import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../firestore_service.dart';
import '../models.dart';
import 'group_list_screen.dart';
import 'login_screen.dart';
import 'create_username_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<AppUser?>(
      stream: firestoreService.getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            ),
          );
        }

        final appUser = snapshot.data;
        if (appUser == null || appUser.username == null || appUser.username!.isEmpty) {
          return const CreateUsernameScreen();
        }

        return const GroupListScreen();
      },
    );
  }
}