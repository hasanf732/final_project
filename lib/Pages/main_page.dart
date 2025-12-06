import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:final_project/Pages/admin_page.dart';
import 'package:final_project/Pages/booking.dart';
import 'package:final_project/Pages/home.dart';
import 'package:final_project/Pages/map_page.dart';
import 'package:final_project/Pages/profile.dart';
import 'package:final_project/services/auth.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _isLoading = true;

  late List<Widget> _pages;
  late List<Widget> _navBarItems;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    bool isAdmin = await AuthMethods().isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _setupNavigation();
        _isLoading = false;
      });
    }
  }

  void _setupNavigation() {
    if (_isAdmin) {
      _pages = [
        const Home(),
        const MapPage(),
        const AdminPanelPage(),
        const Profile(),
      ];
      _navBarItems = const <Widget>[
        Icon(Icons.home, size: 30),
        Icon(Icons.map, size: 30),
        Icon(Icons.admin_panel_settings, size: 30),
        Icon(Icons.person, size: 30),
      ];
    } else {
      _pages = [
        const Home(),
        const MapPage(),
        const Booking(),
        const Profile(),
      ];
      _navBarItems = const <Widget>[
        Icon(Icons.home, size: 30),
        Icon(Icons.map, size: 30),
        Icon(Icons.book_online, size: 30),
        Icon(Icons.person, size: 30),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 75.0,
        items: _navBarItems,
        color: theme.colorScheme.surface,
        buttonBackgroundColor: theme.colorScheme.primary,
        backgroundColor: Colors.transparent,
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
