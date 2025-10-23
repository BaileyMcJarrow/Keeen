import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the User? stream
    final user = Provider.of<User?>(context);

    // If user is null, show LoginScreen, otherwise show HomeScreen
    return user == null ? const LoginScreen() : const HomeScreen();
  }
}