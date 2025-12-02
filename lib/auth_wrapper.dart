import 'package:final_project/Pages/admin_page.dart';
import 'package:final_project/Pages/main_page.dart';
import 'package:final_project/Pages/welcome_page.dart';
import 'package:final_project/services/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Something went wrong")));
        }
        if (snapshot.hasData) {
          return const RoleBasedRedirect();
        } else {
          return const WelcomePage();
        }
      },
    );
  }
}

class RoleBasedRedirect extends StatelessWidget {
  const RoleBasedRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthMethods().isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Default to non-admin view unless explicitly identified as an admin.
        if (snapshot.hasData && snapshot.data == true) {
          return const AdminPage();
        } else {
          // This covers non-admin users, errors, or null data.
          return const MainPage();
        }
      },
    );
  }
}
