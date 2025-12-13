import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/Pages/favorites_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:table_calendar/table_calendar.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String _userName = "";
  String? _selectedCategory;
  Set<String> _bookmarkedEventIds = {};
  final Set<String> _bookedEventIds = {};
  final Set<String> _attendedEventIds = {};
  Position? _currentPosition;
  Map<String, int> _registrationCounts = {};

  StreamSubscription? _bookmarksSubscription;
  StreamSubscription? _userEventsSubscription;
  StreamSubscription? _registrationCountsSubscription;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  // Calendar View State
  bool _isCalendarView = false;

  final List<Map<String, String>> _categories = [
    {'name': 'Music', 'image': 'Images/music1.png'},
    {'name': 'Media', 'image': 'Images/videography1.png'},
    {'name': 'Sport', 'image': 'Images/sport1.png'},
    {'name': 'Astro', 'image': 'Images/astro1.png'},
    {'name': 'Art', 'image': 'Images/Art1.png'},
    {'name': 'Film', 'image': 'Images/Film.png'},
    {'name': 'Volunteer', 'image': 'Images/volunteer.png'},
    {'name': 'Cyber', 'image': 'Images/cyber-security.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _handleRefresh();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookmarksSubscription?.cancel();
    _userEventsSubscription?.cancel();
    _registrationCountsSubscription?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    _listenToBookmarks();
    _listenToUserEvents();
    _listenToRegistrationCounts();
    await _determinePosition();
  }

  Future<void> _handleRefresh() async {
    await _loadInitialData();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await DatabaseMethods().getUser(user.uid);
        if (userDoc.exists && userDoc.data() != null && mounted) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = (userData['Name'] ?? '').split(' ').first;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _userName = "User");
        }
      }
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Silently catch errors.
    }
  }

  void _listenToBookmarks() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _bookmarksSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((userDoc) {
        if (mounted &&
            userDoc.exists &&
            userDoc.data()!.containsKey('favoriteEvents')) {
          final favs = List<String>.from(userDoc.data()!['favoriteEvents']);
          if (mounted) {
            setState(() {
              _bookmarkedEventIds = favs.toSet();
            });
          }
        }
      });
    }
  }

  void _listenToUserEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEventsSubscription =
          DatabaseMethods().getUserStream(user.uid).listen((userDoc) {
        if (mounted && userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final booked = data.containsKey('bookedEvents')
              ? List<dynamic>.from(data['bookedEvents'])
              : [];
          final attended = data.containsKey('attendedEvents')
              ? List<dynamic>.from(data['attendedEvents'])
              : [];
          setState(() {
            _bookedEventIds.clear();
            _bookedEventIds.addAll(booked.map((e) => e.toString()));
            _attendedEventIds.clear();
            _attendedEventIds.addAll(attended.map((e) => e.toString()));
          });
        }
      });
    }
  }

  void _listenToRegistrationCounts() {
    _registrationCountsSubscription =
        DatabaseMethods().getEventRegistrationCounts().listen((counts) {
      if (mounted) {
        setState(() {
          _registrationCounts = counts;
        });
      }
    });
  }

  void _toggleBookmark(String eventId) {
    setState(() {
      if (_bookmarkedEventIds.contains(eventId)) {
        _bookmarkedEventIds.remove(eventId);
        DatabaseMethods().removeFromFavorites(eventId);
      } else {
        _bookmarkedEventIds.add(eventId);
        DatabaseMethods().addToFavorites(eventId);
      }
    });
  }

  List<DocumentSnapshot> _filterUpcomingEvents(List<DocumentSnapshot> events) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return events.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final eventDate = (data['endDate'] ?? data['Date']) as Timestamp?;
      if (eventDate == null) return false;
      return !eventDate.toDate().isBefore(startOfToday);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSearching = _searchQuery.isNotEmpty;
    final bool isFiltering = _selectedCategory != null;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            title: Text(
              "UniVent",
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            centerTitle: false,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: IconButton(
                  icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_today, color: theme.colorScheme.primary),
                  onPressed: () {
                      setState(() {
                          _isCalendarView = !_isCalendarView;
                      });
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.bookmarks_outlined, color: theme.colorScheme.primary),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FavoritesPage())),
                ),
              ),
            ],
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _handleRefresh,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, ${_userName.isNotEmpty ? _userName : 'User'}! 👋",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Discover events near you",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isCalendarView)
            SliverToBoxAdapter(
                child: Column(
                children: [
                    Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10),
                    child: _AnimatedSearchBar(controller: _searchController),
                    ),
                    const SizedBox(height: 16),
                    _buildCategorySelector(),
                ],
                ),
            ),
          StreamBuilder<QuerySnapshot>(
            stream: DatabaseMethods().getEventDetails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverList(delegate: SliverChildListDelegate([_buildShimmerPlaceholder()]));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    heightFactor: 10,
                    child: Text("No events available right now."),
                  ),
                );
              }

              List<DocumentSnapshot> allEvents = _filterUpcomingEvents(snapshot.data!.docs);

              if (_isCalendarView) {
                  return SliverToBoxAdapter(
                    child: EventCalendar(
                      events: allEvents,
                      bookmarkedEventIds: _bookmarkedEventIds,
                      onToggleBookmark: _toggleBookmark,
                    ),
                  );
              }

              if (isSearching || isFiltering) {
                return _buildFilteredList(allEvents);
              }
              
              return _buildHomeContent(allEvents);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(List<DocumentSnapshot> allEvents) {
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSectionHeader("Discover"),
        _buildHorizontalEventsList(getDiscoverEvents(allEvents)),
        _buildSectionHeader("What's Hot"),
        _buildHorizontalEventsList(getHotEvents(allEvents)),
        _buildSectionHeader("Top Rated"),
        _buildHorizontalEventsList(getTopRatedEvents(allEvents)),
        _buildSectionHeader("Nearest To You"),
        _buildVerticalEventsList(getNearestEvents(allEvents)),
        const SizedBox(height: 100),
      ]),
    );
  }

  List<DocumentSnapshot> getDiscoverEvents(List<DocumentSnapshot> allEvents) {
    allEvents.sort((a, b) {
      var aDate = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      var bDate = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return allEvents.take(7).toList();
  }

  List<DocumentSnapshot> getHotEvents(List<DocumentSnapshot> allEvents) {
    var sortedEvents = allEvents.toList();
    sortedEvents.sort((a, b) {
      final aCount = _registrationCounts[a.id] ?? 0;
      final bCount = _registrationCounts[b.id] ?? 0;
      return bCount.compareTo(aCount);
    });
    return sortedEvents.take(10).toList();
  }

  List<DocumentSnapshot> getTopRatedEvents(List<DocumentSnapshot> allEvents) {
    var docsWithRatings = allEvents.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final double avgRating = _calculateAverageRating(data['ratings']);
      return MapEntry(doc, avgRating);
    }).where((entry) => entry.value > 0).toList();

    docsWithRatings.sort((a, b) => b.value.compareTo(a.value));

    return docsWithRatings.map((entry) => entry.key).take(7).toList();
  }

  List<MapEntry<DocumentSnapshot, double>> getNearestEvents(List<DocumentSnapshot> allEvents) {
    if (_currentPosition == null) return [];

    var docsWithDistances = allEvents.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitude'];
      final lon = data['longitude'];

      if (lat is num && lon is num) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat.toDouble(),
          lon.toDouble(),
        );
        return MapEntry(doc, distance);
      }
      return null;
    }).whereType<MapEntry<DocumentSnapshot, double>>().toList();

    docsWithDistances.sort((a, b) => a.value.compareTo(b.value));

    // Limit to 5 nearest events
    return docsWithDistances.take(5).toList();
  }

  double _calculateAverageRating(Map<String, dynamic>? ratings) {
    if (ratings == null || ratings.isEmpty) return 0.0;
    double total = 0;
    ratings.forEach((key, value) {
      total += (value['rating'] as num? ?? 0);
    });
    return total / ratings.length;
  }

  Widget _buildFilteredList(List<DocumentSnapshot> allEvents) {
      List<DocumentSnapshot> events = allEvents;

      if (_selectedCategory != null) {
        events = events.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['Category'] == _selectedCategory;
        }).toList();
      }

      if (_searchQuery.isNotEmpty) {
        events = events.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['Name'] as String? ?? '';
          final detail = data['Detail'] as String? ?? '';
          final query = _searchQuery.toLowerCase();
          return name.toLowerCase().contains(query) ||
              detail.toLowerCase().contains(query);
        }).toList();
      }

      if (events.isEmpty) {
        return const SliverToBoxAdapter(
          child: Center(
            heightFactor: 10,
            child: Text("No events match your criteria."),
          ),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == events.length) {
                return const SizedBox(height: 100);
            }
            final event = events[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
              child: EventCard(
                  event: event,
                  isBookmarked: _bookmarkedEventIds.contains(event.id),
                  onToggleBookmark: _toggleBookmark),
            );
          },
          childCount: events.length + 1,
        ),
      );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
      child: Row(
        children: [
          Container(
            width: 4, 
            height: 24, 
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4)
            )
          ),
          const SizedBox(width: 12),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildHorizontalEventsList(List<DocumentSnapshot> events) {
    if (events.isEmpty) {
      return const SizedBox(
          height: 100,
          child: Center(child: Text("No events in this category yet.")));
    }

    // Increased height to 260 to prevent overflow
    return SizedBox(
      height: 260, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventCard(
              event: event,
              isBookmarked: _bookmarkedEventIds.contains(event.id),
              isFeatured: true,
              onToggleBookmark: _toggleBookmark);
        },
      ),
    );
  }

  Widget _buildVerticalEventsList(List<MapEntry<DocumentSnapshot, double>> events) {
    if (_currentPosition == null) {
      return const Center(
          heightFactor: 5,
          child: Text("Enable location to see nearby events."));
    }
    if (events.isEmpty) {
      return const Center(heightFactor: 5, child: Text("No events nearby."));
    }

    return Column(
      children: events.map((eventEntry) {
          final event = eventEntry.key;
          final distance = eventEntry.value; // in meters
          return Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
            child: EventCard(
              event: event,
              isBookmarked: _bookmarkedEventIds.contains(event.id),
              isFeatured: false,
              distance: distance,
              onToggleBookmark: _toggleBookmark,
            ),
          );
      }).toList(),
    );
  }


  Widget _buildCategorySelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length + 1, // +1 for the "All" button
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategory == null;
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildCategoryChip('All', null, isSelected),
            );
          }

          final category = _categories[index - 1];
          final isSelected = _selectedCategory == category['name'];

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _buildCategoryChip(category['name']!, category['image'], isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? imagePath, bool isSelected) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? null : label == 'All' ? null : label;
        });
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
          ]
        ),
        child: Row(
          children: [
            if (imagePath != null) ...[
              Image.asset(imagePath, width: 20, height: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildShimmerPlaceholder() {
  return Column(
    children: [
      _buildSectionHeader(""), // Placeholder for header
      _buildHorizontalShimmer(),
      _buildSectionHeader(""), // Placeholder for header
      _buildHorizontalShimmer(),
      _buildSectionHeader(""), // Placeholder for header
      _buildVerticalShimmer(),
    ],
  );
}

  Widget _buildHorizontalShimmer() {
    return SizedBox(
      height: 225,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surface,
          highlightColor: Theme.of(context).colorScheme.surface.withAlpha(128),
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalShimmer() {
    return Column(
      children: List.generate(
          3,
          (index) => Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.surface,
                highlightColor:
                    Theme.of(context).colorScheme.surface.withAlpha(128),
                child: Container(
                  height: 220,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )),
    );
  }
}


class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;

  const _AnimatedSearchBar({required this.controller});

  @override
  __AnimatedSearchBarState createState() => __AnimatedSearchBarState();
}

class __AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  Timer? _hintTextTimer;
  int _hintTextIndex = 0;
  bool _isSearching = false;

  final List<String> _hintTexts = [
    "Search for events...",
    "Try 'Music'",
    "Try 'Art'",
    "Try 'Sports'"
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) {
        setState(() {
          _isSearching = widget.controller.text.isNotEmpty;
        });
      }
    });
    _hintTextTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isSearching) {
        setState(() {
          _hintTextIndex = (_hintTextIndex + 1) % _hintTexts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _hintTextTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: '',
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.only(left: 48.0),
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.5),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _hintTexts[_hintTextIndex],
                    key: ValueKey<int>(_hintTextIndex),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EventCalendar extends StatefulWidget {
  final List<DocumentSnapshot> events;
  final Set<String> bookmarkedEventIds;
  final Function(String) onToggleBookmark;

  const EventCalendar({
    super.key,
    required this.events,
    required this.bookmarkedEventIds,
    required this.onToggleBookmark,
  });

  @override
  State<EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Map<DateTime, List<DocumentSnapshot>> _groupedEvents;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _groupedEvents = _groupEventsByDate(widget.events);
  }

  @override
  void didUpdateWidget(EventCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _groupedEvents = _groupEventsByDate(widget.events);
    }
  }

  Map<DateTime, List<DocumentSnapshot>> _groupEventsByDate(List<DocumentSnapshot> events) {
    Map<DateTime, List<DocumentSnapshot>> data = {};
    for (var event in events) {
        final eventData = event.data() as Map<String, dynamic>;
        final timestamp = eventData['Date'] as Timestamp?;
        if (timestamp != null) {
            final date = timestamp.toDate();
            final normalizedDate = DateTime(date.year, date.month, date.day);
            if (data[normalizedDate] == null) data[normalizedDate] = [];
            data[normalizedDate]!.add(event);
        }
    }
    return data;
  }

  List<DocumentSnapshot> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _groupedEvents[normalizedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
      final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

      return Column(
          children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CalendarFormat>(
                          value: _calendarFormat,
                          isDense: true,
                          icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.primary),
                          items: const [
                            DropdownMenuItem(value: CalendarFormat.month, child: Text("Month")),
                            DropdownMenuItem(value: CalendarFormat.twoWeeks, child: Text("2 Weeks")),
                            DropdownMenuItem(value: CalendarFormat.week, child: Text("Week")),
                          ],
                          onChanged: (format) {
                            if (format != null) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                        CalendarFormat.twoWeeks: '2 Weeks',
                        CalendarFormat.week: 'Week',
                      },
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                          });
                      },
                      onFormatChanged: (format) {
                          setState(() {
                              _calendarFormat = format;
                          });
                      },
                      onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                      },
                      eventLoader: (day) {
                          return _getEventsForDay(day);
                      },
                      calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                          ),
                          markerDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              shape: BoxShape.circle,
                          )
                      ),
                    ),
                  ),
              ),
              const SizedBox(height: 20),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Text(
                          "Events on ",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)
                      ),
                      Text(
                          DateFormat('MMM dd').format(_selectedDay ?? DateTime.now()),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          )
                      ),
                    ],
                  ),
              ),
              const SizedBox(height: 10),
              if (selectedEvents.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            "No events on this day",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                  )
              else
                  ...selectedEvents.map((event) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: EventCard(
                          event: event, 
                          isBookmarked: widget.bookmarkedEventIds.contains(event.id),
                          onToggleBookmark: widget.onToggleBookmark
                      ),
                  )),
              const SizedBox(height: 100),
          ],
      );
  }
}

