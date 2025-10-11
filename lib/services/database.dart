import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseMethods {
  Future addUserDetail(Map<String, dynamic> userinfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .set(userinfoMap, SetOptions(merge: true));
  }

  Future<void> addNews(File imageFile, String name, String detail, String location, double latitude, double longitude, DateTime dateTime) async {
    // 1. Upload image to Firebase Storage
    String fileName = 'event_images/${DateTime.now().millisecondsSinceEpoch}.png';
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot taskSnapshot = await uploadTask;
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    // 2. Create the event data map
    Map<String, dynamic> eventData = {
      'Name': name,
      'Detail': detail,
      'Location': location,
      'latitude': latitude,
      'longitude': longitude,
      'Date': Timestamp.fromDate(dateTime),
      'Image': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 3. Add the event data to Firestore
    await FirebaseFirestore.instance.collection("News").add(eventData);
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
      return;
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return await userRef.update({
      'bookedEvents': FieldValue.arrayUnion([eventId])
    });
  }

  Future<DocumentSnapshot> getUser(String uid) async {
    return await FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Future<DocumentSnapshot> getEventById(String eventId) async {
    return await FirebaseFirestore.instance.collection('News').doc(eventId).get();
  }

  Future<void> addUserInfo(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .set(userInfoMap, SetOptions(merge: true));
  }
}
