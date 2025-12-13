import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final StreamController<List<Map<String, dynamic>>> _notificationsController = StreamController<List<Map<String, dynamic>>>();
  List<Map<String, dynamic>> _userNotifications = [];
  List<Map<String, dynamic>> _globalNotifications = [];

  @override
  void initState() {
    super.initState();
    if (user != null) {
      // Listen to User Notifications
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
           _userNotifications = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['isGlobal'] = false;
            data['reference'] = doc.reference;
            return data;
          }).toList();
          _emitCombinedList();
        }
      });

      // Listen to Global Notifications
      FirebaseFirestore.instance
          .collection('global_notifications')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
           _globalNotifications = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['isGlobal'] = true;
            data['reference'] = doc.reference;
            return data;
          }).toList();
          _emitCombinedList();
        }
      });
    }
  }

  void _emitCombinedList() {
    final combined = [..._userNotifications, ..._globalNotifications];
    // Sort combined list by timestamp descending
    combined.sort((a, b) {
      Timestamp? t1 = a['timestamp'];
      Timestamp? t2 = b['timestamp'];
      if (t1 == null) return 1;
      if (t2 == null) return -1;
      return t2.compareTo(t1);
    });
    if (!_notificationsController.isClosed) {
      _notificationsController.add(combined);
    }
  }

  @override
  void dispose() {
    _notificationsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text("Please log in to see notifications.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting && !_notificationsController.hasListener) {
             // Basic loading state only initially
             return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index];
              final title = data['title'] ?? 'No Title';
              final body = data['body'] ?? 'No Body';
              final timestamp = data['timestamp'] as Timestamp?;
              final timeText = timestamp != null
                  ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                  : '';
              final isRead = data['read'] ?? false;
              final isGlobal = data['isGlobal'] ?? false;
              final reference = data['reference'] as DocumentReference?;

              // Use a Dismissible only for personal notifications
              Widget listTile = ListTile(
                tileColor: (!isGlobal && !isRead) ? Colors.blue.withOpacity(0.1) : null,
                leading: Icon(
                  isGlobal ? Icons.campaign : Icons.notifications, 
                  color: isGlobal ? Colors.orange : Colors.blue
                ),
                title: Text(title, style: TextStyle(fontWeight: (!isGlobal && !isRead) ? FontWeight.bold : FontWeight.normal)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body),
                    Text(timeText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                onTap: () {
                   if (!isGlobal && !isRead && reference != null) {
                     reference.update({'read': true});
                   }
                },
              );

              if (isGlobal) {
                return listTile;
              } else {
                return Dismissible(
                  key: Key(data['id']),
                  onDismissed: (direction) {
                    if (reference != null) {
                        reference.delete();
                    }
                  },
                  background: Container(color: Colors.red),
                  child: listTile,
                );
              }
            },
          );
        },
      ),
    );
  }
}
