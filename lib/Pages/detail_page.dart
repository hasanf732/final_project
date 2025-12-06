import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/EditEventPage.dart';
import 'package:final_project/Pages/qr_display_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shimmer/shimmer.dart';

class DetailPage extends StatefulWidget {
  final String image, name, date, location, detail, time, id;
  const DetailPage(
      {super.key,
      required this.image,
      required this.name,
      required this.date,
      required this.location,
      required this.detail,
      required this.time,
      required this.id});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with TickerProviderStateMixin {
  double _userRating = 0.0;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  List<Map<String, dynamic>> _reviews = [];
  final TextEditingController _reviewController = TextEditingController();
  bool _isReviewSectionExpanded = false;
  bool _isRegistered = false;
  bool _isAttended = false;
  bool _isLoadingReviews = true;
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  Timer? _reviewRequestTimer;
  bool _isAdmin = false;
  String? _creatorId;
  bool _showReviews = false;


  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  StreamSubscription? _userEventsSubscription;

  @override
  void initState() {
    super.initState();
    _getRatingAndReviews();
    _listenToUserEvents();
    _checkIfFavorite();
    _checkAdminStatus();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _reviewRequestTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _showReviewDialog();
      }
    });
  }

  @override
  void dispose() {
    _reviewRequestTimer?.cancel();
    _reviewController.dispose();
    _animationController.dispose();
    _userEventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    bool isAdmin = await DatabaseMethods().isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enjoying the App?'),
        content: const Text('Would you like to leave a review on the Play Store?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final InAppReview inAppReview = InAppReview.instance;
              if (await inAppReview.isAvailable()) {
                inAppReview.requestReview();
              }
            },
            child: const Text('Rate It'),
          ),
        ],
      ),
    );
  }

  void _listenToUserEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEventsSubscription = DatabaseMethods().getUserStream(user.uid).listen((userDoc) {
        if (mounted && userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final booked = data.containsKey('bookedEvents') ? List<String>.from(data['bookedEvents']) : [];
          final attended = data.containsKey('attendedEvents') ? List<String>.from(data['attendedEvents']) : [];
          setState(() {
            _isRegistered = booked.contains(widget.id);
            _isAttended = attended.contains(widget.id);
          });
        }
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    bool isFav = await DatabaseMethods().isFavorite(widget.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    if (_isFavorite) {
      await DatabaseMethods().removeFromFavorites(widget.id);
    } else {
      await DatabaseMethods().addToFavorites(widget.id);
      _animationController.forward().then((_) => _animationController.reverse());
    }

    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
        _isTogglingFavorite = false;
      });
    }
  }

  Future<void> _getRatingAndReviews() async {
    if (mounted) setState(() => _isLoadingReviews = true);
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection("News").doc(widget.id).get();
    if (doc.exists && doc.data() != null) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      _creatorId = data['creatorId'];
      if (data.containsKey('ratings')) {
        Map<String, dynamic> ratings = data['ratings'];
        List<Map<String, dynamic>> reviewsList = [];
        double total = 0;

        ratings.forEach((key, value) {
          if (value is Map && value.containsKey('rating')) {
            total += value['rating'];
            reviewsList.add({
              'userName': value['userName'] ?? 'Anonymous',
              'rating': value['rating'].toDouble(),
              'review': value['review'] ?? ''
            });
          }
        });

        if (mounted) {
          setState(() {
            _totalRatings = ratings.isNotEmpty ? ratings.length : 0;
            _averageRating = ratings.isNotEmpty ? total / ratings.length : 0.0;
            _reviews = reviewsList;
          });
        }
      }
    }
    if (mounted) setState(() => _isLoadingReviews = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isAttended)
                    _buildStatusBadge('Attended', theme.colorScheme.secondary)
                  else if (_isRegistered)
                    _buildStatusBadge('Registered', theme.colorScheme.primary),
                  const SizedBox(height: 20.0),

                  _buildInfoRow(theme, Icons.calendar_today_outlined, widget.date),
                  const SizedBox(height: 10.0),
                  _buildInfoRow(theme, Icons.access_time_outlined, widget.time),
                  const SizedBox(height: 10.0),
                  _buildInfoRow(theme, Icons.location_on_outlined, widget.location),

                  const SizedBox(height: 30.0),
                  Text("About Event", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10.0),
                  Text(widget.detail, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 30.0),
                  _buildReviewsSection(theme),
                  const SizedBox(height: 30.0),
                  _buildRegisterButton(theme),
                  const SizedBox(height: 20.0),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool canEdit = _isAdmin && (_creatorId == null || _creatorId == currentUser?.uid);

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height / 2.5,
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: widget.image,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: theme.colorScheme.surface),
              errorWidget: (context, url, error) =>
                  Container(color: theme.colorScheme.surface, child: const Icon(Icons.broken_image, size: 50)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
        title: Text(widget.name, style: TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.7))])),
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
        child: CircleAvatar(
          backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
          child: BackButton(color: theme.colorScheme.onSurface),
        ),
      ),
       actions: [
         if (canEdit)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditEventPage(eventId: widget.id),
                    ),
                  );
                },
              ),
            ),
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final bool? confirmed = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: const Text('Are you sure you want to delete this event?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await DatabaseMethods().deleteEvent(widget.id);
                    if (mounted) {
                       Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
          child: CircleAvatar(
             backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: IconButton(
                icon: Icon(
                  _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  color: _isFavorite ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
                onPressed: _toggleFavorite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
      ],
    );
  }

  Widget _buildReviewsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Reviews", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5.0),
                  _isLoadingReviews
                      ? Shimmer.fromColors(
                          baseColor: theme.colorScheme.surface,
                          highlightColor: theme.colorScheme.surface.withOpacity(0.5),
                          child: Container(height: 20, width: 150, color: Colors.white),
                        )
                      : Row(
                          children: [
                            if (_totalRatings > 0)
                              RatingBarIndicator(
                                rating: _averageRating,
                                itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber),
                                itemCount: 5,
                                itemSize: 20.0,
                                direction: Axis.horizontal,
                              ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _totalRatings > 0 ? '($_totalRatings Reviews)' : 'No reviews yet',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildReviewButtons(theme),
        if (_isReviewSectionExpanded) _buildReviewEditor(theme),
        if (_showReviews)
          _isLoadingReviews ? _buildReviewShimmer(theme) : _buildReviewList(theme),
      ],
    );
  }

  Widget _buildReviewButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_reviews.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showReviews = !_showReviews;
              });
            },
            icon: Icon(_showReviews ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(_showReviews ? "Hide Reviews" : "Show Reviews"),
          ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isReviewSectionExpanded = !_isReviewSectionExpanded;
            });
          },
          icon: Icon(_isReviewSectionExpanded ? Icons.cancel_outlined : Icons.rate_review_outlined),
          label: Text(_isReviewSectionExpanded ? "Cancel" : "Rate Event"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isReviewSectionExpanded ? Colors.grey : theme.colorScheme.primary,
            foregroundColor: _isReviewSectionExpanded ? Colors.white : theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewEditor(ThemeData theme) {
  // Wrap the content in a SingleChildScrollView
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Rate this Event", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10.0),
          RatingBar.builder(
            initialRating: _userRating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: (rating) {
              setState(() {
                _userRating = rating;
              });
            },
          ),
          const SizedBox(height: 20.0),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Write a review...',
              fillColor: theme.colorScheme.surface,
              filled: true,
            ),
          ),
          const SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () async {
              if (_userRating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Please select a rating (at least 1 star).")));
                return;
              }
              await DatabaseMethods().addReview(widget.id, _userRating, _reviewController.text);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text("Thank you for your feedback!")));

              await _getRatingAndReviews();

              setState(() {
                _userRating = 0.0;
                _reviewController.clear();
                _isReviewSectionExpanded = false;
              });
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text("Submit Review"),
          ),
          // This padding ensures there's space below the button when the keyboard is up
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    ),
  );
}

  Widget _buildReviewList(ThemeData theme) {
    if (_reviews.isEmpty) {
      return const Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text("Be the first to review!")));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        var review = _reviews[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review['userName'], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4.0),
                RatingBarIndicator(
                  rating: review['rating'],
                  itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber),
                  itemCount: 5,
                  itemSize: 16.0,
                  direction: Axis.horizontal,
                ),
                const SizedBox(height: 8.0),
                Text(review['review'], style: theme.textTheme.bodyMedium)
              ],
            ),
          ),
        );
      },
    );
  }

    Widget _buildReviewShimmer(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
           baseColor: theme.colorScheme.surface,
           highlightColor: theme.colorScheme.surface.withOpacity(0.5),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 100, color: Colors.white),
                  const SizedBox(height: 8.0),
                   Container(height: 14, width: 80, color: Colors.white),
                  const SizedBox(height: 12.0),
                  Container(height: 14, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 4.0),
                  Container(height: 14, width: 200, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterButton(ThemeData theme) {
    if (_isAttended) {
      return ElevatedButton(
        onPressed: null, // Attended events have no action
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: Colors.grey.shade600,
        ),
        child: const Text("Attended"),
      );
    }
    
    if (_isRegistered) {
      return ElevatedButton(
        onPressed: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            String qrData = "${user.uid}_${widget.id}";
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QrDisplayPage(
                  qrData: qrData,
                  eventName: widget.name,
                  eventDate: widget.date,
                  eventLocation: widget.location,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: theme.colorScheme.secondary, // A different color to show it's a different state
          foregroundColor: theme.colorScheme.onSecondary,
        ),
        child: const Text("Show QR Code"),
      );
    }

    return ElevatedButton(
      onPressed: () async {
        await DatabaseMethods().registerForEvent(widget.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Successfully registered for the event!")));
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      child: const Text("Register Now"),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
