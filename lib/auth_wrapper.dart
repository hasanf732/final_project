import 'package:final_project/Pages/bottomnav.dart';
import 'package:final_project/Pages/verify_email_page.dart';
import 'package:final_project/Pages/welcome_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // If user signed up with email but hasn't verified
          if (user.providerData.any((p) => p.providerId == 'password') && !user.emailVerified) {
            return const VerifyEmailPage();
          }
          // User is logged in and verified (or is a Google user), proceed to data checks
          return const SixMonthCheckWrapper();
        }
        // User is not logged in
        return const WelcomePage();
      },
    );
  }
}

class SixMonthCheckWrapper extends StatelessWidget {
  const SixMonthCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const WelcomePage(); // Should not happen, but a safe fallback
    }

    return FutureBuilder<DocumentSnapshot>(
      future: DatabaseMethods().getUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Document doesn't exist. This is an invalid state. Sign out.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final lastSignIn = (userData['lastSignInTime'] as Timestamp?)?.toDate();
        final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));

        if (lastSignIn == null || lastSignIn.isBefore(sixMonthsAgo)) {
          // Expired session. Sign out.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // All checks passed, show the main app.
        return const Bottomnav();
      },
    );
  }
}
