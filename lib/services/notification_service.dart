import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
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
    // Use 'launcher_icon' which is your actual logo, instead of 'ic_launcher' which is the flutter default
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print("Received foreground message: ${message.messageId}");
      }

      RemoteNotification? notification = message.notification;
      
      if (notification != null) {
        // Try to load the logo for the foreground notification too
        String? largeIconPath;
        try {
          largeIconPath = await _getImageFilePathFromAssets('Images/Logo.png', 'large_icon_logo.png');
        } catch (e) {
          if (kDebugMode) print("Could not load logo asset: $e");
        }

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon', // Use your logo here
              largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
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
    final now = DateTime.now();
    
    // Get the logo file path
    String? largeIconPath;
    try {
      largeIconPath = await _getImageFilePathFromAssets('Images/Logo.png', 'large_icon_logo.png');
    } catch (e) {
      if (kDebugMode) print("Could not load logo asset: $e");
    }

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon', // Use your logo here
      largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    // 1. Schedule 24 Hours Before
    final date24h = eventDate.subtract(const Duration(hours: 24));
    if (date24h.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        eventId.hashCode, // ID
        'Event Reminder: 1 Day Left!',
        'Your event "$eventName" starts tomorrow at ${DateFormat('h:mm a').format(eventDate)}.',
        tz.TZDateTime.from(date24h, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 2. Schedule 1 Hour Before
    final date1h = eventDate.subtract(const Duration(hours: 1));
    if (date1h.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        eventId.hashCode + 1, // ID + 1 to avoid conflict
        'Event Starting Soon!',
        'Get ready! "$eventName" starts in 1 hour.',
        tz.TZDateTime.from(date1h, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    // Cancel both possible notifications
    await _localNotifications.cancel(eventId.hashCode);
    await _localNotifications.cancel(eventId.hashCode + 1);
  }

  Future<String> _getImageFilePathFromAssets(String asset, String filename) async {
    final byteData = await rootBundle.load(asset);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }
}
