import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'local_notification.dart'; // Your existing service
import 'fcm_service.dart';        // The new service
import 'auth_service.dart';       // The new service
import 'screens/auth_gate.dart';   // The new screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const String clientId = '793520647227-0agknl7ve4rbe84ulgcipjml6si8avc0.apps.googleusercontent.com';
  await GoogleSignIn.instance.initialize(
    clientId: clientId, // Provide the Web Client ID here
  );

  // Initialize all services
  await NotificationService().init(); // Your local notifications
  await FcmService().init();          // Firebase Cloud Messaging

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to provide services to the widget tree
    return MultiProvider(
      providers: [
        // Provides the AuthService instance
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // Listens to auth changes and provides the User? object
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Keeen',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(), // Use AuthGate to decide which screen to show
      ),
    );
  }
}