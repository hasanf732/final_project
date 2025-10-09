import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? _selectedCategory;
  bool _showAllEvents = false;
  final PageController _pageController = PageController(viewportFraction: 1.0);
  Timer? _carouselTimer;
  int _currentPage = 0;
  String _userName = "";

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<String> _hintTexts = [
    "Search for Events",
    "Search for Art",
    "Search for Sport",
    "Search for Music",
    "Search for Film",
    "Search for Cyber",
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
    _loadUserData();
    _searchController.addListener(() {
      if (mounted && _searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await DatabaseMethods().getUser(user.uid);
        if (userDoc.exists && userDoc.data() != null && mounted) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String fullName = userData['Name'] ?? '';
          setState(() {
            _userName = fullName.split(' ').first;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _userName = "User";
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startTimer(int pageCount) {
    _carouselTimer?.cancel();
    if (_selectedCategory == null && !_showAllEvents && pageCount > 0) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_currentPage < pageCount - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 400), curve: Curves.easeIn);
        }
      });
    }
  }

  Widget allEvents() {
    Stream<QuerySnapshot> eventStream = (_selectedCategory != null)
        ? FirebaseFirestore.instance.collection("News").where("Category", isEqualTo: _selectedCategory).snapshots()
        : DatabaseMethods().getEventDetails();

    return StreamBuilder<QuerySnapshot>(
      stream: eventStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _searchQuery.isEmpty) {
          return const SizedBox(height: 285, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No events found."));
        }

        List<DocumentSnapshot> eventDocs = snapshot.data!.docs;

        if (_searchQuery.isNotEmpty) {
          eventDocs = eventDocs.where((doc) {
            final eventName = (doc.data() as Map<String, dynamic>)['Name']?.toString().toLowerCase() ?? '';
            return eventName.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        bool isFeaturedMode = _selectedCategory == null && !_showAllEvents && _searchQuery.isEmpty;

        if (isFeaturedMode) {
          List<DocumentSnapshot> featuredDocs = List.from(eventDocs);
          featuredDocs.sort((a, b) {
            int aRatings = (a.data() as Map<String, dynamic>).containsKey('ratings') ? (a['ratings'] as Map).length : 0;
            int bRatings = (b.data() as Map<String, dynamic>).containsKey('ratings') ? (b['ratings'] as Map).length : 0;
            return bRatings.compareTo(aRatings);
          });
          featuredDocs = featuredDocs.take(4).toList();
          if (featuredDocs.isNotEmpty) _startTimer(featuredDocs.length);
          
          return SizedBox(
            height: 285,
            child: PageView.builder(
              controller: _pageController,
              itemCount: featuredDocs.length,
              onPageChanged: (page) => _currentPage = page,
              itemBuilder: (context, index) => _buildEventCard(featuredDocs[index], isFeatured: true),
            ),
          );
        } else {
          _carouselTimer?.cancel();
          if (eventDocs.isEmpty) return const Center(child: Text("No events match your search."));
          return ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: eventDocs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: _buildEventCard(eventDocs[index], isFeatured: false),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildEventCard(DocumentSnapshot ds, {required bool isFeatured}) {
    var data = ds.data() as Map<String, dynamic>;
    final imageUrl = data['Image'] as String?;
    final eventName = data['Name'] as String? ?? 'Untitled Event';
    final eventLocation = data['Location'] as String?;
    final eventDetail = data['Detail'] as String?;
    final eventTime = data['Time'] as String?;
    DateTime? eventDate;
    final dateData = data['Date'];
    String eventDateStr = '';
    if (dateData is Timestamp) {
      eventDate = dateData.toDate();
      eventDateStr = DateFormat('yyyy-MM-dd').format(eventDate);
    }

    return GestureDetector(
      onTap: () {
        _carouselTimer?.cancel();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(
              id: ds.id,
              image: imageUrl ?? '',
              name: eventName,
              date: eventDateStr,
              location: eventLocation ?? 'No location specified',
              detail: eventDetail ?? 'No details available',
              time: eventTime ?? 'No time specified',
            ),
          ),
        ).then((_) => _startTimer(4));
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isFeatured ? 10.0 : 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15.0),
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 180,
                          width: MediaQuery.of(context).size.width,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15.0)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 180,
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15.0)),
                            child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 40),
                          ),
                        )
                      : Container(
                          height: 180,
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15.0)),
                          child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 40),
                        ),
                ),
                if (eventDate != null)
                  Container(
                    margin: const EdgeInsets.only(left: 15.0, top: 9.0),
                    padding: const EdgeInsets.all(5.0),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
                    child: Text(DateFormat("MMM\ndd").format(eventDate), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14.0, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 10.0),
            Text(eventName, style: const TextStyle(color: Colors.black, fontSize: 20.0, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5.0),
            if (eventLocation != null && eventLocation.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 5.0),
                  Expanded(
                    child: Text(eventLocation, style: TextStyle(color: Colors.grey.shade600, fontSize: 16.0), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xffe3e6ff), Color(0xfff1f3ff), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 50.0, left: 20.0, right: 20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.location_on_outlined, color: Colors.black), SizedBox(width: 5.0), Text("Polytechnic, Bahrain", style: TextStyle(color: Colors.black, fontSize: 20.0, fontWeight: FontWeight.w500))]),
                  const SizedBox(height: 20.0),
                  Text("Hello, ${_userName.isNotEmpty ? _userName : 'User'}!", style: const TextStyle(color: Colors.black, fontSize: 25.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10.0),
                   StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('News').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final eventCount = snapshot.data!.docs.length;
                        final eventText = eventCount == 1 ? "event" : "events";
                        final verb = eventCount == 1 ? "is" : "are";
                        return Text(
                          "There $verb $eventCount $eventText in\npolytechnic campus.",
                          style: const TextStyle(
                            color: Color(0xFF00008B),
                            fontSize: 25.0,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      } else {
                        return const Text(
                          "Loading events...",
                          style: TextStyle(
                            color: Color(0xFF00008B),
                            fontSize: 25.0,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20.0),
                  AnimatedSearchBar(searchController: _searchController, hintTexts: _hintTexts),
                  const SizedBox(height: 20.0),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        var category = _categories[index];
                        bool isSelected = category['name'] == _selectedCategory;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentPage = 0;
                              _showAllEvents = false;
                              _searchController.clear();
                              if (isSelected) {
                                _selectedCategory = null;
                              } else {
                                _selectedCategory = category['name'];
                              }
                            });
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 15.0),
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00008B) : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8.0, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(category['image']!, height: 60, width: 60, fit: BoxFit.cover, color: isSelected ? Colors.white : null, colorBlendMode: isSelected ? BlendMode.srcIn : null),
                                const SizedBox(height: 10),
                                Text(category['name']!, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 14.0, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Search Results'
                            : _selectedCategory == null
                                ? (_showAllEvents ? "All Events" : "Featured Events")
                                : "Events in $_selectedCategory",
                        style: const TextStyle(color: Colors.black, fontSize: 22.0, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedCategory == null && _searchQuery.isEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAllEvents = !_showAllEvents;
                            });
                          },
                          child: Text(_showAllEvents ? "Show Featured" : "See all", style: const TextStyle(color: Color(0xFF00008B))),
                        )
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  allEvents(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedSearchBar extends StatefulWidget {
  final TextEditingController searchController;
  final List<String> hintTexts;

  const AnimatedSearchBar({
    Key? key,
    required this.searchController,
    required this.hintTexts,
  }) : super(key: key);

  @override
  _AnimatedSearchBarState createState() => _AnimatedSearchBarState();
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
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });
    _startTypingAnimation();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {}); // Update suffix icon
      if (widget.searchController.text.isNotEmpty) {
        _typingTimer?.cancel();
      } else if (widget.searchController.text.isEmpty && !(_typingTimer?.isActive ?? false)) {
        _startTypingAnimation();
      }
    }
  }

  void _startTypingAnimation() {
    _typingTimer?.cancel();
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
    final bool hasText = widget.searchController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
      child: TextField(
        controller: widget.searchController,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
          hintText: hasText ? null : _currentHintText + (_showCursor ? '|' : ''),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                  onPressed: () {
                    widget.searchController.clear();
                  },
                )
              : const Icon(Icons.search_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}
