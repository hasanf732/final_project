import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:final_project/services/database.dart';

class AuthMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isAdmin() async {
    final user = auth.currentUser;
    if (user == null) return false;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        // Check for both 'role' and 'isAdmin' fields for robustness
        return data['role'] == 'admin' || data['isAdmin'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount? googleSignInAccount = await GoogleSignIn().signIn();
    if (googleSignInAccount == null) return; 

    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication.idToken,
        accessToken: googleSignInAuthentication.accessToken);

    UserCredential result = await auth.signInWithCredential(credential);
    User? userDetails = result.user;

    if (userDetails != null) {
      // Check if user already exists to preserve their role
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userDetails.uid).get();
      if (!userDoc.exists) {
         Map<String, dynamic> userInfoMap = {
          "Name": userDetails.displayName,
          "Image": userDetails.photoURL,
          "Email": userDetails.email,
          "Id": userDetails.uid,
          'lastSignInTime': FieldValue.serverTimestamp(),
          'role': 'user', // Default role
        };
        await DatabaseMethods().addUserDetail(userInfoMap, userDetails.uid);
      }
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, String fullName) async {
    UserCredential result = await auth.createUserWithEmailAndPassword(
        email: email, password: password);
    
    User? user = result.user;
    if (user != null) {
        Map<String, dynamic> userInfoMap = {
        "Name": fullName,
        "Email": email,
        "Id": user.uid,
        'role': 'user', // Default role
      };
      await DatabaseMethods().addUserDetail(userInfoMap, user.uid);
    }
    return result;
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    UserCredential result = await auth.signInWithEmailAndPassword(
        email: email, password: password);

    if (result.user != null) {
      await DatabaseMethods().addUserDetail({'lastSignInTime': FieldValue.serverTimestamp()}, result.user!.uid);
    }

    return result;
  }

  Future<void> signOut() async {
    await auth.signOut();
    await GoogleSignIn().signOut();
  }
}
