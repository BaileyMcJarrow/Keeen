import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for FirebaseAuthException

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoginMode = true; // Toggle between Login and Sign Up

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper function to handle auth calls and loading state
  Future<void> _performAuthAction(Future<User?> Function() authAction) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await authAction();
      // Navigation happens automatically via AuthGate listening to the stream
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "An error occurred.";
      });
    } catch (e) {
       setState(() {
        _errorMessage = "An unexpected error occurred.";
      });
    } finally {
      // Ensure loading indicator stops even if widget is disposed
      if (mounted) { 
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginMode ? 'Login' : 'Sign Up'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView( // Prevents overflow when keyboard appears
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Keeen',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 40),

              // --- Email Field ---
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 15),

              // --- Password Field ---
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 30),

              // --- Loading Indicator ---
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[ // Show buttons only when not loading
                // --- Error Message ---
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // --- Email/Password Button ---
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
                    child: Text(
                      _isLoginMode ? 'Login with Email' : 'Sign Up with Email',
                      style: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text.trim();
                      if (email.isEmpty || password.isEmpty) {
                         setState(() => _errorMessage = "Please enter email and password.");
                         return;
                      }
                      if (_isLoginMode) {
                        _performAuthAction(() => authService.signInWithEmailAndPassword(email, password));
                      } else {
                        _performAuthAction(() => authService.createUserWithEmailAndPassword(email, password));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 15),

                // --- Google Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Sign In with Google', style: TextStyle(fontSize: 18)),
                     style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor: Colors.white, // Style like Google button
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onPressed: () => _performAuthAction(authService.signInWithGoogle),
                  ),
                ),
                const SizedBox(height: 15),
                
                // --- Anonymous Button ---
                 SizedBox(
                   width: double.infinity,
                   child: OutlinedButton(
                     style: OutlinedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 15),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(10.0),
                       ),
                       side: BorderSide(color: Theme.of(context).colorScheme.primary),
                       foregroundColor: Theme.of(context).colorScheme.primary,
                     ),
                     child: const Text('Sign In Anonymously', style: TextStyle(fontSize: 18)),
                     onPressed: () => _performAuthAction(authService.signInAnonymously),
                   ),
                 ),
                 const SizedBox(height: 30),

                 // --- Toggle Mode Button ---
                 TextButton(
                    child: Text(
                      _isLoginMode
                          ? 'Need an account? Sign Up'
                          : 'Have an account? Login',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                    ),
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        _errorMessage = null; // Clear error on mode switch
                      });
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}