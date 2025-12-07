import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:final_project/Pages/map_styles.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(26.2285, 50.5860); // Default to Bahrain

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
      }
    } catch (e) {
      // Handle location permission errors or other issues
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap to Pick Location'),
      ),
      body: FutureBuilder<String>(
        future: MapStyles.getStyle(isDarkMode ? 'Images/map_style_dark.json' : 'Images/map_style.json'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading map style'));
          }
          return GoogleMap(
            style: snapshot.data,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
            },
            onTap: (position) {
              Navigator.of(context).pop(position);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
