import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart' as cluster_manager;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';


class Place with cluster_manager.ClusterItem {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final DocumentSnapshot? document;
  @override
  final LatLng latLng;

  Place({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.latLng,
    required this.rating,
    this.document,
  });

  @override
  LatLng get location => latLng;
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late cluster_manager.ClusterManager _manager;
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Position? _currentPosition;
  final Map<String, BitmapDescriptor> _markerBitmaps = {};
  List<Place> _selectedClusterPlaces = [];

  @override
  void initState() {
    super.initState();
    _manager = _initClusterManager();
    _fetchEventLocations();
    _getCurrentLocation();
  }

  cluster_manager.ClusterManager _initClusterManager() {
    return cluster_manager.ClusterManager<Place>(
      [],
      _updateMarkers,
      markerBuilder: _markerBuilder,
    );
  }

  void _updateMarkers(Set<Marker> markers) {
    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<void> _fetchEventLocations() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('News').get();
    final List<Place> newItems = [];
    for (var result in querySnapshot.docs) {
      final data = result.data();
      final lat = data['latitude'];
      final lon = data['longitude'];
      final String name = data['Name'] ?? 'No Name';
      final String imageUrl = data['Image'] ?? '';

      if (lat != null && lon != null) {
        newItems.add(Place(
          id: result.id,
          name: name,
          imageUrl: imageUrl,
          latLng: LatLng(lat, lon),
          rating: 0.0,
          document: result,
        ));
      }
    }

    _manager.setItems(newItems);
    _createMarkerBitmaps(newItems);
  }

  Future<void> _createMarkerBitmaps(List<Place> places) async {
    for (final place in places) {
      try {
        if (place.imageUrl.isNotEmpty) {
          final bitmap = await _createCustomMarkerBitmap(place.imageUrl, context);
          _markerBitmaps[place.id] = bitmap;
        }
      } catch (e) {
        print("Error creating custom marker for ${place.name}: $e");
      }
    }
    _manager.updateMap();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _animateToUser();
      }
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Event Map', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle);
              _manager.setMapId(controller.mapId);
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(26.2285, 50.5860),
              zoom: 12.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            mapToolbarEnabled: false,
            onCameraMove: _manager.onCameraMove,
            onCameraIdle: _manager.updateMap,
            onTap: (_) => setState(() => _selectedClusterPlaces.clear()),
          ),
          if (_selectedClusterPlaces.isNotEmpty) _buildEventCarousel(bottomPadding),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0), // Adjust this value to lift the button
        child: FloatingActionButton(
          onPressed: _animateToUser,
          tooltip: 'My Location',
          child: const Icon(Icons.my_location),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _animateToUser() async {
    if (_currentPosition != null) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 14.0,
        ),
      ));
    }
  }

  Future<Marker> _markerBuilder(cluster_manager.Cluster<Place> cluster) async {
    if (cluster.isMultiple) {
      return _buildClusterMarker(cluster);
    } else {
      final place = cluster.items.first;
      return Marker(
        markerId: MarkerId(place.id),
        position: place.location,
        icon: _markerBitmaps[place.id] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: 'Click for details',
          onTap: () => _navigateToDetail(place),
        ),
      );
    }
  }

  Future<Marker> _buildClusterMarker(cluster_manager.Cluster<Place> cluster) async {
    return Marker(
      markerId: MarkerId(cluster.location.toString()),
      position: cluster.location,
      onTap: () {
        _controller.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(cluster.location, 17.5)));
        if (mounted) {
          setState(() {
            _selectedClusterPlaces = cluster.items.toList();
          });
        }
      },
      icon: await _getClusterMarker(cluster.count, context),
    );
  }

  void _navigateToDetail(Place place) {
    final eventDoc = place.document;
    if (eventDoc != null) {
      final data = eventDoc.data() as Map<String, dynamic>;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailPage(
            image: data['Image'] ?? '',
            name: data['Name'] ?? 'No Name',
            date: data['Date'] != null ? (data['Date'] as Timestamp).toDate().toString() : 'No Date',
            location: data['Location'] ?? 'No Location',
            detail: data['Detail'] ?? 'No Details',
            time: data['Time'] ?? 'No Time',
            id: eventDoc.id,
          ),
        ),
      );
    }
  }

  static Future<BitmapDescriptor> _createCustomMarkerBitmap(String imageUrl, BuildContext context) async {
    const double size = 150;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Paint paint = Paint()..color = isDarkMode ? Colors.grey.shade300 : Theme.of(context).colorScheme.primary;
    final Paint borderPaint = Paint()
      ..color = isDarkMode ? Colors.black : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const double pinWidth = size * 0.8;
    const double pinHeight = size;

    final Path path = Path()
      ..moveTo(pinWidth / 2, pinHeight)
      ..cubicTo(pinWidth / 2, pinHeight * 0.8, 0, pinHeight * 0.6, 0, pinHeight * 0.4)
      ..arcTo(Rect.fromCircle(center: Offset(pinWidth / 2, pinHeight * 0.4), radius: pinWidth / 2), math.pi, math.pi, false)
      ..cubicTo(pinWidth, pinHeight * 0.6, pinWidth / 2, pinHeight * 0.8, pinWidth / 2, pinHeight)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    final Completer<ui.Image> imageCompleter = Completer();
    NetworkImage(imageUrl).resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) => imageCompleter.complete(info.image)));
    final ui.Image image = await imageCompleter.future;

    final Rect imageRect = Rect.fromCircle(center: Offset(pinWidth / 2, pinHeight * 0.4), radius: (pinWidth / 2) * 0.85);
    canvas.clipPath(Path()..addOval(imageRect));
    paintImage(canvas: canvas, rect: imageRect, image: image, fit: BoxFit.cover);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _getClusterMarker(int count, BuildContext context) async {
    const int size = 130;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Theme.of(context).colorScheme.secondary;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: count.toString(),
      style: TextStyle(fontSize: size / 3, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondary),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2));

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Widget _buildEventCarousel(double bottomPadding) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedClusterPlaces.length,
            itemBuilder: (context, index) {
              final place = _selectedClusterPlaces[index];
              return GestureDetector(
                onTap: () => _navigateToDetail(place),
                child: Container(
                  width: 280,
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: CachedNetworkImage(
                            imageUrl: place.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              place.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
