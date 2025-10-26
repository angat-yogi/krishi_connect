import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KrishiConnectApp());
}

class KrishiConnectApp extends StatelessWidget {
  const KrishiConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
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
