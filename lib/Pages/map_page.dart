import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:final_project/Pages/detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart' as cluster_manager;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class Place with cluster_manager.ClusterItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final double rating;
  final DocumentSnapshot? document;
  @override
  final LatLng latLng;

  Place({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.latLng,
    required this.category,
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

  // State for tracking selections and UI
  Place? _selectedPlace;
  bool _isSheetOpen = false;

  // State for search and filtering
  List<Place> _allPlaces = [];
  List<Place> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFilter;
  final List<String> _filters = ['All', 'Music', 'Art', 'Sport', 'Film', 'Volunteer', 'Cyber', 'Astro', 'Media'];
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _manager = _initClusterManager();
    _fetchEventLocations();
    _getCurrentLocation();

    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
        _filterAndRefreshMap();
      }
    });

    _searchFocusNode.addListener(() {
      setState(() {}); // Re-render to show/hide search results dropdown
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _fetchEventLocations();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
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
      setState(() => _markers = markers);
    }
  }

  Future<void> _fetchEventLocations() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('News').get();
    final List<Place> newItems = [];

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var result in querySnapshot.docs) {
      final data = result.data();
      final eventDate = (data['Date'] as Timestamp?)?.toDate();

      if (eventDate != null && !eventDate.isBefore(startOfToday)) {
        final lat = data['latitude'];
        final lon = data['longitude'];

        if (lat != null && lon != null) {
          newItems.add(Place(
            id: result.id,
            name: data['Name'] ?? 'No Name',
            imageUrl: data['Image'] ?? '',
            latLng: LatLng(lat, lon),
            category: data['Category'] ?? 'Unknown',
            rating: 0.0, // Placeholder for rating
            document: result,
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _allPlaces = newItems;
      });
    }

    _manager.setItems(newItems);
    _createMarkerBitmaps(newItems);
  }

  void _filterAndRefreshMap() {
    List<Place> placesToShowOnMap = _allPlaces;
    List<Place> searchDropdownResults = [];

    if (_searchQuery.isNotEmpty) {
      searchDropdownResults = _allPlaces.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      placesToShowOnMap = searchDropdownResults;
    } else {
      searchDropdownResults = [];
    }

    if (mounted) {
      setState(() {
        _searchResults = searchDropdownResults;
      });
    }

    if (_selectedFilter != null && _selectedFilter != 'All') {
      placesToShowOnMap = placesToShowOnMap.where((p) => p.category == _selectedFilter).toList();
    }

    _manager.setItems(placesToShowOnMap);
  }

  Future<void> _createMarkerBitmaps(List<Place> places) async {
    for (final place in places) {
      if (place.imageUrl.isNotEmpty) {
        try {
          final bitmap = await _createCustomMarkerBitmap(place.imageUrl, context);
          _markerBitmaps[place.id] = bitmap;
        } catch (e) {
          // Handle error creating custom marker
        }
      }
    }
    _manager.updateMap();
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        if (mounted) {
          setState(() => _currentPosition = position);
          _animateToUser();
        }
      } catch (e) {
        // Handle error getting current location or timeout
      }
    } else {
      // Handle permission denied
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool showSearchResults = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0, // We are building our own app bar content
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _loadMapStyles(isDarkMode),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mapStyle = snapshot.data!['style'];

          return Stack(
            children: [
              GoogleMap(
                style: mapStyle,
                mapType: MapType.normal,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                  _manager.setMapId(controller.mapId);
                },
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const LatLng(26.2285, 50.5860),
                  zoom: 12.0,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onCameraMove: _manager.onCameraMove,
                onCameraIdle: _manager.updateMap,
                onTap: (_) {
                  if (mounted) {
                    setState(() {
                      _selectedPlace = null;
                      _searchFocusNode.unfocus();
                    });
                  }
                },
              ),
              _buildSearchAndFilterUI(),
              // Padding for the bottom navigation bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  color: Colors.transparent,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Visibility(
        visible: !_isSheetOpen && !showSearchResults,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              onPressed: _animateToUser,
              tooltip: 'My Location',
              heroTag: 'location_fab',
              child: const Icon(Icons.my_location),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: _fetchEventLocations, // Re-fetches data and markers
              tooltip: 'Refresh Events',
              heroTag: 'refresh_fab',
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<Map<String, String>> _loadMapStyles(bool isDarkMode) async {
    String style = await rootBundle.loadString(isDarkMode ? 'Images/map_style_dark.json' : 'Images/map_style.json');
    return {'style': style};
  }

  Widget _buildSearchAndFilterUI() {
    final theme = Theme.of(context);
    final bool showSearchResults = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: Icon(Icons.search, color: theme.hintColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close), onPressed: () => _searchController.clear())
                    : null,
              ),
            ),
          ),
          if (showSearchResults)
            Container(
              height: 220,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    title: Text(place.name),
                    subtitle: Text(place.category),
                    onTap: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();

                      if (_isSheetOpen) {
                        Navigator.of(context).pop();
                      }

                      Future.delayed(const Duration(milliseconds: 100), () {
                        _animateToLocation(place.latLng);
                        _onMarkerTapped(place);
                      });
                    },
                  );
                },
              ),
            ),
          if (!showSearchResults) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = selected ? filter : null);
                        _filterAndRefreshMap();
                      },
                      backgroundColor: theme.cardColor,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.dividerColor)),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _animateToUser() async {
    if (_currentPosition != null) {
      _animateToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }
  }

  void _animateToLocation(LatLng location) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: location,
        zoom: 17.5,
      ),
    ));
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
        onTap: () => _onMarkerTapped(place),
      );
    }
  }

  void _onMarkerTapped(Place place) {
    setState(() {
      _selectedPlace = place;
      _isSheetOpen = true;
    });

    showModalBottomSheet(
      context: context,
      builder: (context) => _buildEventPreviewSheet(place),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).whenComplete(() {
      setState(() {
        _selectedPlace = null;
        _isSheetOpen = false;
      });
    });
  }

  Widget _buildEventPreviewSheet(Place place) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (_, controller) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  children: [
                    if (place.imageUrl.isNotEmpty)
                      SizedBox(
                        height: screenHeight * 0.25,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: place.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Image.asset(
                            'Images/Eventposter1.png', // Placeholder from assets
                            fit: BoxFit.cover,
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'Images/Eventposter1.png', // Placeholder from assets
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.category_outlined, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                place.category,
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (place.document != null) ...[
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (place.document!.data() as Map<String, dynamic>)['Location'] ?? 'No Location',
                                    style: theme.textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              (place.document!.data() as Map<String, dynamic>)['Detail'] ?? 'No Details',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context); // Dismiss the sheet
                                _navigateToDetail(place);
                              },
                              child: const Text('View Full Details', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Marker> _buildClusterMarker(cluster_manager.Cluster<Place> cluster) async {
    return Marker(
      markerId: MarkerId(cluster.location.toString()),
      position: cluster.location,
      onTap: () => _onClusterTapped(cluster.items.toList()),
      icon: await _getClusterMarker(cluster.count, context),
    );
  }

  void _onClusterTapped(List<Place> places) {
    setState(() => _isSheetOpen = true);

    showModalBottomSheet(
      context: context,
      builder: (context) => _buildClusterListSheet(places),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).whenComplete(() {
      setState(() => _isSheetOpen = false);
    });
  }

  Widget _buildClusterListSheet(List<Place> places) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '${places.length} Events Nearby',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: places.length,
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: CachedNetworkImage(
                          imageUrl: place.imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Image.asset(
                            'Images/Eventposter1.png', // Placeholder from assets
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'Images/Eventposter1.png', // Placeholder from assets
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(place.name),
                      subtitle: Text(place.category),
                      onTap: () {
                        _animateToLocation(place.latLng);
                        Navigator.of(context).pop();
                        _onMarkerTapped(place);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToDetail(Place place) {
    final eventDoc = place.document;
    if (eventDoc != null) {
      final data = eventDoc.data() as Map<String, dynamic>;
      final startDate = data['Date'] as Timestamp?;
      if (startDate == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailPage(
            image: data['Image'] ?? '',
            name: data['Name'] ?? 'No Name',
            startDate: startDate,
            endDate: data['endDate'] as Timestamp?,
            location: data['Location'] ?? 'No Location',
            detail: data['Detail'] ?? 'No Details',
            id: eventDoc.id,
          ),
        ),
      );
    }
  }

  static Future<BitmapDescriptor> _createCustomMarkerBitmap(String imageUrl, BuildContext context) async {
    const int size = 150;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Paint paint = Paint()..color = isDarkMode ? Colors.grey.shade800 : Theme.of(context).colorScheme.primary;
    final Paint borderPaint = Paint()
      ..color = isDarkMode ? Colors.black : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    // Draw the pin shape
    final Path pinPath = Path();
    pinPath.moveTo(size / 2, size.toDouble());
    pinPath.quadraticBezierTo(size / 2, size * 0.7, size * 0.3, size * 0.6);
    pinPath.quadraticBezierTo(size * 0.4, size * 0.75, size / 2, size.toDouble());
    canvas.drawPath(pinPath, paint);

    // Draw the circular image
    final double circleRadius = size / 3;
    final Offset circleOffset = Offset(size / 2, circleRadius);

    // Fetch and decode the image
    Uint8List imageBytes;
    try {
      if (imageUrl.isNotEmpty) {
        final file = await DefaultCacheManager().getSingleFile(imageUrl);
        imageBytes = await file.readAsBytes();
      } else {
        throw Exception("Image URL is empty");
      }
    } catch (e) {
      final ByteData data = await rootBundle.load('Images/Eventposter1.png');
      imageBytes = data.buffer.asUint8List();
    }

    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    // Clip the canvas to a circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: circleOffset, radius: circleRadius)));

    // Paint the image within the circle
    paintImage(
      canvas: canvas,
      rect: Rect.fromCircle(center: circleOffset, radius: circleRadius),
      image: image,
      fit: BoxFit.cover,
    );

    // Draw the border around the circle
    canvas.drawCircle(circleOffset, circleRadius, borderPaint);

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _getClusterMarker(int count, BuildContext context) async {
    const double size = 120; // Slightly smaller for a cleaner look
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final Paint shadowPaint = Paint()
      ..color = isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, shadowPaint);

    final Paint gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.colorScheme.primary,
          theme.colorScheme.secondary,
        ],
        center: const Alignment(0.0, 0.0),
        radius: 0.8,
      ).createShader(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2));
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, gradientPaint);

    final Paint borderPaint = Paint()
      ..color = isDarkMode ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, borderPaint);

    TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: count.toString(),
      style: TextStyle(
        fontSize: size / 3,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onPrimary,
        shadows: const [
          Shadow(
            blurRadius: 2.0,
            color: Colors.black26,
            offset: Offset(1.0, 1.0),
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2));

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
