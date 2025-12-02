import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:final_project/Pages/favorites_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? _selectedCategory;
  String _userName = "";
  Position? _currentPosition;
  Set<String> _bookmarkedEventIds = {};
  Set<String> _bookedEventIds = {};
  Set<String> _attendedEventIds = {};

  StreamSubscription? _bookmarksSubscription;
  StreamSubscription? _positionStreamSubscription;
  StreamSubscription? _userEventsSubscription;

  Stream<List<DocumentSnapshot>>? _hotEventsStream;
  Stream<List<DocumentSnapshot>>? _topRatedEventsStream;
  Stream<List<DocumentSnapshot>>? _nearestEventsStream;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<String> _hintTexts = ["Search for Events", "Search for Art", "Search for Sport", "Search for Music"];
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
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = (userData['Name'] ?? '').split(' ').first;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _userName = "User");
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
        if (mounted && userDoc.exists && userDoc.data()!.containsKey('favoriteEvents')) {
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
      _userEventsSubscription = DatabaseMethods().getUserStream(user.uid).listen((userDoc) {
        if (mounted && userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final booked = data.containsKey('bookedEvents') ? List<dynamic>.from(data['bookedEvents']) : [];
          final attended = data.containsKey('attendedEvents') ? List<dynamic>.from(data['attendedEvents']) : [];
          setState(() {
            _bookedEventIds = booked.map((e) => e.toString()).toSet();
            _attendedEventIds = attended.map((e) => e.toString()).toSet();
          });
        }
      });
    }
  }

  void _listenToLocationUpdates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position? position) {
          if (mounted && position != null) {
            setState(() {
              _currentPosition = position;
            });
          }
        },
        onError: (e) {
          // Don't invoke 'print' in production code.
        }
      );
    } catch (e) {
      // Don't invoke 'print' in production code.
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
            title: Text("Hello, ${_userName.isNotEmpty ? _userName : 'User'}!"),
            actions: [
              IconButton(
                icon: Icon(Icons.bookmarks, color: theme.colorScheme.primary, size: 28),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesPage())),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                 Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: AnimatedSearchBar(searchController: _searchController, hintTexts: _hintTexts),
                ),
                const SizedBox(height: 12),
                _buildCategorySelector(),
              ],
            ),
          ),
          if (isSearching || isFiltering)
            _buildFilteredList()
          else ...[
            _buildSectionHeader("What's Hot 🔥"),
            _buildHorizontalEventsList(_hotEventsStream),
            _buildSectionHeader("Top Rated ⭐"),
            _buildHorizontalEventsList(_topRatedEventsStream),
            _buildSectionHeader("Nearest To You 📍"),
            _buildVerticalEventsList(_nearestEventsStream),
          ],
        ],
      ),
    );
  }

  Stream<List<DocumentSnapshot>> hotEventsStream() {
    return FirebaseFirestore.instance
        .collection('News')
        .snapshots()
        .map((snapshot) {
      var docs = snapshot.docs.where((doc) {
        final data = doc.data();
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
    return FirebaseFirestore.instance.collection('News').snapshots().map((snapshot) {
      var docsWithRatings = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final double avgRating = _calculateAverageRating(data['ratings']);
            return MapEntry(doc, avgRating);
          })
          .where((entry) => entry.value > 0)
          .toList();

      docsWithRatings.sort((a, b) => b.value.compareTo(a.value));

      return docsWithRatings.map((entry) => entry.key).take(7).toList();
    });
  }

  Stream<List<DocumentSnapshot>> nearestEventsStream() {
    return FirebaseFirestore.instance.collection('News').snapshots().map((snapshot) {
      if (_currentPosition == null) return [];

      var docsWithDistances = snapshot.docs.map((doc) {
        final data = doc.data();
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

      return docsWithDistances.map((entry) => entry.key).take(2).toList();
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

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 16.0),
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHorizontalEventsList(Stream<List<DocumentSnapshot>>? stream) {
    if (stream == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: StreamBuilder<List<DocumentSnapshot>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildHorizontalShimmer();
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox(height: 100, child: Center(child: Text("No events in this category yet.")));
          
          return SizedBox(
            height: 225,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final event = snapshot.data![index];
                return _buildEventCard(event, isBookmarked: _bookmarkedEventIds.contains(event.id), isFeatured: true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalEventsList(Stream<List<DocumentSnapshot>>? stream) {
    if (stream == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: stream,
      builder: (context, snapshot) {
        if (_currentPosition == null) return const SliverToBoxAdapter(child: Center(heightFactor: 5, child: Text("Enable location to see nearby events.")));
        if (snapshot.connectionState == ConnectionState.waiting) return SliverToBoxAdapter(child: _buildVerticalShimmer());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SliverToBoxAdapter(child: Center(heightFactor: 5, child: Text("No events nearby.")));

        return SliverList(delegate: SliverChildBuilderDelegate((context, index) {
          final event = snapshot.data![index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildEventCard(event, isBookmarked: _bookmarkedEventIds.contains(event.id), isFeatured: false),
          );
        }, childCount: snapshot.data!.length));
      },
    );
  }

   Widget _buildFilteredList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('News').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return SliverToBoxAdapter(child: _buildVerticalShimmer());
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(heightFactor: 5, child: Text("Loading events...")));

        var eventDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (_searchQuery.isNotEmpty) {
            return (data['Name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
          }
          if (_selectedCategory != null) {
            return (data['Category'] as String? ?? '') == _selectedCategory;
          }
          return false; 
        }).toList();

        if (eventDocs.isEmpty) return const SliverToBoxAdapter(child: Center(heightFactor: 5, child: Text("No events found for your query.")));

        return SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final event = eventDocs[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildEventCard(event, isBookmarked: _bookmarkedEventIds.contains(event.id), isFeatured: false),
            );
        }, childCount: eventDocs.length));
      },
    );
  }
  
  Widget _buildCategorySelector() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          var category = _categories[index];
          bool isSelected = category['name'] == _selectedCategory;
          return GestureDetector(
            onTap: () {
              setState(() {
                _searchController.clear();
                _selectedCategory = isSelected ? null : category['name'];
              });
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 12.0),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                border: isSelected ? null : Border.all(color: theme.dividerColor, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(category['image']!, height: 40, width: 40, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary, colorBlendMode: BlendMode.srcIn),
                  const SizedBox(height: 4),
                   Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        category['name']!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot ds, {required bool isBookmarked, required bool isFeatured}) {
    var data = ds.data() as Map<String, dynamic>;
    final theme = Theme.of(context);
    final int imageCacheSize = (MediaQuery.of(context).size.width * 0.4).round();

    final bool isAttended = _attendedEventIds.contains(ds.id);
    final bool isRegistered = _bookedEventIds.contains(ds.id);

    if (isFeatured) {
      return Container(
        width: MediaQuery.of(context).size.width * 0.65,
        margin: const EdgeInsets.only(right: 16.0),
        child: GestureDetector(
          onTap: () => _navigateToDetail(ds.id, data),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.topLeft,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15.0),
                    child: CachedNetworkImage(
                      imageUrl: data['Image'] ?? '',
                      memCacheHeight: imageCacheSize,
                      memCacheWidth: imageCacheSize,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildShimmerImage(true),
                      errorWidget: (context, url, error) => _buildErrorImage(130),
                    ),
                  ),
                  if (isAttended)
                    _buildStatusBadge('Attended', theme.colorScheme.secondary)
                  else if (isRegistered)
                    _buildStatusBadge('Registered', theme.colorScheme.primary),

                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildBookmarkButton(isBookmarked, () => _toggleBookmark(ds.id)),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text(data['Name'] ?? 'Event Name', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Text(data['Location'] ?? 'No location', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }
    
    // List view card
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => _navigateToDetail(ds.id, data),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              CachedNetworkImage(
                imageUrl: data['Image'] ?? '',
                memCacheHeight: imageCacheSize,
                memCacheWidth: imageCacheSize,
                height: 110,
                width: 110,
                fit: BoxFit.cover,
                 placeholder: (context, url) => _buildShimmerImage(false, width: 110, height: 110),
                 errorWidget: (context, url, error) => _buildErrorImage(110, width: 110),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['Name'] ?? 'Event Name', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(data['Location'] ?? 'No location', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      if (isAttended)
                        _buildStatusBadge('Attended', theme.colorScheme.secondary)
                      else if (isRegistered)
                        _buildStatusBadge('Registered', theme.colorScheme.primary),
                      if (_currentPosition != null && data['latitude'] is num && data['longitude'] is num) ...[
                        Row(
                          children: [
                             Icon(Icons.location_on_outlined, size: 14, color: theme.hintColor),
                             const SizedBox(width: 4),
                             Text('${(Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, (data['latitude'] as num).toDouble(), (data['longitude'] as num).toDouble())/1000).toStringAsFixed(1)} km away', style: TextStyle(color: theme.hintColor, fontSize: 12)),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
              ),
               IconButton(
                padding: const EdgeInsets.only(right: 8.0),
                icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: theme.colorScheme.primary, size: 28),
                onPressed: () => _toggleBookmark(ds.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBookmarkButton(bool isBookmarked, VoidCallback onPressed) {
     return Card(
      elevation: 2,
      color: Theme.of(context).cardColor.withAlpha(153),
      margin: const EdgeInsets.all(6),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 20,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(4),
        splashRadius: 20,
        icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Theme.of(context).colorScheme.primary),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(204),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }


  void _navigateToDetail(String id, Map<String, dynamic> data) {
     Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(
        id: id,
        image: data['Image'] ?? '',
        name: data['Name'] ?? 'Untitled Event',
        date: data['Date'] != null ? DateFormat('yyyy-MM-dd').format((data['Date'] as Timestamp).toDate()) : '',
        location: data['Location'] ?? 'No location specified',
        detail: data['Detail'] ?? 'No details available',
        time: data['Time'] ?? 'No time specified',
      )));
  }

  Widget _buildHorizontalShimmer() {
    return SizedBox(
      height: 225,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: 3,
        itemBuilder: (context, index) => _buildShimmerImage(true),
      ),
    );
  }

  Widget _buildVerticalShimmer() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemBuilder: (context, index) => _buildShimmerImage(false),
    );
  }

  Widget _buildShimmerImage(bool isCard, {double width = 0, double height = 130}) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = theme.brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[100]!;
    final itemWidth = width > 0 ? width : MediaQuery.of(context).size.width * 0.65;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: isCard
          ? Container(
              width: itemWidth,
              margin: const EdgeInsets.only(right: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: height, width: double.infinity, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(15.0))),
                  const SizedBox(height: 10),
                  Container(height: 18, width: itemWidth * 0.8, color: baseColor),
                  const SizedBox(height: 5),
                  Container(height: 14, width: itemWidth * 0.6, color: baseColor),
                ],
              ),
            )
          : Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: Card(
                 child: Row(
                  children: [
                    Container(height: 110, width: 110, color: baseColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 16, width: double.infinity, color: baseColor),
                          const SizedBox(height: 8),
                           Container(height: 14, width: double.infinity, color: baseColor),
                          const SizedBox(height: 8),
                          Container(height: 12, width: 100, color: baseColor),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorImage(double height, {double width = double.infinity}) {
    final theme = Theme.of(context);
    return Container(
      height: height, 
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15.0),
      ), 
      child: Icon(Icons.broken_image, color: theme.colorScheme.onSurfaceVariant, size: 40)
    );
  }
}

class AnimatedSearchBar extends StatefulWidget {
   final TextEditingController searchController;
  final List<String> hintTexts;

  const AnimatedSearchBar({super.key, required this.searchController, required this.hintTexts});

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  Timer? _typingTimer;
  int _hintTextIndex = 0;
  String _currentHintText = "";
  bool _isDeleting = false;
  final _typingSpeed = const Duration(milliseconds: 150);
  final _deleteSpeed = const Duration(milliseconds: 100);
  final _delayBetweenHints = const Duration(seconds: 2);
  bool _showCursor = true;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });
    _startTypingAnimation();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
      if (widget.searchController.text.isNotEmpty) {
        _typingTimer?.cancel();
      } else if (!(_typingTimer?.isActive ?? false)) {
        _startTypingAnimation();
      }
    }
  }

  void _startTypingAnimation() {
    _typingTimer = Timer.periodic(_isDeleting ? _deleteSpeed : _typingSpeed, (timer) {
      if (!mounted || widget.searchController.text.isNotEmpty) {
        timer.cancel();
        return;
      }
      setState(() {
        String targetHint = widget.hintTexts[_hintTextIndex];
        if (_isDeleting) {
          if (_currentHintText.isNotEmpty) {
            _currentHintText = _currentHintText.substring(0, _currentHintText.length - 1);
          } else {
            _isDeleting = false;
            _hintTextIndex = (_hintTextIndex + 1) % widget.hintTexts.length;
            timer.cancel();
            _startTypingAnimation();
          }
        } else {
          if (_currentHintText.length < targetHint.length) {
            _currentHintText = targetHint.substring(0, _currentHintText.length + 1);
          } else {
            timer.cancel();
            Future.delayed(_delayBetweenHints, () {
              if (mounted) {
                _isDeleting = true;
                _startTypingAnimation();
              }
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasText = widget.searchController.text.isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(13), border: Border.all(color: theme.dividerColor, width: 1)),
      child: TextField(
        controller: widget.searchController,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
          hintText: hasText ? '' : _currentHintText + (_showCursor && !_isDeleting ? '|' : ''),
          suffixIcon: hasText
              ? IconButton(icon: Icon(Icons.close, color: theme.hintColor), onPressed: () => widget.searchController.clear())
              : Icon(Icons.search_outlined, color: theme.hintColor),
        ),
      ),
    );
  }
}
