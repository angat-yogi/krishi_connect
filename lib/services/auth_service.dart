import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Stream<UserProfile?> get profileChanges {
    return authStateChanges.asyncExpand((user) async* {
      if (user == null) {
        yield null;
        return;
      }

      final fallbackProfile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        role: null,
      );

      final docRef = _firestore.collection('users').doc(user.uid);

      await _ensureUserDocument(user, displayName: user.displayName);

      UserProfile? lastProfile;

      while (true) {
        try {
          await for (final snapshot in docRef.snapshots(
            includeMetadataChanges: true,
          )) {
            final data = snapshot.data();
            if (!snapshot.exists || data == null) {
              yield lastProfile ?? fallbackProfile;
            } else {
              final profile = UserProfile.fromMap(snapshot.id, data);
              lastProfile = profile;
              yield profile;
            }
          }
          break;
        } on FirebaseException catch (e, stackTrace) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: e,
            stack: stackTrace,
            library: 'AuthService',
            informationCollector: () => [
              DiagnosticsNode.message(
                'Streaming profile for uid=${user.uid}',
              ),
            ],
          ));

          if (e.code == 'unavailable') {
            debugPrint(
              'Firestore unavailable when streaming profile (uid=${user.uid}). Retrying...',
            );
            yield lastProfile ?? fallbackProfile;
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }

          yield lastProfile ?? fallbackProfile;
          return;
        } catch (e, stackTrace) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: e,
            stack: stackTrace,
            library: 'AuthService',
          ));
          yield lastProfile ?? fallbackProfile;
          return;
        }
      }
    });
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user, displayName: user.displayName);
    }
    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Google sign-in aborted by user.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await _ensureUserDocument(user, displayName: user.displayName);
    }
    return userCredential;
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<UserProfile?> fetchUserProfile(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);
    try {
      final doc = await _getDocumentWithRetry(docRef);
      if (!doc.exists) {
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null && currentUser.uid == uid) {
          await _ensureUserDocument(
            currentUser,
            displayName: currentUser.displayName,
          );
          final refreshed = await _getDocumentWithRetry(docRef);
          if (!refreshed.exists) return null;
          return UserProfile.fromMap(uid, refreshed.data());
        }
        return null;
      }
      return UserProfile.fromMap(uid, doc.data());
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        debugPrint(
          'Firestore unavailable when fetching profile (uid=$uid). Failing gracefully.',
        );
        return null;
      }
      rethrow;
    } on StateError catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        library: 'AuthService',
        informationCollector: () => [
          DiagnosticsNode.message('fetchUserProfile failed for uid=$uid'),
        ],
      ));
      return null;
    }
  }

  Future<void> updateUserRole(UserRole role) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'role': role.key,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }

    await user.updateDisplayName(displayName);
    await _firestore.collection('users').doc(user.uid).set(
      {
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _ensureUserDocument(
    User user, {
    String? displayName,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    bool shouldWrite = true;

    try {
      final doc = await _getDocumentWithRetry(docRef);
      shouldWrite = !doc.exists;
    } on FirebaseException catch (e, stackTrace) {
      if (e.code != 'unavailable') {
        FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'AuthService',
          informationCollector: () => [
            DiagnosticsNode.message(
              'Ensuring user document for uid=${user.uid}',
            ),
          ],
        ));
      } else {
        debugPrint(
          'Firestore unavailable when checking user document (uid=${user.uid}). Will enqueue create.',
        );
      }
    } on StateError catch (e, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        library: 'AuthService',
        informationCollector: () => [
          DiagnosticsNode.message(
            'Unable to confirm user document for uid=${user.uid}; proceeding with enqueue.',
          ),
        ],
      ));
    }

    if (!shouldWrite) return;

    await docRef.set(
      {
        'email': user.email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocumentWithRetry(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await ref.get();
      } on FirebaseException catch (e) {
        final isUnavailable = e.code == 'unavailable';
        final shouldRetry = isUnavailable && attempt < maxAttempts - 1;
        if (shouldRetry) {
          final backoff = Duration(milliseconds: 400 * (1 << attempt));
          debugPrint(
            'Firestore unavailable (attempt ${attempt + 1}). Retrying in ${backoff.inMilliseconds}ms...',
          );
          await Future.delayed(backoff);
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Unable to load document after $maxAttempts attempts.');
  }
}
