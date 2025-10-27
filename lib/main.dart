import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/user_model.dart';
import 'pages/auth/auth_gate.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
    runApp(const KrishiConnectApp());
  } on firebase_core.FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      runApp(const KrishiConnectApp());
      return;
    }
    runApp(ConfigErrorApp(message: '${e.code}: ${e.message ?? ''}'.trim()));
  } on StateError catch (e) {
    runApp(ConfigErrorApp(message: e.message ?? e.toString()));
  } on UnsupportedError catch (e) {
    runApp(ConfigErrorApp(message: e.message ?? 'An unknown error occurred.'));
  } catch (e) {
    runApp(ConfigErrorApp(message: e.toString()));
  }
}

class KrishiConnectApp extends StatelessWidget {
  const KrishiConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<StorageService>(create: (_) => StorageService()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
        StreamProvider<UserProfile?>(
          create: (context) => context.read<AuthService>().profileChanges,
          initialData: null,
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) {
          return MaterialApp(
            title: 'KrishiConnect',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
              ),
              useMaterial3: true,
            ),
            home: const AuthGate(),
            routes: {
              LoginPage.routeName: (_) => const LoginPage(),
              SignUpPage.routeName: (_) => const SignUpPage(),
            },
          );
        },
      ),
    );
  }
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Configuration Required')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Firebase configuration is missing.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                'Run the app with the required --dart-define values or use '
                '--dart-define-from-file with your Firebase config file.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
