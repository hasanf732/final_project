import 'dart:async';
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
  final _confirmPasswordController = TextEditingController();
  final _majorController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;
  double _passwordStrength = 0;
  bool _has8Chars = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _passwordController.addListener(_updatePasswordStrength);

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        // Pop all routes until the first one (AuthWrapper)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _majorController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    String password = _passwordController.text;
    double strength = 0;

    setState(() {
      _has8Chars = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

      if (_has8Chars) strength += 0.25;
      if (_hasUppercase) strength += 0.25;
      if (_hasNumber) strength += 0.25;
      if (_hasSpecialChar) strength += 0.25;
      
      _passwordStrength = strength;
    });
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
    }
    if (mounted) {
       setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await AuthMethods().signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await AuthMethods().signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );
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
     if (mounted && FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthMethods().signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (mounted) _handleAuthError(e);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred. Please try again.";
        });
      }
    }
     if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
  }

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLogin ? "Welcome Back" : "Create Account",
                style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
                Column(
                  children: [
                    if (!_isLogin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildTextFormField(_nameController, "Full Name", "Please enter your name"),
                      ),
                    if (!_isLogin)
                       Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildTextFormField(_majorController, "Major", "Please enter your major"),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildTextFormField(_emailController, "Email", null,
                        validator: (value) {
                          if (value == null || !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildPasswordFormField(),
                    ),
                    if (!_isLogin) ...[
                       _buildConfirmPasswordFormField(),
                       const SizedBox(height: 20),
                       _buildPasswordStrengthIndicator(),
                    ],
                  ],
                ),
              const SizedBox(height: 40.0),
              _isLoading
                  ? const CircularProgressIndicator()
                  : _buildSubmitButton(),
              const SizedBox(height: 20.0),
              _buildToggleAuthModeButton(),
              const SizedBox(height: 20.0),
              if (!_isLoading) ...[
                const OrDivider(),
                const SizedBox(height: 20.0),
                _buildGoogleSignInButton(onTap: _signInWithGoogle),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, String? emptyMessage, {bool obscureText = false, FormFieldValidator<String>? validator}) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyLarge, 
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
         errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
      obscureText: obscureText,
      validator: validator ?? (value) => value == null || value.isEmpty ? emptyMessage : null,
    );
  }

  Widget _buildPasswordFormField() {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _passwordController,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
         enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
         errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
      obscureText: true,
      validator: (value) {
        if (value == null || value.isEmpty) return "Password is required";
        if (value.length < 8 && !_isLogin) return "Password must be at least 8 characters";
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordFormField() {
     final theme = Theme.of(context);
    return TextFormField(
      controller: _confirmPasswordController,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: "Confirm Password",
        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
         enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
         errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
      obscureText: true,
      validator: (value) {
        if (value != _passwordController.text) return "Passwords do not match";
        return null;
      },
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final theme = Theme.of(context);
    final strengthColor = Color.lerp(Colors.red, Colors.green, _passwordStrength)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: theme.dividerColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: AnimatedContainer(
             duration: const Duration(milliseconds: 300),
             decoration: BoxDecoration(
                color: strengthColor,
                borderRadius: BorderRadius.circular(5),
              ),
             width: (MediaQuery.of(context).size.width - 80) * _passwordStrength,
          ),
        ),
        const SizedBox(height: 12),
        _buildPasswordRequirementRow('At least 8 characters', _has8Chars),
        _buildPasswordRequirementRow('Contains an uppercase letter', _hasUppercase),
        _buildPasswordRequirementRow('Contains a number', _hasNumber),
        _buildPasswordRequirementRow('Contains a special character', _hasSpecialChar),
      ],
    );
  }

  Widget _buildPasswordRequirementRow(String text, bool isMet) {
    final theme = Theme.of(context);
    final color = isMet ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.remove_circle_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: _submitForm,
       style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(_isLogin ? "Log In" : "Sign Up", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _buildToggleAuthModeButton() {
    return TextButton(
      onPressed: _isLoading ? null : () {
        setState(() {
          _isLogin = !_isLogin;
          _errorMessage = null;
          _formKey.currentState?.reset();
          _nameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _majorController.clear();
        });
      },
      child: Text(_isLogin ? "Create an account" : "Already have an account? Log in"),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("or", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)))),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _buildGoogleSignInButton extends StatelessWidget {
  const _buildGoogleSignInButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(40.0),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("Images/google.png", height: 24, width: 24),
            const SizedBox(width: 20.0),
            Text("Continue with Google", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
