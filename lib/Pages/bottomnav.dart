import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:final_project/Pages/booking.dart';
import 'package:final_project/Pages/home.dart';
import 'package:final_project/Pages/map_page.dart';
import 'package:final_project/admin/upload_event.dart';
import 'package:flutter/material.dart';
import 'package:final_project/Pages/profile.dart';

class Bottomnav extends StatefulWidget {
  const Bottomnav({super.key});

  @override
  State<Bottomnav> createState() => _BottomnavState();
}

class _BottomnavState extends State<Bottomnav> {
  late List<Widget> pages;
  late Home home;
  late Booking booking;
  late MapPage mapPage;
  late UploadEvent upload;
  late Profile profile;
  int currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    home = const Home();
    booking = const Booking();
    mapPage = const MapPage();
    upload = const UploadEvent();
    profile = const Profile();
    pages = [home, booking, mapPage, upload, profile];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final List<Widget> items = [
      Icon(Icons.home_outlined, color: currentTabIndex == 0 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.6)),
      Icon(Icons.book_outlined, color: currentTabIndex == 1 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.6)),
      Icon(Icons.map_outlined, color: currentTabIndex == 2 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.6)),
      Icon(Icons.cloud_upload_outlined, color: currentTabIndex == 3 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.6)),
      Icon(Icons.person_outlined, color: currentTabIndex == 4 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withOpacity(0.6)),
    ];

    return Scaffold(
      extendBody: true, // This is important for the transparent background
      bottomNavigationBar: CurvedNavigationBar(
        height: 65,
        backgroundColor: Colors.transparent, // Fixes the white spot
        color: isDarkMode ? const Color(0xFF1F1F1F) : theme.colorScheme.primary,
        buttonBackgroundColor: theme.colorScheme.primary,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (int index) {
          setState(() {
            currentTabIndex = index;
          });
        },
        items: items,
      ),
      body: pages[currentTabIndex],
    );
  }
}
