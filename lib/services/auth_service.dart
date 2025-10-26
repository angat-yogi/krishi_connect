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

  Stream<UserProfile?> get profileChanges async* {
    await for (final user in authStateChanges) {
      if (user == null) {
        yield null;
        continue;
      }
      try {
        yield await fetchUserProfile(user.uid);
      } on FirebaseException catch (e, stackTrace) {
        debugPrint('Failed to load user profile: ${e.code} ${e.message}');
        FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'AuthService',
          informationCollector: () => [
            DiagnosticsNode.message('Fetching profile for uid=${user.uid}'),
          ],
        ));
        yield null;
      } catch (e, stackTrace) {
        debugPrint('Unexpected error loading profile: $e');
        FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'AuthService',
        ));
        yield null;
      }
    }
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
    final doc = await docRef.get();
    if (!doc.exists) {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        await _ensureUserDocument(currentUser,
            displayName: currentUser.displayName);
        final refreshed = await docRef.get();
        if (!refreshed.exists) return null;
        return UserProfile.fromMap(uid, refreshed.data());
      }
      return null;
    }
    return UserProfile.fromMap(uid, doc.data());
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
    final doc = await docRef.get();
    if (doc.exists) return;

    await docRef.set({
      'email': user.email,
      'displayName': displayName,
      'role': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
