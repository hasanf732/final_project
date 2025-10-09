import 'package:final_project/services/auth.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signup extends StatefulWidget {
  final bool isLogin;
  const Signup({super.key, this.isLogin = true});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  late bool _isLogin;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists for that email.';
        break;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        message = 'Invalid credentials. Please try again.';
        break;
      case 'invalid-email':
        message = 'The email address is not valid.';
        break;
      case 'user-disabled':
        message = 'This user has been disabled.';
        break;
      default:
        message = 'An unknown error occurred. Please try again.';
        print('Firebase Auth Error: ${e.code} - ${e.message}');
    }
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        // Login Flow
        final userCredential = await AuthMethods().signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (mounted && userCredential.user != null && !userCredential.user!.emailVerified) {
          setState(() {
            _errorMessage = "Please verify your email to log in. A new verification link has been sent.";
            _isLoading = false;
          });
          await userCredential.user!.sendEmailVerification();
        }
        // On successful login, AuthWrapper will handle navigation.

      } else {
        // Sign-Up Flow
        UserCredential userCredential = await AuthMethods().signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          Map<String, dynamic> userInfoMap = {
            "Name": _nameController.text,
            "Email": _emailController.text,
            "Id": user.uid,
            'lastSignInTime': FieldValue.serverTimestamp(),
          };
          await DatabaseMethods().addUserInfo(userInfoMap, user.uid);
          // After sign up, AuthWrapper will detect the new user and show the VerifyEmailPage.
          // No navigation is needed here.
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred. Please try again.";
          _isLoading = false;
        });
      }
    }
    // Only set isLoading to false if there was an error and we are still on this page
     if (mounted && FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold, color: Color(0xFF00008B)),
              ),
              const SizedBox(height: 30.0),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin)
                      TextFormField(
                        key: const ValueKey('name'),
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Full Name"),
                        validator: (value) => value == null || value.isEmpty ? "Please enter your name" : null,
                      ),
                    TextFormField(
                      key: const ValueKey('email'),
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      validator: (value) {
                        if (value == null || !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      key: const ValueKey('password'),
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Password"),
                      obscureText: true,
                      validator: (value) => value == null || value.isEmpty ? "Please enter your password" : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40.0),
              _isLoading
                  ? const CircularProgressIndicator()
                  : GestureDetector(
                      onTap: _submitForm,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00008B),
                          borderRadius: BorderRadius.circular(40.0),
                        ),
                        child: Center(
                          child: Text(
                            _isLogin ? "Log In" : "Sign Up",
                            style: const TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 20.0),
              TextButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                    _formKey.currentState?.reset();
                    _nameController.clear();
                    _emailController.clear();
                    _passwordController.clear();
                  });
                },
                child: Text(_isLogin ? "Create an account" : "Already have an account? Log in"),
              ),
              const SizedBox(height: 20.0),
              if (!_isLoading)
                Row(
                  children: <Widget>[
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text("or", style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              const SizedBox(height: 20.0),
              if (!_isLoading)
                GestureDetector(
                  onTap: () => AuthMethods().signInWithGoogle(),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40.0),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("Images/google.png", height: 24, width: 24),
                        const SizedBox(width: 20.0),
                        const Text("Continue with Google", style: TextStyle(color: Colors.black87, fontSize: 18.0, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
