import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/Pages/favorites_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

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

  StreamSubscription? _bookmarksSubscription;
  StreamSubscription? _userEventsSubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookmarksSubscription?.cancel();
    _userEventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    _listenToBookmarks();
    _listenToUserEvents();
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
              "Hello, ${_userName.isNotEmpty ? _userName : 'User'}!",
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.bookmarks, color: theme.colorScheme.primary, size: 28),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FavoritesPage())),
              ),
            ],
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _handleRefresh,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10),
                  child: _AnimatedSearchBar(controller: _searchController),
                ),
                const SizedBox(height: 12),
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
        _buildSectionHeader("Discover 🚀"),
        _buildHorizontalEventsList(getDiscoverEvents(allEvents)),
        _buildSectionHeader("What's Hot 🔥"),
        _buildHorizontalEventsList(getHotEvents(allEvents)),
        _buildSectionHeader("Top Rated ⭐"),
        _buildHorizontalEventsList(getTopRatedEvents(allEvents)),
        _buildSectionHeader("Nearest To You 📍"),
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
    var docs = allEvents.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data.containsKey('ratings') && (data['ratings'] as Map).isNotEmpty;
    }).toList();

    docs.sort((a, b) {
      var aRatings = (a.data() as Map<String, dynamic>)['ratings']?.length ?? 0;
      var bRatings = (b.data() as Map<String, dynamic>)['ratings']?.length ?? 0;
      return bRatings.compareTo(aRatings);
    });

    return docs.take(7).toList();
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

    return docsWithDistances.take(10).toList();
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
              child: _buildEventCard(event,
                  isBookmarked: _bookmarkedEventIds.contains(event.id)),
            );
          },
          childCount: events.length + 1,
        ),
      );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 20.0, right: 20.0, top: 24.0, bottom: 16.0),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHorizontalEventsList(List<DocumentSnapshot> events) {
    if (events.isEmpty) {
      return const SizedBox(
          height: 100,
          child: Center(child: Text("No events in this category yet.")));
    }

    return SizedBox(
      height: 225,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event,
              isBookmarked: _bookmarkedEventIds.contains(event.id),
              isFeatured: true);
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
            child: _buildEventCard(
              event,
              isBookmarked: _bookmarkedEventIds.contains(event.id),
              isFeatured: false,
              distance: distance,
            ),
          );
      }).toList(),
    );
  }


  Widget _buildCategorySelector() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length + 1, // +1 for the "All" button
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategory == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: const Text('All'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            );
          }

          final category = _categories[index - 1];
          final isSelected = _selectedCategory == category['name'];

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(category['name']!),
              avatar: Image.asset(category['image']!, width: 20),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category['name'] : null;
                });
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot event, {bool isBookmarked = false, bool isFeatured = false, double? distance}) {
    final data = event.data() as Map<String, dynamic>;
    final theme = Theme.of(context);

    final startDate = data['Date'] as Timestamp?;
    final endDate = data['endDate'] as Timestamp?;

    final card = Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      data['Image'] ?? 'https://via.placeholder.com/280x120',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleBookmark(event.id),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withAlpha(102),
                        radius: 18,
                        child: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? theme.colorScheme.primary : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  if (distance != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(distance / 1000).toStringAsFixed(1)} km away',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['Name'] ?? 'Untitled Event',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          startDate != null
                              ? (endDate != null
                                  ? '${DateFormat('MMM dd').format(startDate.toDate())} - ${DateFormat('MMM dd, yyyy').format(endDate.toDate())}'
                                  : DateFormat('MMM dd, yyyy').format(startDate.toDate()))
                              : "Date N/A",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data['Location'] ?? 'No location',
                            style: theme.textTheme.bodySmall,
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
    );

    return isFeatured
        ? Padding(padding: const EdgeInsets.only(right: 16), child: card)
        : card;
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
    "Search for Events",
    "Search for Art",
    "Search for Sport",
    "Search for Music"
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

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: '',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.white,
          ),
        ),
        if (!_isSearching)
          Padding(
            padding: const EdgeInsets.only(left: 40.0),
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
                  color: theme.hintColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
