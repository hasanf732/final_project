import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Stream<List<DocumentSnapshot>>? _favoritesStream;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupFavoritesStream();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _setupFavoritesStream();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _setupFavoritesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDocStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

      if (mounted) {
        setState(() {
          _favoritesStream = userDocStream.asyncMap((userDoc) async {
            if (!userDoc.exists || userDoc.data()?['favoriteEvents'] == null) {
              return [];
            }
            List<String> favoriteEventIds = List<String>.from(userDoc.data()!['favoriteEvents']);
            if (favoriteEventIds.isEmpty) {
              return [];
            }

            List<Future<DocumentSnapshot>> futureDocs = [];
            for (String eventId in favoriteEventIds) {
              futureDocs.add(DatabaseMethods().getEventById(eventId));
            }
            var events = await Future.wait(futureDocs);

            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            return events.where((event) {
              if (!event.exists) return false;
              final data = event.data() as Map<String, dynamic>;
              final eventDate = (data['endDate'] ?? data['Date']) as Timestamp?;
              if (eventDate == null) return false;
              return !eventDate.toDate().isBefore(startOfToday);
            }).toList();
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _favoritesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no favorite events yet.\nTap the bookmark on an event to save it!',
                textAlign: TextAlign.center,
              ),
            );
          }

          var favoriteDocs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: favoriteDocs.length,
            itemBuilder: (context, index) {
              var eventData = favoriteDocs[index].data() as Map<String, dynamic>;
              var eventId = favoriteDocs[index].id;
              final startDate = eventData['Date'] as Timestamp?;
              final endDate = eventData['endDate'] as Timestamp?;

              String formattedDate;
              if (startDate != null) {
                if (endDate != null &&
                    (endDate.toDate().difference(startDate.toDate()).inDays > 0 ||
                        endDate.toDate().day != startDate.toDate().day)) {
                  formattedDate =
                      '${DateFormat('MMM dd').format(startDate.toDate())} - ${DateFormat('MMM dd, yyyy').format(endDate.toDate())}';
                } else {
                  formattedDate = DateFormat('MMM dd, yyyy').format(startDate.toDate());
                }
              } else {
                formattedDate = "Date N/A";
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: eventData['Image'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[300],
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        'Images/Eventposter1.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(eventData['Name'] ?? 'Unnamed Event', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${eventData['Location'] ?? 'No location'}\n$formattedDate"),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                    onPressed: () {
                      DatabaseMethods().removeFromFavorites(eventId);
                    },
                  ),
                  onTap: () {
                    if (startDate == null) return;
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPage(
                          id: eventId,
                          image: eventData['Image'] ?? '',
                          name: eventData['Name'] ?? 'Untitled Event',
                          startDate: startDate,
                          endDate: endDate,
                          location: eventData['Location'] ?? 'No location specified',
                          detail: eventData['Detail'] ?? 'No details available',
                        ),
                      ),
                    );
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
