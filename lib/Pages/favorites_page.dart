import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _setupFavoritesStream();
  }

  void _setupFavoritesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDocStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

      setState(() {
        _favoritesStream = userDocStream.asyncMap((userDoc) async {
          if (!userDoc.exists || userDoc.data()?['favoriteEvents'] == null) {
            return [];
          }
          List<String> favoriteEventIds = List<String>.from(userDoc.data()!['favoriteEvents']);
          if (favoriteEventIds.isEmpty) {
            return [];
          }

          // Fetch each favorite event document
          List<Future<DocumentSnapshot>> futureDocs = [];
          for (String eventId in favoriteEventIds) {
            futureDocs.add(DatabaseMethods().getEventById(eventId));
          }
          return await Future.wait(futureDocs);
        });
      });
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
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      eventData['Image'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(eventData['Name'] ?? 'Unnamed Event', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(eventData['Location'] ?? 'No location'),
                  trailing: IconButton(
                    icon: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                    onPressed: () {
                      DatabaseMethods().removeFromFavorites(eventId);
                    },
                  ),
                  onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPage(
                          id: eventId,
                          image: eventData['Image'] ?? '',
                          name: eventData['Name'] ?? 'Untitled Event',
                          date: eventData['Date'] != null ? DateFormat('yyyy-MM-dd').format((eventData['Date'] as Timestamp).toDate()) : '',
                          location: eventData['Location'] ?? 'No location specified',
                          detail: eventData['Detail'] ?? 'No details available',
                          time: eventData['Time'] ?? 'No time specified',
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
