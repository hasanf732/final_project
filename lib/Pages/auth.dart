import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:final_project/services/database.dart';
import 'package:final_project/Pages/bottomnav.dart';
import 'package:final_project/Pages/welcome_page.dart'; // Changed to welcome_page

class AuthMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;

  getCurrentUser() async {
    return await auth.currentUser;
  }

  signInWithGoogle(BuildContext context) async {
    final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
    final GoogleSignIn googleSignIn = GoogleSignIn();

    final GoogleSignInAccount? googleSignInAccount =
        await googleSignIn.signIn();

    final GoogleSignInAuthentication? googleSignInAuthentication =
        await googleSignInAccount?.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication?.idToken,
        accessToken: googleSignInAuthentication?.accessToken);

    UserCredential result = await firebaseAuth.signInWithCredential(credential);

    User? userDetails = result.user;

    if (userDetails != null) {
      Map<String, dynamic> userInfoMap = {
        "Name": userDetails.displayName,
        "Image": userDetails.photoURL,
        "Email": userDetails.email,
        "Id": userDetails.uid
      };

      await DatabaseMethods()
          .addUserDetail(userInfoMap, userDetails.uid)
          .then((value) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "Registered Successfully!",
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            )));

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => Bottomnav()));
      });
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    return await auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut(BuildContext context) async {
    await auth.signOut();
    await GoogleSignIn().signOut();
    // Navigate to the welcome screen and remove all other screens from the stack
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomePage()),
        (Route<dynamic> route) => false);
  }
}
