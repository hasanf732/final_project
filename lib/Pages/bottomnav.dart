import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:final_project/Pages/booking.dart';
import 'package:final_project/Pages/home.dart';
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
  late UploadEvent upload;
  late Profile profile;
  int currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    home = Home();
    booking = Booking();
    upload = UploadEvent();
    profile = Profile();
    pages = [home, booking, upload, profile];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
          height: 65,
          backgroundColor: Colors.white,
          color: Color(0xFF00008B),
          animationDuration: Duration(milliseconds: 500),
          onTap: (int index) {
            setState(() {
              currentTabIndex = index;
            });
          },
          items: [
            Icon(Icons.home_outlined, color: Colors.white),
            Icon(Icons.book, color: Colors.white),
            Icon(Icons.cloud_upload_outlined, color: Colors.white),
            Icon(Icons.person_outlined, color: Colors.white),
          ]),
      body: pages[currentTabIndex],
    );
  }
}
