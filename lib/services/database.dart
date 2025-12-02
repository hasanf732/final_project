import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addUserDetail(Map<String, dynamic> userinfoMap, String id) async {
    await _firestore.collection("users").doc(id).set(userinfoMap, SetOptions(merge: true));
  }

  Future<void> addNews(
      Uint8List imageBytes, String name, String detail, String location, double latitude, double longitude, DateTime dateTime, String category) async {
    String fileName = 'event_images/${DateTime.now().millisecondsSinceEpoch}.png';
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    UploadTask uploadTask = storageRef.putData(imageBytes);
    TaskSnapshot taskSnapshot = await uploadTask;
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    Map<String, dynamic> eventData = {
      'Name': name,
      'Detail': detail,
      'Location': location,
      'latitude': latitude,
      'longitude': longitude,
      'Date': Timestamp.fromDate(dateTime),
      'Image': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'Category': category,
    };

    await _firestore.collection("News").add(eventData);
  }

  Stream<QuerySnapshot> getEventDetails() {
    return _firestore.collection("News").snapshots();
  }

  Stream<Map<String, int>> getEventRegistrationCounts() {
    return _firestore.collection("users").snapshots().map((snapshot) {
      final counts = <String, int>{};
      for (var userDoc in snapshot.docs) {
        final data = userDoc.data();
        if (data.containsKey('bookedEvents')) {
          final bookedEvents = List<String>.from(data['bookedEvents']);
          for (var eventId in bookedEvents) {
            counts[eventId] = (counts[eventId] ?? 0) + 1;
          }
        }
      }
      return counts;
    });
  }

  Stream<Map<String, int>> getEventAttendanceCounts() {
    return _firestore.collection("users").snapshots().map((snapshot) {
      final counts = <String, int>{};
      for (var userDoc in snapshot.docs) {
        final data = userDoc.data();
        if (data.containsKey('attendedEvents')) {
          final attendedEvents = List<String>.from(data['attendedEvents']);
          for (var eventId in attendedEvents) {
            counts[eventId] = (counts[eventId] ?? 0) + 1;
          }
        }
      }
      return counts;
    });
  }


  Future<void> addReview(String eventId, double rating, String reviewText) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final eventRef = _firestore.collection('News').doc(eventId);
    final reviewData = {
      'rating': rating,
      'review': reviewText,
      'timestamp': FieldValue.serverTimestamp(),
      'userName': user.displayName ?? 'Anonymous',
    };

    await eventRef.set({
      'ratings': {user.uid: reviewData}
    }, SetOptions(merge: true));
  }

  Future<void> registerForEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.update({
      'bookedEvents': FieldValue.arrayUnion([eventId])
    });
  }

  Future<void> markUserAsAttended(String userId, String eventId) async {
    final userRef = _firestore.collection('users').doc(userId);
    await userRef.update({
      'attendedEvents': FieldValue.arrayUnion([eventId])
    });
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<bool> isFavorite(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;
    List<dynamic> favorites = userDoc.data()?['favoriteEvents'] ?? [];
    return favorites.contains(eventId);
  }

  Future<void> addToFavorites(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.update({
      'favoriteEvents': FieldValue.arrayUnion([eventId])
    });
  }

  Future<void> removeFromFavorites(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.update({
      'favoriteEvents': FieldValue.arrayRemove([eventId])
    });
  }

  Future<DocumentSnapshot> getUser(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<DocumentSnapshot> getEventById(String eventId) async {
    return await _firestore.collection('News').doc(eventId).get();
  }
}
