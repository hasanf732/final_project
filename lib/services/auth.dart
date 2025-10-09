import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:final_project/services/database.dart';

class AuthMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleSignInAccount = await GoogleSignIn().signIn();
      if (googleSignInAccount == null) return; // User cancelled

      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleSignInAuthentication.idToken,
          accessToken: googleSignInAuthentication.accessToken);

      UserCredential result = await auth.signInWithCredential(credential);
      User? userDetails = result.user;

      if (userDetails != null) {
        Map<String, dynamic> userInfoMap = {
          "Name": userDetails.displayName,
          "Image": userDetails.photoURL,
          "Email": userDetails.email,
          "Id": userDetails.uid,
          'lastSignInTime': FieldValue.serverTimestamp(),
        };
        // Just update user data. AuthWrapper will handle navigation.
        await DatabaseMethods().addUserDetail(userInfoMap, userDetails.uid);
      }
    } on FirebaseAuthException catch (e) {
      // This error can be handled in the UI if needed
      print("Google Sign-In Error: ${e.message}");
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    return await auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    UserCredential result = await auth.signInWithEmailAndPassword(
        email: email, password: password);

    // Update last sign-in time
    if (result.user != null) {
      await DatabaseMethods().addUserInfo({'lastSignInTime': FieldValue.serverTimestamp()}, result.user!.uid);
    }

    return result;
  }

  Future<void> signOut() async {
    await auth.signOut();
    await GoogleSignIn().signOut();
    // Navigation will be handled by the AuthWrapper stream
  }
}