class EventCard extends StatelessWidget {
  final DocumentSnapshot event;
  final bool isBookmarked;
  final bool isFeatured;
  final double? distance;
  final Function(String) onToggleBookmark;

  const EventCard({
    super.key,
    required this.event,
    required this.isBookmarked,
    required this.onToggleBookmark,
    this.isFeatured = false,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final data = event.data() as Map<String, dynamic>;
    final theme = Theme.of(context);

    final startDate = data['Date'] as Timestamp?;
    final endDate = data['endDate'] as Timestamp?;

    final card = Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (startDate == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(
                  id: event.id,
                  image: data['Image'] ?? '',
                  name: data['Name'] ?? 'Untitled Event',
                  startDate: startDate,
                  endDate: endDate,
                  location: data['Location'] ?? 'No location',
                  detail: data['Detail'] ?? '',
                  latitude: data['latitude'] as double?,
                  longitude: data['longitude'] as double?,
                ),
              ),
            );
          },
          child: SizedBox(
            width: isFeatured ? 280 : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: data['Image'] ?? '',
                        height: isFeatured ? 120 : 115, // Reduced height
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 130,
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 130,
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => onToggleBookmark(event.id),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              )
                            ]
                          ),
                          child: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: isBookmarked ? theme.colorScheme.primary : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    if (distance != null)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${(distance! / 1000).toStringAsFixed(1)} km',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['Name'] ?? 'Untitled Event',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded( // Added Expanded
                            child: Text(
                              startDate != null
                                  ? DateFormat('MMM dd, yyyy • h:mm a').format(startDate.toDate())
                                  : "Date N/A",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data['Location'] ?? 'No location',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return isFeatured
        ? Padding(padding: const EdgeInsets.only(right: 16), child: card)
        : card;
  }
}
