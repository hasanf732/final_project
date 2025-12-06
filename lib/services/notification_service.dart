import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // Request permission from the user
    await _firebaseMessaging.requestPermission();

    // Get the FCM token and save it to the database
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      await _saveTokenToDatabase(fcmToken);
    }

    // Listen for token refreshes and update the database
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // Handle incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // In a real app, you would show a local notification here
        print('Foreground Message: ${message.notification!.title} - ${message.notification!.body}');
      }
    });
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await DatabaseMethods().saveUserToken(token, user.uid);
    }
  }
}
