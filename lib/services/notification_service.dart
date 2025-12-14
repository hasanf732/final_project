import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // 0. Initialize Timezones
    tz.initializeTimeZones();

    // 1. Request permission from the user
    await _firebaseMessaging.requestPermission();

    // 2. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(initializationSettings);

    // 3. Create a Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Log token for testing
    final fcmToken = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $fcmToken');
    }

    // 5. Subscribe to the 'newEvents' topic by default
    await _firebaseMessaging.subscribeToTopic("newEvents");

    // 6. Handle incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("Received foreground message: ${message.messageId}");
        print("Notification: ${message.notification?.title}, ${message.notification?.body}");
      }

      RemoteNotification? notification = message.notification;
      
      // Show notification even if 'android' payload is missing, as long as 'notification' exists
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
          ),
        );
      }
    });
  }

  Future<void> subscribeToTopic(String topic) async {
    if (kDebugMode) print("Subscribing to topic: $topic");
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (kDebugMode) print("Unsubscribing from topic: $topic");
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  Future<void> scheduleEventReminder(String eventId, String eventName, DateTime eventDate) async {
    // Schedule for 24 hours before event
    DateTime scheduledDate = eventDate.subtract(const Duration(hours: 24));
    final now = DateTime.now();
    
    // If 24h before is already past, try 1 hour before
    if (scheduledDate.isBefore(now)) {
       scheduledDate = eventDate.subtract(const Duration(hours: 1));
    }

    // If that is also past, don't schedule
    if (scheduledDate.isBefore(now)) return;

    await _localNotifications.zonedSchedule(
      eventId.hashCode,
      'Event Reminder',
      'Upcoming: $eventName is starting soon at ${DateFormat('h:mm a').format(eventDate)}!',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelEventReminder(String eventId) async {
    await _localNotifications.cancel(eventId.hashCode);
  }
}
