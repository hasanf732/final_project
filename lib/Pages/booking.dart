import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/Pages/qr_display_page.dart';
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

class _BookingState extends State<Booking> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Registered'),
            Tab(text: 'Attended'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BookedEventsList(status: 'bookedEvents'),
          BookedEventsList(status: 'attendedEvents'),
        ],
      ),
    );
  }
}

class BookedEventsList extends StatelessWidget {
  final String status;
  const BookedEventsList({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your bookings."));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: DatabaseMethods().getUserStream(user.uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildBookingShimmer(theme);
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text("No bookings found."));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final eventIds = List<String>.from(userData[status] ?? []);

        if (eventIds.isEmpty) {
          return Center(child: Text("No events found in this category."));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('News').where(FieldPath.documentId, whereIn: eventIds).snapshots(),
          builder: (context, eventSnapshot) {
            if (eventSnapshot.connectionState == ConnectionState.waiting) {
              return _buildBookingShimmer(theme);
            }
            if (eventSnapshot.hasError) {
              return Center(child: Text("Error: ${eventSnapshot.error}"));
            }
            if (!eventSnapshot.hasData || eventSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No event details found."));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: eventSnapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final event = eventSnapshot.data!.docs[index];
                final data = event.data() as Map<String, dynamic>;
                DateTime? eventDate;
                final dateData = data['Date'];
                String eventDateStr = '';
                if (dateData is Timestamp) {
                  eventDate = dateData.toDate();
                  eventDateStr = DateFormat('yyyy-MM-dd').format(eventDate);
                }
                return GestureDetector(
                  onTap: () {
                    if (status == 'bookedEvents') {
                      String qrData = "${user.uid}_${event.id}";
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QrDisplayPage(
                            qrData: qrData,
                            eventName: data['Name'] ?? 'Untitled Event',
                            eventDate: eventDateStr,
                            eventLocation: data['Location'] ?? 'No location specified',
                          ),
                        ),
                      );
                    } else {
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailPage(
                            id: event.id,
                            image: data['Image'] ?? '',
                            name: data['Name'] ?? 'Untitled Event',
                            date: eventDateStr,
                            location: data['Location'] ?? 'No location specified',
                            detail: data['Detail'] ?? 'No details available',
                            time: data['Time'] ?? 'No time specified',
                          ),
                        ),
                      );
                    }
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: CachedNetworkImage(
                              imageUrl: data['Image'] ?? '',
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
                                child: Icon(Icons.broken_image, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['Name'] ?? 'Untitled Event',
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
                                        data['Location'] ?? 'No location',
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
        );
      },
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
                  Container(width: 80, height: 80, color: theme.colorScheme.surface),
                  const SizedBox(width: 15.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 16, width: 200, color: theme.colorScheme.surface),
                        const SizedBox(height: 8.0),
                        Container(height: 14, width: 100, color: theme.colorScheme.surface),
                        const SizedBox(height: 8.0),
                        Container(height: 14, width: 150, color: theme.colorScheme.surface),
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
