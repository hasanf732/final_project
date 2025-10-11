import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:final_project/Pages/booking.dart';
import 'package:final_project/Pages/home.dart';
import 'package:final_project/Pages/map_page.dart';
import 'package:final_project/Pages/profile.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const Home(),
    const MapPage(),
    const Booking(),
    const Profile(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 75.0,
        items: const <Widget>[
          Icon(Icons.home, size: 30),
          Icon(Icons.map, size: 30),
          Icon(Icons.book_online, size: 30),
          Icon(Icons.person, size: 30),
        ],
        color: theme.colorScheme.surface,
        buttonBackgroundColor: theme.colorScheme.primary,
        backgroundColor: theme.scaffoldBackgroundColor,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        letIndexChange: (index) => true,
      ),
    );
  }
}
