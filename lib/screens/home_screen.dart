import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = Provider.of<User?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keeen Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Call auth service to sign out
              authService.signOut();
            },
          )
        ],
      ),
      body: Center(
        child: Text('Welcome! ${user?.uid} \n\n Now you can build your group list here.'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add logic to create a new group
          // e.g., show a dialog, then call:
          // FirestoreService().createGroup('My New Group', user!.uid);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}