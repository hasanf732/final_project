import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/location_picker_page.dart';
import 'package:final_project/services/database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Create Event'),
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Statistics'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CreateEventTab(),
          EventStatisticsTab(),
          ScanQrPage(),
        ],
      ),
    );
  }
}

class CreateEventTab extends StatefulWidget {
  const CreateEventTab({super.key});

  @override
  State<CreateEventTab> createState() => _CreateEventTabState();
}

class _CreateEventTabState extends State<CreateEventTab> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _detailController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  File? _selectedImage;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _pickedLocation;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    _locationNameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(),
      ),
    );

    if (picked != null) {
      setState(() {
        _pickedLocation = picked;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null ||
        _pickedLocation == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields for the event.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await DatabaseMethods().addNews(
        _selectedImage!,
        _nameController.text.trim(),
        _detailController.text.trim(),
        _locationNameController.text.trim(),
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
        combinedDateTime,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('Event created successfully!')),
      );
      _formKey.currentState?.reset();
      setState(() {
        _selectedImage = null;
        _pickedLocation = null;
        _dateController.clear();
        _timeController.clear();
        _nameController.clear();
        _detailController.clear();
        _locationNameController.clear();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Failed to create event: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePicker(theme),
            const SizedBox(height: 20),
            _buildTextFormField(_nameController, 'Event Name'),
            const SizedBox(height: 16),
            _buildTextFormField(_detailController, 'Event Details', maxLines: 5),
            const SizedBox(height: 16),
            _buildTextFormField(_locationNameController, 'Location Name (e.g. Building 15)'),
            const SizedBox(height: 16),
            _buildLocationPicker(theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextFormField(_dateController, 'Date', readOnly: true, onTap: _pickDate)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextFormField(_timeController, 'Time', readOnly: true, onTap: _pickTime)),
              ],
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitEvent,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: const Text('Create Event'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: theme.dividerColor),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  const Text('Tap to select an image'),
                ],
              ),
      ),
    );
  }

  Widget _buildLocationPicker(ThemeData theme) {
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade600),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              _pickedLocation == null ? 'Pick Location on Map' : 'Location Selected!',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _pickedLocation != null ? Colors.green : theme.colorScheme.onSurface,
                fontWeight: _pickedLocation != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (_pickedLocation != null) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label,
      {int maxLines = 1, bool readOnly = false, VoidCallback? onTap}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the $label';
        }
        return null;
      },
    );
  }
}

class EventStatisticsTab extends StatelessWidget {
  const EventStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseMethods().getEventDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No events have been created yet."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var eventDoc = snapshot.data!.docs[index];
            var eventData = eventDoc.data() as Map<String, dynamic>;
            var eventName = eventData['Name'] ?? 'Unnamed Event';
            var ratings = eventData['ratings'] as Map<String, dynamic>? ?? {};
            double averageRating = 0;
            if (ratings.isNotEmpty) {
              averageRating = ratings.values.map((r) => r['rating'] as num).fold(0.0, (prev, element) => prev + element) /
                  ratings.length;
            }

            return Card(
              elevation: 2.0,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eventName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FutureBuilder<int>(
                          future: DatabaseMethods().getRegistrationCount(eventDoc.id),
                          builder: (context, regSnapshot) {
                            if (regSnapshot.connectionState == ConnectionState.waiting) {
                              return const Row(children: [Icon(Icons.people_alt_outlined, size: 16), SizedBox(width: 8), Text('Loading...')]);
                            }
                            return Row(children: [
                              const Icon(Icons.people_alt_outlined, size: 16),
                              const SizedBox(width: 8),
                              Text('${regSnapshot.data ?? 0} Registered', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]);
                          },
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_border, size: 16),
                            const SizedBox(width: 8),
                            Text('${averageRating.toStringAsFixed(1)} (${ratings.length} Reviews)', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  String? _scannedData;
  bool _isValid = false;
  bool _isProcessing = false;

  Future<void> _verifyQrCode(String data) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final parts = data.split('_');
      if (parts.length != 2) {
        setState(() {
          _scannedData = "Invalid QR Code";
          _isValid = false;
        });
        return;
      }

      final userId = parts[0];
      final eventId = parts[1];

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        setState(() {
          _scannedData = "User not found";
          _isValid = false;
        });
        return;
      }

      final userData = userDoc.data()!;
      final bookedEvents = List<String>.from(userData['bookedEvents'] ?? []);

      if (bookedEvents.contains(eventId)) {
        setState(() {
          _scannedData = "Valid Ticket for ${userData['Name']}";
          _isValid = true;
        });
      } else {
        setState(() {
          _scannedData = "Invalid Ticket for ${userData['Name']}";
          _isValid = false;
        });
      }
    } catch (e) {
      setState(() {
        _scannedData = "Error: $e";
        _isValid = false;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && !_isProcessing) {
              final String code = barcodes.first.rawValue!;
              _verifyQrCode(code);
            }
          },
        ),
        if (_scannedData != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: _isValid ? theme.colorScheme.primary : theme.colorScheme.error,
              child: Text(
                _scannedData!,
                style: TextStyle(color: _isValid ? theme.colorScheme.onPrimary : theme.colorScheme.onError, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_isProcessing)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
