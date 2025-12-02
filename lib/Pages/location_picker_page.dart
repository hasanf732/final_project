import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:final_project/Pages/map_styles.dart';
import 'dart:ui' as ui;

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(26.2285, 50.5860); // Default to Bahrain
  BitmapDescriptor? _customMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _createCustomMarker();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled don't continue
        // accessing the position and request users of the 
        // App to enable the location services.
        return Future.error('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if(mounted){
        setState(() {
          _initialPosition = LatLng(position.latitude, position.longitude);
          _pickedLocation = _initialPosition;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
      }
    } catch (e) {
      // Handle location permission errors or other issues
    }
  }

  Future<void> _createCustomMarker() async {
    final marker = await _getMarkerFromCanvas(200, Theme.of(context).colorScheme.primary);
    if (mounted) {
      setState(() {
        _customMarker = marker;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _pickedLocation == null
                ? null
                : () {
                    Navigator.of(context).pop(_pickedLocation);
                  },
          ),
        ],
      ),
      body: GoogleMap(
        style: isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onTap: (position) {
          setState(() {
            _pickedLocation = position;
          });
        },
        markers: _pickedLocation == null || _customMarker == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId('picked-location'),
                  position: _pickedLocation!,
                  icon: _customMarker!,
                  infoWindow: const InfoWindow(
                    title: 'Selected Location',
                    snippet: 'This location will be used for the event.',
                  ),
                ),
              },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<BitmapDescriptor> _getMarkerFromCanvas(int size, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    const double radius = 30;

    // Draw the pin shape
    final Path path = Path();
    path.moveTo(size / 2, size.toDouble()); // Bottom point
    path.cubicTo(size / 2, size - 40, 0, size / 2, size / 2, 0); // Left curve to top point
    path.cubicTo(size.toDouble(), size / 2, size / 2, size - 40, size / 2, size.toDouble()); // Right curve to bottom point
    canvas.drawPath(path, paint);

    // Draw the inner circle
    final Paint innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size / 2, radius), radius - 15, innerPaint);

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }
}
