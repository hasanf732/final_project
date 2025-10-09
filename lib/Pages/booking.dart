import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    // Get the stream of the user's document
    final userStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    // Transform the user document stream into an event stream
    _bookedEventsStream = userStream.asyncMap((userDoc) async {
      if (!userDoc.exists || userDoc.data() == null) {
        return [];
      }

      Map<String, dynamic> userData = userDoc.data()!;
      List<String> eventIds = List<String>.from(userData['bookedEvents'] ?? []);

      if (eventIds.isEmpty) {
        return [];
      }

      // Fetch all booked events in a single, efficient query
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('News')
          .where(FieldPath.documentId, whereIn: eventIds)
          .get();

      // Map the event documents to a list of maps
      return eventsSnapshot.docs.map((doc) {
        Map<String, dynamic> eventData = doc.data();
        eventData['id'] = doc.id; // Add document ID to the map
        return eventData;
      }).toList();
    });
     setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(top: 50.0, left: 20.0, right: 20.0),
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xffe3e6ff), Color(0xfff1f3ff), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Bookings",
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 30.0,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.0),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _bookedEventsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Text(
                      "You haven't registered for any events yet.",
                      style: TextStyle(fontSize: 18.0, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ));
                  }

                  var bookedEvents = snapshot.data!;

                  return ListView.builder(
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
                          margin: EdgeInsets.only(bottom: 20.0),
                          elevation: 5.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
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
                                      color: Colors.grey.shade200,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      height: 80,
                                      width: 80,
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 15.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event['Name'] ?? 'Untitled Event',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18.0),
                                      ),
                                      SizedBox(height: 5.0),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16.0, color: Colors.grey.shade700),
                                          SizedBox(width: 5.0),
                                          Text(
                                            eventDateStr,
                                            style: TextStyle(fontSize: 14.0, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 3.0),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 16.0, color: Colors.grey.shade700),
                                          SizedBox(width: 5.0),
                                          Expanded(
                                            child: Text(
                                              event['Location'] ?? 'No location',
                                              style: TextStyle(fontSize: 14.0, color: Colors.grey.shade700),
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
            )
          ],
        ),
      ),
    );
  }
}
