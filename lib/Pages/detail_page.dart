import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

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

class _DetailPageState extends State<DetailPage> {
  double _userRating = 0.0;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  List<Map<String, dynamic>> _reviews = [];
  final TextEditingController _reviewController = TextEditingController();
  bool _isReviewSectionExpanded = false;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _getRatingAndReviews();
    _checkIfRegistered();
  }

    _checkIfRegistered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await DatabaseMethods().getUser(user.uid);
    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      if (userData.containsKey('bookedEvents') &&
          (userData['bookedEvents'] as List).contains(widget.id)) {
        setState(() {
          _isRegistered = true;
        });
      }
    }
  }


  _getRatingAndReviews() async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection("News").doc(widget.id).get();
    if (doc.exists && doc.data() != null) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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

        if (ratings.isNotEmpty) {
          setState(() {
            _totalRatings = ratings.length;
            _averageRating = total / _totalRatings;
            _reviews = reviewsList;
          });
        } else {
          setState(() {
            _totalRatings = 0;
            _averageRating = 0.0;
            _reviews = [];
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: widget.image,
                  height: MediaQuery.of(context).size.height / 2,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: MediaQuery.of(context).size.height / 2,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: MediaQuery.of(context).size.height / 2,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                    ),
                    child: Icon(Icons.broken_image,
                        color: Colors.grey.shade400, size: 40),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height / 2,
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin:
                              const EdgeInsets.only(top: 40.0, left: 20.0),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30)),
                          child: const Icon(
                            Icons.arrow_back_ios_new_outlined,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 20.0, bottom: 20.0, right: 20.0),
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(color: Colors.black45),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25.0,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10.0),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: Colors.white,
                                ),
                                SizedBox(
                                  width: 10.0,
                                ),
                                Text(
                                  widget.date,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 19.0,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5.0),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white,
                                ),
                                SizedBox(
                                  width: 10.0,
                                ),
                                Expanded(
                                  child: Text(
                                    widget.location,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 19.0,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
            SizedBox(
              height: 20.0,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: Text(
                "About Event",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 25.0,
                    fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 5.0,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: Text(
                widget.detail,
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(height: 20.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Reviews",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 25.0,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 5.0),
                          Row(
                            children: [
                              RatingBarIndicator(
                                rating: _averageRating,
                                itemBuilder: (context, index) => Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                itemCount: 5,
                                itemSize: 20.0,
                                direction: Axis.horizontal,
                              ),
                              SizedBox(width: 10),
                              Text("($_totalRatings Reviews)", style: TextStyle(fontSize: 16, color: Colors.grey.shade600),)
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                           setState(() {
                            _isReviewSectionExpanded = !_isReviewSectionExpanded;
                          });
                        },
                        child: Row(
                          children: [
                            Text(
                               _isReviewSectionExpanded ? "Hide" : "Write a Review",
                                style: TextStyle(
                                color: Color(0xFF00008B),
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 5.0),
                            Icon(
                                _isReviewSectionExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: Color(0xFF00008B),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  if (_isReviewSectionExpanded)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.0),
                        Text(
                          "Rate this Event",
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10.0),
                        RatingBar.builder(
                          initialRating: _userRating,
                          minRating: 1,
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,
                          itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                          itemBuilder: (context, _) => Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          onRatingUpdate: (rating) {
                            setState(() {
                              _userRating = rating;
                            });
                          },
                        ),
                        SizedBox(height: 20.0),
                        TextField(
                          controller: _reviewController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Write a review...',
                          ),
                        ),
                        SizedBox(height: 20.0),
                        GestureDetector(
                          onTap: () async {
                            if (_userRating == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text("Please select a rating (at least 1 star).")));
                              return;
                            }
                            await DatabaseMethods().addReview(
                                widget.id, _userRating, _reviewController.text);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                backgroundColor: Colors.green,
                                content: Text("Thank you for your feedback!",
                                    style: TextStyle(fontSize: 18.0))));
                            
                            await _getRatingAndReviews();

                            setState(() {
                              _userRating = 0.0;
                              _reviewController.clear();
                              _isReviewSectionExpanded = false;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15.0),
                            decoration: BoxDecoration(
                                color: Color(0xFF00008B),
                                borderRadius: BorderRadius.circular(10.0)),
                            child: Center(
                              child: Text(
                                "Submit Review",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.0),
                        Divider(),
                        SizedBox(height: 10.0),
                        _reviews.isEmpty
                            ? Center(child: Text("No reviews yet."))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  var review = _reviews[index];
                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(review['userName'],
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16.0)),
                                          SizedBox(height: 4.0),
                                          RatingBarIndicator(
                                            rating: review['rating'],
                                            itemBuilder: (context, index) => Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                            ),
                                            itemCount: 5,
                                            itemSize: 16.0,
                                            direction: Axis.horizontal,
                                          ),
                                          SizedBox(height: 8.0),
                                          Text(review['review'])
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                      ],
                    )
                ],
              ),
            ),
            SizedBox(height: 30.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GestureDetector(
                 onTap: _isRegistered
                    ? null // Disable button if already registered
                    : () async {
                        await DatabaseMethods().registerForEvent(widget.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.green,
                            content: Text("Successfully registered for the event!", style: TextStyle(fontSize: 18.0))));
                        setState(() {
                          _isRegistered = true;
                        });
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15.0),
                   decoration: BoxDecoration(
                    color: _isRegistered ? Colors.grey : Color(0xFF00008B),
                    borderRadius: BorderRadius.circular(10.0)),
                  child: Center(
                    child: Text(
                       _isRegistered ? "Already Registered" : "Register Now",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.0)
          ],
        ),
      ),
    );
  }
}
