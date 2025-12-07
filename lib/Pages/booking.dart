import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class _BookingState extends State<Booking> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _handleRefresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() {});
    }
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
        children: [
          BookedEventsList(status: 'bookedEvents', onRefresh: _handleRefresh),
          BookedEventsList(status: 'attendedEvents', showPastEvents: true, onRefresh: _handleRefresh),
        ],
      ),
    );
  }
}

class BookedEventsList extends StatelessWidget {
  final String status;
  final bool showPastEvents;
  final Future<void> Function() onRefresh;

  const BookedEventsList({
    super.key,
    required this.status,
    this.showPastEvents = false,
    required this.onRefresh,
  });

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
          return _buildRefreshableEmptyView("No bookings found.");
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final eventIds = List<String>.from(userData[status] ?? []);

        if (eventIds.isEmpty) {
          return _buildRefreshableEmptyView("No events found in this category.");
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('News').where(FieldPath.documentId, whereIn: eventIds).snapshots(),
          builder: (context, eventSnapshot) {
            if (eventSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
              return _buildBookingShimmer(theme);
            }
            if (eventSnapshot.hasError) {
              return _buildRefreshableEmptyView("Error: ${eventSnapshot.error}");
            }
            if (!eventSnapshot.hasData || eventSnapshot.data!.docs.isEmpty) {
              return _buildRefreshableEmptyView("No event details found.");
            }

            final now = DateTime.now();
            var filteredDocs = eventSnapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final eventDate = (data['Date'] as Timestamp).toDate();
              if (showPastEvents) {
                return eventDate.isBefore(now);
              } else {
                return !eventDate.isBefore(now);
              }
            }).toList();

            if (filteredDocs.isEmpty) {
              return _buildRefreshableEmptyView("No events in this category.");
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = filteredDocs[index];
                          final data = event.data() as Map<String, dynamic>;
                          final imageUrl = data['Image'] as String? ?? '';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailPage(
                                    id: event.id,
                                    image: imageUrl,
                                    name: data['Name'] ?? 'Untitled Event',
                                    startDate: data['Date'] as Timestamp,
                                    endDate: data['endDate'] as Timestamp?,
                                    location: data['Location'] ?? 'No location specified',
                                    detail: data['Detail'] ?? 'No details available',
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10.0),
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              height: 80,
                                              width: 80,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                height: 80,
                                                width: 80,
                                                color: theme.colorScheme.surface.withAlpha(26),
                                              ),
                                              errorWidget: (context, url, error) => Image.asset(
                                                'Images/Eventposter1.png', // Placeholder from assets
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Image.asset(
                                              'Images/Eventposter1.png', // Placeholder from assets
                                              height: 80,
                                              width: 80,
                                              fit: BoxFit.cover,
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
                                              Text(DateFormat('yyyy-MM-dd').format((data['Date'] as Timestamp).toDate()), style: theme.textTheme.bodySmall),
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
                        childCount: filteredDocs.length,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRefreshableEmptyView(String message) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverFillRemaining(
            child: Center(child: Text(message)),
          )
        ],
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
          highlightColor: theme.colorScheme.surface.withAlpha(128),
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
