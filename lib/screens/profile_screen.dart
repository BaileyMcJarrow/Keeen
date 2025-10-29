// lib/screens/profile_screen.dart
import 'package:flut1/models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  String _originalUsername = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<User?>(context, listen: false);

    if (user != null) {
      final appUser = await firestoreService.getUser(user.uid);
      if (appUser != null && appUser.username != null) {
        setState(() {
          _originalUsername = appUser.username!;
          _usernameController.text = appUser.username!;
        });
      }
    }
    setState(() => _isLoading = false);
  }

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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final newUsername = _usernameController.text.trim();

    if (newUsername == _originalUsername) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No changes made.';
      });
      return;
    }

    try {
      final isAvailable = await firestoreService.isUsernameAvailable(newUsername);
      if (!isAvailable) {
        setState(() {
          _errorMessage = 'Username is already taken.';
          _isLoading = false;
        });
        return;
      }

      await firestoreService.setUsername(user!.uid, newUsername);
      messenger.showSnackBar(
        const SnackBar(content: Text('Username updated successfully!')),
      );
      navigator.pop();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                      initialValue: user?.email ?? 'No Email',
                      readOnly: true,
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
                    const SizedBox(height: 30),
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
                          child: const Text('Save Changes', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: _errorMessage == 'No changes made.' ? Colors.black54 : Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}