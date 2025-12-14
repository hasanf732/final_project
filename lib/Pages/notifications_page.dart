import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final StreamController<List<Map<String, dynamic>>> _notificationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  List<Map<String, dynamic>> _userNotifications = [];
  List<Map<String, dynamic>> _globalNotifications = [];
  Set<String> _dismissedGlobalIds = {};

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _loadDismissedIds();
      _listenForNotifications();
    }
  }

  void _listenForNotifications() {
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
        .limit(30) // Limit to recent 30 global announcements
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

  Future<void> _loadDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dismissedGlobalIds = (prefs.getStringList('dismissed_notifications') ?? []).toSet();
    });
    _emitCombinedList(); // Re-filter list after loading dismissed IDs
  }

  void _dismissGlobalNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dismissedGlobalIds.add(id);
    });
    await prefs.setStringList('dismissed_notifications', _dismissedGlobalIds.toList());
    _emitCombinedList();
  }

  void _emitCombinedList() {
    // Filter out dismissed global notifications
    final filteredGlobal = _globalNotifications.where((notif) => !_dismissedGlobalIds.contains(notif['id'])).toList();

    final combined = [..._userNotifications, ...filteredGlobal];
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

  Future<void> _clearAllNotifications() async {
    if (user == null) return;

    // 1. Delete personal notifications
    final personalNotifsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('notifications')
        .get();
    
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in personalNotifsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // 2. Dismiss all currently visible global notifications
    final prefs = await SharedPreferences.getInstance();
    final currentlyVisibleGlobalIds = _globalNotifications.map((n) => n['id'] as String).toList();
    setState(() {
      _dismissedGlobalIds.addAll(currentlyVisibleGlobalIds);
    });
    await prefs.setStringList('dismissed_notifications', _dismissedGlobalIds.toList());
    _emitCombinedList(); // Refresh the UI
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
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All',
            onPressed: () {
              if (_userNotifications.isEmpty && _globalNotifications.where((n) => !_dismissedGlobalIds.contains(n['id'])).isEmpty) return;
              showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Notifications?'),
                    content: const Text('Are you sure you want to remove all notifications?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(onPressed: () {
                        _clearAllNotifications();
                        Navigator.pop(context);
                      }, child: const Text('Clear', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
            },
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (!snapshot.hasData) {
             return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

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

              return Dismissible(
                  key: Key(data['id']),
                  onDismissed: (direction) {
                    if (isGlobal) {
                       _dismissGlobalNotification(data['id']);
                    } else if (reference != null) {
                        reference.delete();
                    }
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
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
                  ),
                );
            },
          );
        },
      ),
    );
  }
}
