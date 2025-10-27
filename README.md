# krishi_connect

KrishiConnect connects local farmers and shopkeepers with role-based dashboards backed by Firebase Authentication, Firestore, and Storage.

## Prerequisites

- Flutter (stable channel)
- Firebase project with iOS and Android apps registered
- `google-services.json` in `android/app/`
- `GoogleService-Info.plist` in `ios/Runner/`
- iOS: ensure `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` are set in `Info.plist`

## Configure Firebase secrets

To avoid committing API keys, runtime values are read from dart-defines.

1. Copy the sample config and fill in the values from the Firebase console:

   ```bash
   cp config/firebase_options.sample.json config/firebase_options.dev.json
   # edit config/firebase_options.dev.json with your Firebase keys
   ```

2. Run the app using `--dart-define-from-file` (Flutter 3.7+):

   ```bash
   flutter run --dart-define-from-file=config/firebase_options.dev.json
   ```

   For older Flutter versions, pass each value manually:

   ```bash
   flutter run \
     --dart-define=FIREBASE_PROJECT_ID=your-project-id \
     --dart-define=FIREBASE_ANDROID_API_KEY=... \
     --dart-define=FIREBASE_ANDROID_APP_ID=... \
     --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=... \
     --dart-define=FIREBASE_IOS_API_KEY=... \
     --dart-define=FIREBASE_IOS_APP_ID=... \
     --dart-define=FIREBASE_IOS_MESSAGING_SENDER_ID=... \
     --dart-define=FIREBASE_IOS_CLIENT_ID=... \
     --dart-define=FIREBASE_IOS_BUNDLE_ID=com.krishiconnect.npl
   ```

If any value is missing, the app shows a configuration screen explaining what to supply.

## Running tests

```
flutter test
```

Widget tests are currently skipped until Firebase mocks are added.

## Image uploads

- Producers can attach an optional photo to each inventory item; when absent, the UI renders a "Coming Soon" placeholder.
- During sign up, non-Google accounts are prompted for profile photo and location. Photos are stored in Firebase Storage under `profile_photos/`.
