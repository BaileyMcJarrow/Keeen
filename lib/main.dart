// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'local_notification.dart';
import 'fcm_service.dart';
import 'auth_service.dart';
import 'screens/auth_gate.dart';
import 'firestore_service.dart'; // Import FirestoreService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const String serverClientId = '793520647227-0agknl7ve4rbe84ulgcipjml6si8avc0.apps.googleusercontent.com';
  await GoogleSignIn.instance.initialize(serverClientId: serverClientId);

  // Initialize services
  await NotificationService().init();

  // Create FirestoreService instance
  final firestoreService = FirestoreService();

  // Initialize FcmService and pass FirestoreService
  // Also, listen for auth changes to save token on login
  final fcmService = FcmService(firestoreService: firestoreService);
  await fcmService.init(); // Initialize FCM (requests permission, sets up listeners)

  // Listen to auth state changes to save token upon login
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      print("User logged in (${user.uid}), attempting to save FCM token.");
      fcmService.saveTokenToFirestore(); // Use the helper method
    } else {
      print("User logged out.");
      // Optional: Remove token from Firestore on logout if desired
    }
  });


  runApp(
    // Provide FirestoreService globally if needed by multiple widgets/viewmodels
    Provider<FirestoreService>(
      create: (_) => firestoreService,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
        // FcmService doesn't typically need to be provided via Provider
        // unless widgets need direct access to its methods beyond init.
      ],
      child: MaterialApp(
        title: 'Keeen',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}