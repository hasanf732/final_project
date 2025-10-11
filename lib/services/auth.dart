import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:final_project/services/database.dart';

class AuthMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> signInWithGoogle() async {
    // Throws exceptions to be handled by the UI
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
      // Using addUserDetail to ensure all user data is stored consistently
      await DatabaseMethods().addUserDetail(userInfoMap, userDetails.uid);
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    return await auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    UserCredential result = await auth.signInWithEmailAndPassword(
        email: email, password: password);

    if (result.user != null) {
      await DatabaseMethods().addUserInfo({'lastSignInTime': FieldValue.serverTimestamp()}, result.user!.uid);
    }

    return result;
  }

  Future<void> signOut() async {
    print(">>> SIGN OUT from services/auth.dart");
    await auth.signOut();
    await GoogleSignIn().signOut();
  }
}
