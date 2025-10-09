import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseMethods {
  Future addUserDetail(Map<String, dynamic> userinfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .set(userinfoMap, SetOptions(merge: true)); // Use merge to avoid overwriting
  }

  Future addEvent(Map<String, dynamic> userinfoMap, String id) async {
    return await FirebaseFirestore.instance.collection("News").doc(id).set(userinfoMap);
  }

  Stream<QuerySnapshot> getEventDetails() {
    return FirebaseFirestore.instance.collection("News").snapshots();
  }

  Future<void> addReview(String eventId, double rating, String reviewText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final eventRef = FirebaseFirestore.instance.collection('News').doc(eventId);

    final reviewData = {
      'rating': rating,
      'review': reviewText,
      'timestamp': FieldValue.serverTimestamp(),
      'userName': user.displayName ?? 'Anonymous',
    };

    return eventRef.set({
      'ratings': {
        user.uid: reviewData
      }
    }, SetOptions(merge: true));
  }

  Future<void> registerForEvent(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return; // Or handle not logged in case
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Atomically add the new event ID to the 'bookedEvents' array
    return await userRef.update({
      'bookedEvents': FieldValue.arrayUnion([eventId])
    });
  }

   // Fetch a user's document to get their booked events
  Future<DocumentSnapshot> getUser(String uid) async {
    return await FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  // Fetch a specific event by its ID
  Future<DocumentSnapshot> getEventById(String eventId) async {
    return await FirebaseFirestore.instance.collection('News').doc(eventId).get();
  }

  Future<void> addUserInfo(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .set(userInfoMap, SetOptions(merge: true)); // Use merge to avoid overwriting
  }
}
