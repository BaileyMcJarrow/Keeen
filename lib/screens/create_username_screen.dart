
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_service.dart';

class CreateUsernameScreen extends StatefulWidget {
  const CreateUsernameScreen({super.key});

  @override
  _CreateUsernameScreenState createState() => _CreateUsernameScreenState();
}

class _CreateUsernameScreenState extends State<CreateUsernameScreen> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<User?>(context, listen: false);
    final username = _usernameController.text.trim();

    try {
      final isAvailable = await firestoreService.isUsernameAvailable(username);
      if (!isAvailable) {
        setState(() {
          _errorMessage = 'Username is already taken.';
          _isLoading = false;
        });
        return;
      }

      await firestoreService.setUsername(user!.uid, username);
      // Navigation will be handled by the AuthGate now that the user has a username
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Username'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Keeen',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Choose a unique username',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username cannot be empty';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: _saveUsername,
                      child: const Text('Save', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
