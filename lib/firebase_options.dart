import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase options are not configured for web. Supply web values via your own initializer.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase options are not available for this platform. Provide them manually.',
        );
    }
  }

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: _require(_androidApiKey, 'FIREBASE_ANDROID_API_KEY'),
    appId: _require(_androidAppId, 'FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: _require(
      _androidMessagingSenderId,
      'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
    ),
    projectId: _require(_projectId, 'FIREBASE_PROJECT_ID'),
    storageBucket: _optional(_storageBucket),
  );

  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: _require(_iosApiKey, 'FIREBASE_IOS_API_KEY'),
    appId: _require(_iosAppId, 'FIREBASE_IOS_APP_ID'),
    messagingSenderId: _require(
      _iosMessagingSenderId,
      'FIREBASE_IOS_MESSAGING_SENDER_ID',
    ),
    projectId: _require(_projectId, 'FIREBASE_PROJECT_ID'),
    storageBucket: _optional(_storageBucket),
    iosClientId: _optional(_iosClientId),
    iosBundleId: _optional(_iosBundleId),
  );
}

const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

const _androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
const _androidMessagingSenderId =
    String.fromEnvironment('FIREBASE_ANDROID_MESSAGING_SENDER_ID');

const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
const _iosMessagingSenderId =
    String.fromEnvironment('FIREBASE_IOS_MESSAGING_SENDER_ID');
const _iosClientId = String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');
const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

String _require(String value, String name) {
  if (value.isEmpty) {
    throw StateError(
      'Firebase configuration missing for $name. Provide it via --dart-define.',
    );
  }
  return value;
}

String? _optional(String value) => value.isEmpty ? null : value;
