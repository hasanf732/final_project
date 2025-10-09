import 'dart:async';
import 'package:final_project/Pages/bottomnav.dart';
import 'package:final_project/services/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isEmailVerified = false;
  bool _canResendEmail = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    if (!_isEmailVerified) {
      sendVerificationEmail();

      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    // Reload the user, otherwise emailVerified will not be updated
    await FirebaseAuth.instance.currentUser!.reload();
    setState(() {
      _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    });

    if (_isEmailVerified) _timer?.cancel();
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();

      setState(() => _canResendEmail = false);
      await Future.delayed(const Duration(seconds: 5));
      if(mounted){
        setState(() => _canResendEmail = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _isEmailVerified
      ? const Bottomnav()
      : Scaffold(
          appBar: AppBar(
            title: const Text('Verify Email'),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'A verification email has been sent to your email address. Please check your inbox and click the link to continue.',
                  style: TextStyle(fontSize: 18.0),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30.0),
                ElevatedButton.icon(
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Resend Email'),
                  onPressed: _canResendEmail ? sendVerificationEmail : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => AuthMethods().signOut(context),
                )
              ],
            ),
          ),
        );
}
