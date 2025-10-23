import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          child: const Text('Sign In Anonymously'),
          onPressed: () {
            // Call the auth service to sign in
            authService.signInAnonymously();
          },
        ),
      ),
    );
  }
}