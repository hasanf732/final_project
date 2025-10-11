import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class Booking extends StatefulWidget {
  const Booking({super.key});

  @override
  State<Booking> createState() => _BookingState();
}

class _BookingState extends State<Booking> {
  Stream<List<Map<String, dynamic>>>? _bookedEventsStream;

  @override
  void initState() {
    super.initState();
    _loadBookedEvents();
  }

  void _loadBookedEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final userStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    _bookedEventsStream = userStream.asyncMap((userDoc) async {
      if (!userDoc.exists || userDoc.data() == null) {
        return [];
      }

      Map<String, dynamic> userData = userDoc.data()!;
      List<String> eventIds = List<String>.from(userData['bookedEvents'] ?? []);

      if (eventIds.isEmpty) {
        return [];
      }

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('News')
          .where(FieldPath.documentId, whereIn: eventIds)
          .get();

      return eventsSnapshot.docs.map((doc) {
        Map<String, dynamic> eventData = doc.data();
        eventData['id'] = doc.id;
        return eventData;
      }).toList();
    });
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bookedEventsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildBookingShimmer(theme);
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text(
              "You haven't registered for any events yet.",
              textAlign: TextAlign.center,
            ));
          }

          var bookedEvents = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: bookedEvents.length,
            itemBuilder: (context, index) {
              var event = bookedEvents[index];
              DateTime? eventDate;
              final dateData = event['Date'];
              String eventDateStr = '';
              if (dateData is Timestamp) {
                eventDate = dateData.toDate();
                eventDateStr = DateFormat('yyyy-MM-dd').format(eventDate);
              }
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DetailPage(
                                id: event['id'],
                                image: event['Image'] ?? '',
                                name: event['Name'] ?? 'Untitled Event',
                                date: eventDateStr,
                                location: event['Location'] ?? 'No location specified',
                                detail: event['Detail'] ?? 'No details available',
                                time: event['Time'] ?? 'No time specified',
                              )));
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: CachedNetworkImage(
                            imageUrl: event['Image'] ?? '',
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 80,
                              width: 80,
                              color: theme.colorScheme.surface.withOpacity(0.1),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 80,
                              width: 80,
                              color: theme.colorScheme.surface.withOpacity(0.1),
                              child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['Name'] ?? 'Untitled Event',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5.0),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16.0, color: theme.textTheme.bodySmall?.color),
                                  const SizedBox(width: 5.0),
                                  Text(eventDateStr, style: theme.textTheme.bodySmall),
                                ],
                              ),
                              const SizedBox(height: 3.0),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16.0, color: theme.textTheme.bodySmall?.color),
                                  const SizedBox(width: 5.0),
                                  Expanded(
                                    child: Text(
                                      event['Location'] ?? 'No location',
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingShimmer(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surface,
          highlightColor: theme.colorScheme.surface.withOpacity(0.5),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(width: 80, height: 80, color: Colors.white),
                  const SizedBox(width: 15.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 16, width: 200, color: Colors.white),
                        const SizedBox(height: 8.0),
                        Container(height: 14, width: 100, color: Colors.white),
                        const SizedBox(height: 8.0),
                        Container(height: 14, width: 150, color: Colors.white),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
