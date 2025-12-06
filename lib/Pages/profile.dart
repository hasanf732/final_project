import 'dart:async';
import 'package:final_project/Pages/admin_page.dart';
import 'package:final_project/Pages/booking.dart';
import 'package:final_project/Pages/edit_profile_page.dart';
import 'package:final_project/Pages/notifications_page.dart';
import 'package:final_project/services/auth.dart';
import 'package:final_project/services/database.dart';
import 'package:final_project/services/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _isAdmin = false;

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
          
          // Check for admin role
          final bool isAdmin = (userData['role'] == 'admin') || (userData['isAdmin'] == true);

          if (!isAdmin) {
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
              _upcomingEventsCount = upcoming;
              _attendedEventsCount = attended;
            });
          }

          setState(() {
            _userName = userData['Name'] ?? 'No Name';
            _userMajor = userData['Major'] ?? "Not Set";
            _isAdmin = isAdmin;
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
    if (!mounted) return;
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
        await AuthMethods().signOut();
    }
  }

  Future<void> _launchFeedbackEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@univent.com',
      query: 'subject=UniVent App Feedback/Bug Report',
    );
    if (!await launchUrl(emailLaunchUri)) {
       if (!mounted) return;
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
        padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 100.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            if (!_isAdmin) _buildStatsSection(),
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
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                  _loadUserData();
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).cardColor, // Use theme color
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                  ),
                  child: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(_userName.isNotEmpty ? _userName : "Loading...", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(_userEmail, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600)),
         const SizedBox(height: 5),
        Text(_userMajor, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatColumn(_attendedEventsCount.toString(), "Attended"),
        _buildStatColumn(_upcomingEventsCount.toString(), "Upcoming"),
      ],
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    return Container(
       decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15.0),
           boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
        children: [
           SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: Icon(Icons.dark_mode_outlined, color: theme.colorScheme.primary),
            value: themeProvider.darkTheme,
            inactiveThumbColor: theme.colorScheme.onSurface.withAlpha(51),
            onChanged: (value) {
              themeProvider.setDarkTheme(value);
            },
          ),
          if (!_isAdmin) ...[
            const Divider(indent: 16, endIndent: 16, height: 1),
            ListTile(
              leading: Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary),
              title: const Text("My Bookings"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Booking())),
            ),
          ],
          const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
            title: const Text("Edit Profile"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
              _loadUserData();
            },
          ),
           const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: theme.colorScheme.primary),
            title: const Text("Notifications"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())),
          ),
           const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: Icon(Icons.feedback_outlined, color: theme.colorScheme.primary),
            title: const Text("Report Bug / Feedback"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _launchFeedbackEmail,
          ),
           const Divider(indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: Icon(Icons.share_outlined, color: theme.colorScheme.primary),
            title: const Text("Share UniVent"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Share.share('Check out UniVent, an awesome app for university events!'),
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
