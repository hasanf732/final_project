import 'dart:async';
import 'package:final_project/Pages/booking.dart';
import 'package:final_project/Pages/signup.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String _userName = "";
  String _userEmail = "";
  String _userPhotoUrl = "";
  String _userMajor = "Not Set";
  int _upcomingEventsCount = 0;
  int _attendedEventsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _userEmail = user.email ?? "";
          _userPhotoUrl = user.photoURL ?? "";
        });
      }

      try {
        DocumentSnapshot userDoc = await DatabaseMethods().getUser(user.uid);
        if (userDoc.exists && userDoc.data() != null && mounted) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          List<String> bookedEventIds = List<String>.from(userData['bookedEvents'] ?? []);

          int upcoming = 0;
          int attended = 0;

          for (String eventId in bookedEventIds) {
            DocumentSnapshot eventDoc = await DatabaseMethods().getEventById(eventId);
            if (eventDoc.exists) {
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final eventDate = (eventData['Date'] as Timestamp).toDate();
              if (eventDate.isAfter(DateTime.now())) {
                upcoming++;
              } else {
                attended++;
              }
            }
          }

          setState(() {
            _userName = userData['Name'] ?? 'No Name';
            _userMajor = userData['Major'] ?? "Not Set";
            _upcomingEventsCount = upcoming;
            _attendedEventsCount = attended;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _userName = "User"; // Fallback name
          });
        }
      }
    }
  }

  Future<void> _logout() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: const Text('Log Out'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Signup()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _launchFeedbackEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@univent.com',
      query: 'subject=UniVent App Feedback/Bug Report',
    );
    if (!await launchUrl(emailLaunchUri)) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch email client.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildStatsSection(),
            const SizedBox(height: 10),
            _buildMenu(),
            const SizedBox(height: 20),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          children: [
             CircleAvatar(
              radius: 50,
              backgroundImage: _userPhotoUrl.isNotEmpty ? NetworkImage(_userPhotoUrl) : null,
              child: _userPhotoUrl.isEmpty ? const Icon(Icons.person, size: 60) : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                ),
                child: const Icon(Icons.edit, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(_userName.isNotEmpty ? _userName : "Loading...", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(_userEmail, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
         const SizedBox(height: 5),
        Text(_userMajor, style: TextStyle(fontSize: 16, color: Colors.blue.shade800, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatColumn(_attendedEventsCount.toString(), "Attended"),
        _buildStatColumn(_upcomingEventsCount.toString(), "Upcoming"),
        // You can add a condition to show "Hosted" for organizers
        // _buildStatColumn("5", "Hosted"), 
      ],
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
      ],
    );
  }

  Widget _buildMenu() {
    return Container(
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
           boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text("My Bookings"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Booking())),
          ),
          const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Edit Profile"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
           const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text("Notifications"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
           const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text("Report Bug / Feedback"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _launchFeedbackEmail,
          ),
           const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text("Share UniVent"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ],
      ),
    );
  }

   Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
           padding: const EdgeInsets.symmetric(vertical: 15),
           side: BorderSide(color: Colors.red.shade300),
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: const Text("Log Out", style: TextStyle(fontSize: 16, color: Colors.red)),
      ),
    );
  }
}
