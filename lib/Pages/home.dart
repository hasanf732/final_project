import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/Pages/favorites_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  StreamSubscription? _positionStreamSubscription;
  StreamSubscription? _userEventsSubscription;

  Stream<List<MapEntry<DocumentSnapshot, double>>>? _nearestEventsStream;
  Stream<List<DocumentSnapshot>>? _discoverEventsStream;
  Stream<List<DocumentSnapshot>>? _hotEventsStream;
  Stream<List<DocumentSnapshot>>? _topRatedEventsStream;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<String> _hintTexts = [
    "Search for Events",
    "Search for Art",
    "Search for Sport",
    "Search for Music"
  ];
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
    _positionStreamSubscription?.cancel();
    _userEventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    _listenToBookmarks();
    _listenToLocationUpdates();
    _listenToUserEvents();
    _initializeStreams();
  }

  void _initializeStreams() {
    _discoverEventsStream = discoverEventsStream();
    _hotEventsStream = hotEventsStream();
    _topRatedEventsStream = topRatedEventsStream();
    _nearestEventsStream = nearestEventsStream();
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

  void _listenToLocationUpdates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // meters
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position? position) {
        if (mounted && position != null) {
          setState(() {
            _currentPosition = position;
          });
        }
      }, onError: (e) {});
    } catch (e) {}
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
      if (data == null || data['Date'] == null) {
        return false;
      }
      final eventDate = (data['Date'] as Timestamp).toDate();
      return !eventDate.isBefore(startOfToday);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSearching = _searchQuery.isNotEmpty;
    final bool isFiltering = _selectedCategory != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor.withAlpha(230),
            title: Text(
              "Hello, ${_userName.isNotEmpty ? _userName : 'User'}!",
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.bookmarks,
                    color: theme.colorScheme.primary, size: 28),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FavoritesPage())),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _hintTexts.first,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCategorySelector(),
              ],
            ),
          ),
          if (isSearching || isFiltering)
            _buildFilteredList()
          else ...[
            _buildSectionHeader("Discover 🚀"),
            _buildHorizontalEventsList(_discoverEventsStream),
            _buildSectionHeader("What's Hot 🔥"),
            _buildHorizontalEventsList(_hotEventsStream),
            _buildSectionHeader("Top Rated ⭐"),
            _buildHorizontalEventsList(_topRatedEventsStream),
            _buildSectionHeader("Nearest To You 📍"),
            _buildVerticalEventsList(_nearestEventsStream),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Stream<List<DocumentSnapshot>> discoverEventsStream() {
    return DatabaseMethods().getEventDetails().map((snapshot) {
      var docs = _filterUpcomingEvents(snapshot.docs);
      docs.sort((a, b) {
        var aDate = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        var bDate = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return docs.take(7).toList();
    });
  }

  Stream<List<DocumentSnapshot>> hotEventsStream() {
    return DatabaseMethods().getEventDetails().map((snapshot) {
      var docs = _filterUpcomingEvents(snapshot.docs).where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data.containsKey('ratings') && (data['ratings'] as Map).isNotEmpty;
      }).toList();

      docs.sort((a, b) {
        var aRatings = (a.data() as Map<String, dynamic>)['ratings']?.length ?? 0;
        var bRatings = (b.data() as Map<String, dynamic>)['ratings']?.length ?? 0;
        return bRatings.compareTo(aRatings);
      });

      return docs.take(7).toList();
    });
  }

  Stream<List<DocumentSnapshot>> topRatedEventsStream() {
    return DatabaseMethods().getEventDetails().map((snapshot) {
      var docsWithRatings = _filterUpcomingEvents(snapshot.docs).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final double avgRating = _calculateAverageRating(data['ratings']);
        return MapEntry(doc, avgRating);
      }).where((entry) => entry.value > 0).toList();

      docsWithRatings.sort((a, b) => b.value.compareTo(a.value));

      return docsWithRatings.map((entry) => entry.key).take(7).toList();
    });
  }

  Stream<List<MapEntry<DocumentSnapshot, double>>> nearestEventsStream() {
  return DatabaseMethods().getEventDetails().map((snapshot) {
    if (_currentPosition == null) return [];

    var docsWithDistances = _filterUpcomingEvents(snapshot.docs).map((doc) {
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

    return docsWithDistances.take(2).toList();
  });
}


  double _calculateAverageRating(Map<String, dynamic>? ratings) {
    if (ratings == null || ratings.isEmpty) return 0.0;
    double total = 0;
    ratings.forEach((key, value) {
      total += (value['rating'] as num? ?? 0);
    });
    return total / ratings.length;
  }

  Widget _buildFilteredList() {
    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseMethods().getEventDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(child: _buildVerticalShimmer());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              heightFactor: 10,
              child: Text("No events found."),
            ),
          );
        }

        List<DocumentSnapshot> events = _filterUpcomingEvents(snapshot.data!.docs);

        // Apply category filtering
        if (_selectedCategory != null) {
          events = events.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['Category'] == _selectedCategory;
          }).toList();
        }

        // Apply search query filtering
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
              final event = events[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
                child: _buildEventCard(event,
                    isBookmarked: _bookmarkedEventIds.contains(event.id)),
              );
            },
            childCount: events.length,
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
            left: 20.0, right: 20.0, top: 24.0, bottom: 16.0),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHorizontalEventsList(Stream<List<DocumentSnapshot>>? stream) {
    if (stream == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: StreamBuilder<List<DocumentSnapshot>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildHorizontalShimmer();
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox(
                height: 100,
                child: Center(child: Text("No events in this category yet.")));
          }

          return SizedBox(
            height: 225,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final event = snapshot.data![index];
                return _buildEventCard(event,
                    isBookmarked: _bookmarkedEventIds.contains(event.id),
                    isFeatured: true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalEventsList(Stream<List<MapEntry<DocumentSnapshot, double>>>? stream) {
  if (stream == null) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
  return StreamBuilder<List<MapEntry<DocumentSnapshot, double>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (_currentPosition == null) {
        return const SliverToBoxAdapter(
            child: Center(
                heightFactor: 5,
                child: Text("Enable location to see nearby events.")));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return SliverToBoxAdapter(child: _buildVerticalShimmer());
      }
      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const SliverToBoxAdapter(
            child: Center(heightFactor: 5, child: Text("No events nearby.")));
      }

      return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
        final eventEntry = snapshot.data![index];
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
      }, childCount: snapshot.data!.length));
    },
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

  final date = data['Date']?.toDate();
  final String formattedDate = date != null ? DateFormat('MMM dd, yyyy').format(date) : "Date N/A";
  final String formattedTime = date != null ? DateFormat('h:mm a').format(date) : "";

  final cardWidth = isFeatured ? 280.0 : null;

  final card = Material(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(16),
    elevation: 2,
    shadowColor: Colors.black.withAlpha(26),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(
              id: event.id,
              image: data['Image'] ?? '',
              name: data['Name'] ?? 'Untitled Event',
              date: formattedDate,
              location: data['Location'] ?? 'No location',
              detail: data['Detail'] ?? '',
              time: formattedTime,
            ),
          ),
        );
      },
      child: SizedBox(
        width: cardWidth,
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
                      Text(formattedDate, style: theme.textTheme.bodySmall),
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
