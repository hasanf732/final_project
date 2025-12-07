import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/Pages/location_picker_page.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
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
  final _startDateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endDateController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _registrationStartDateController = TextEditingController();
  final _registrationEndDateController = TextEditingController();
  final _participantLimitController = TextEditingController();

  Uint8List? _selectedImageBytes;
  DateTime? _selectedStartDate;
  TimeOfDay? _selectedStartTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  DateTime? _selectedRegistrationStartDate;
  DateTime? _selectedRegistrationEndDate;
  bool _unlimitedParticipants = false;
  LatLng? _pickedLocation;
  String? _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = [
    'Music',
    'Media',
    'Sport',
    'Astro',
    'Art',
    'Film',
    'Volunteer',
    'Cyber'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    _locationNameController.dispose();
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    _registrationStartDateController.dispose();
    _registrationEndDateController.dispose();
    _participantLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 85,
        minWidth: 1024,
        minHeight: 768,
      );
      if (compressedBytes != null) {
        setState(() {
          _selectedImageBytes = compressedBytes;
        });
      }
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

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedStartTime) {
      setState(() {
        _selectedStartTime = picked;
        _startTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedStartDate ?? DateTime.now(),
      firstDate: _selectedStartDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? _selectedStartTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedEndTime) {
      setState(() {
        _selectedEndTime = picked;
        _endTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _pickRegistrationStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRegistrationStartDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _selectedStartDate ?? DateTime(2101),
    );
    if (picked != null && picked != _selectedRegistrationStartDate) {
      setState(() {
        _selectedRegistrationStartDate = picked;
        _registrationStartDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickRegistrationEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRegistrationEndDate ?? _selectedRegistrationStartDate ?? DateTime.now(),
      firstDate: _selectedRegistrationStartDate ?? DateTime.now(),
      lastDate: _selectedStartDate ?? DateTime(2101),
    );
    if (picked != null && picked != _selectedRegistrationEndDate) {
      setState(() {
        _selectedRegistrationEndDate = picked;
        _registrationEndDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImageBytes == null ||
        _pickedLocation == null ||
        _selectedStartDate == null ||
        _selectedStartTime == null ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields for the event.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = DateTime(
        _selectedStartDate!.year,
        _selectedStartDate!.month,
        _selectedStartDate!.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );

      final endDateTime = _selectedEndDate != null && _selectedEndTime != null
          ? DateTime(
              _selectedEndDate!.year,
              _selectedEndDate!.month,
              _selectedEndDate!.day,
              _selectedEndTime!.hour,
              _selectedEndTime!.minute,
            )
          : null;
      final registrationStartDateTime = _selectedRegistrationStartDate;
      final registrationEndDateTime = _selectedRegistrationEndDate;
      final participantLimit = _unlimitedParticipants ? -1 : int.tryParse(_participantLimitController.text);

      await DatabaseMethods().addNews(
        _selectedImageBytes!,
        _nameController.text.trim(),
        _detailController.text.trim(),
        _locationNameController.text.trim(),
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
        startDateTime,
        _selectedCategory!,
        endDate: endDateTime,
        registrationStartDate: registrationStartDateTime,
        registrationEndDate: registrationEndDateTime,
        participantLimit: participantLimit,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.green, content: Text('Event created successfully!')),
      );
      _formKey.currentState?.reset();
      setState(() {
        _selectedImageBytes = null;
        _pickedLocation = null;
        _selectedCategory = null;
        _startDateController.clear();
        _startTimeController.clear();
        _endDateController.clear();
        _endTimeController.clear();
        _nameController.clear();
        _detailController.clear();
        _locationNameController.clear();
        _registrationStartDateController.clear();
        _registrationEndDateController.clear();
        _participantLimitController.clear();
        _unlimitedParticipants = false;
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
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePicker(theme),
            const SizedBox(height: 20),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
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
                Expanded(
                    child: _buildTextFormField(_startDateController, 'Start Date',
                        readOnly: true, onTap: _pickStartDate)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextFormField(_startTimeController, 'Start Time',
                        readOnly: true, onTap: _pickStartTime)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextFormField(_endDateController, 'End Date',
                        readOnly: true, onTap: _pickEndDate)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextFormField(_endTimeController, 'End Time',
                        readOnly: true, onTap: _pickEndTime)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text('Registration Settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextFormField(
                        _registrationStartDateController, 'Registration Start',
                        readOnly: true, onTap: _pickRegistrationStartDate)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextFormField(
                        _registrationEndDateController, 'Registration End',
                        readOnly: true, onTap: _pickRegistrationEndDate)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    _participantLimitController,
                    'Participant Limit',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !_unlimitedParticipants,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Text('Unlimited'),
                    Switch(
                      value: _unlimitedParticipants,
                      onChanged: (value) {
                        setState(() {
                          _unlimitedParticipants = value;
                        });
                      },
                    ),
                  ],
                )
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
        child: _selectedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 40, color: theme.colorScheme.primary),
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
              _pickedLocation == null
                  ? 'Pick Location on Map'
                  : 'Location Selected!',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _pickedLocation != null
                    ? Colors.green
                    : theme.colorScheme.onSurface,
                fontWeight: _pickedLocation != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (_pickedLocation != null)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label,
      {int maxLines = 1, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, bool? enabled}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: enabled,
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

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      hint: const Text('Select Category'),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      items: _categories.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'Please select a category' : null,
    );
  }
}

class EventStatisticsTab extends StatelessWidget {
  const EventStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
          child: Text("You must be logged in to view statistics."));
    }

    return StreamBuilder<Map<String, int>>(
      stream: DatabaseMethods().getEventRegistrationCounts(),
      builder: (context, regCountSnapshot) {
        if (regCountSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (regCountSnapshot.hasError) {
          return Center(
              child: Text("Error fetching stats: ${regCountSnapshot.error}"));
        }

        final registrationCounts = regCountSnapshot.data ?? {};

        return StreamBuilder<Map<String, int>>(
          stream: DatabaseMethods().getEventAttendanceCounts(),
          builder: (context, attendanceSnapshot) {
            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (attendanceSnapshot.hasError) {
              return Center(
                  child: Text("Error fetching stats: ${attendanceSnapshot.error}"));
            }

            final attendanceCounts = attendanceSnapshot.data ?? {};

            return StreamBuilder<QuerySnapshot>(
              stream: DatabaseMethods().getAdminEventDetails(),
              builder: (context, eventSnapshot) {
                if (eventSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (eventSnapshot.hasError) {
                  return Center(child: Text("Error: ${eventSnapshot.error}"));
                }
                if (!eventSnapshot.hasData ||
                    eventSnapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("You have not created any events yet."));
                }

                final filteredDocs = eventSnapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['creatorId'] == currentUser.uid;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Text("You have not created any events yet."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 100.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var eventDoc = filteredDocs[index];
                    var eventData = eventDoc.data() as Map<String, dynamic>;
                    var eventName = eventData['Name'] ?? 'Unnamed Event';
                    var ratings =
                        eventData['ratings'] as Map<String, dynamic>? ?? {};
                    double averageRating = 0;
                    if (ratings.isNotEmpty) {
                      averageRating = ratings.values
                              .map((r) => r['rating'] as num)
                              .fold(0.0, (prev, element) => prev + element) /
                          ratings.length;
                    }

                    final registrationCount =
                        registrationCounts[eventDoc.id] ?? 0;
                    final attendanceCount = attendanceCounts[eventDoc.id] ?? 0;

                    return Card(
                      elevation: 2.0,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(eventName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12.0,
                              runSpacing: 4.0,
                              alignment: WrapAlignment.spaceAround,
                              children: [
                                Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_alt_outlined,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Text('$registrationCount Registered',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ]),
                                Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Text('$attendanceCount Attended',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ]),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_border, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                        '${averageRating.toStringAsFixed(1)} (${ratings.length} Reviews)',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
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
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _verifyQrCode(String data) async {
    if (_isProcessing || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final parts = data.split('_');
      if (parts.length != 2) {
        _showScanResultDialog(ScanStatus.invalidQr);
        return;
      }

      final userId = parts[0];
      final eventId = parts[1];

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final eventDoc =
          await FirebaseFirestore.instance.collection('News').doc(eventId).get();

      if (!userDoc.exists || !eventDoc.exists) {
        _showScanResultDialog(ScanStatus.notFound,
            userData: userDoc.data(), eventData: eventDoc.data());
        return;
      }

      final userData = userDoc.data()!;
      final eventData = eventDoc.data()!;
      final bookedEvents = List<String>.from(userData['bookedEvents'] ?? []);
      final attendedEvents =
          List<String>.from(userData['attendedEvents'] ?? []);

      if (attendedEvents.contains(eventId)) {
        _showScanResultDialog(ScanStatus.alreadyScanned,
            userData: userData, eventData: eventData);
      } else if (bookedEvents.contains(eventId)) {
        await DatabaseMethods().markUserAsAttended(userId, eventId);
        _showScanResultDialog(ScanStatus.valid,
            userData: userData, eventData: eventData);
      } else {
        _showScanResultDialog(ScanStatus.invalidTicket,
            userData: userData, eventData: eventData);
      }
    } catch (e) {
      _showScanResultDialog(ScanStatus.error);
    }
  }

  void _showScanResultDialog(ScanStatus status,
      {Map<String, dynamic>? userData, Map<String, dynamic>? eventData}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _TicketDetailsCard(
              status: status,
              userData: userData,
              eventData: eventData,
              scrollController: scrollController,
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_isProcessing) return;
            final String? code = capture.barcodes.first.rawValue;
            if (code != null) {
              _verifyQrCode(code);
            }
          },
        ),
        // Visual Finder
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Instruction Text
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Align QR code within the frame',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),

        if (_isProcessing &&
            !ModalRoute.of(context)!
                .isCurrent) // Only show spinner if no dialog is up
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }
}

enum ScanStatus {
  valid,
  invalidTicket,
  invalidQr,
  notFound,
  alreadyScanned,
  error
}

class _TicketDetailsCard extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? eventData;
  final ScanStatus status;
  final ScrollController scrollController;

  const _TicketDetailsCard({
    this.userData,
    this.eventData,
    required this.status,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, message) = _getStatusInfo(status);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ListView(
                controller: scrollController,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 32),
                      const SizedBox(width: 12),
                      Text(title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  const Divider(),

                  if (eventData != null) ...[
                    const SizedBox(height: 16),
                    Text("Event Details",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        theme, Icons.event, 'Event', eventData!['Name'] ?? 'N/A'),
                    _buildInfoRow(
                        theme,
                        Icons.calendar_today,
                        'Date',
                        _formatTimestamp(
                            eventData!['Date'], 'EEE, MMM d, yyyy')),
                    _buildInfoRow(theme, Icons.access_time, 'Time',
                        _formatTimestamp(eventData!['Date'], 'h:mm a')),
                    _buildInfoRow(theme, Icons.location_on, 'Location',
                        eventData!['Location'] ?? 'N/A'),
                    const SizedBox(height: 16),
                    const Divider(),
                  ],

                  if (userData != null) ...[
                    const SizedBox(height: 16),
                    Text("User Information",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        theme, Icons.person, 'Name', userData!['Name'] ?? 'N/A'),
                    _buildInfoRow(
                        theme,
                        Icons.email,
                        'Email',
                        (userData!['Email'] ?? userData!['email']) ?? 'N/A'),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Scan Next Ticket'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String, String) _getStatusInfo(ScanStatus status) {
    switch (status) {
      case ScanStatus.valid:
        return (
          Icons.check_circle,
          Colors.green,
          "Access Granted",
          "User is validated for this event."
        );
      case ScanStatus.invalidTicket:
        return (
          Icons.cancel,
          Colors.red,
          "Invalid Ticket",
          "This user has not booked this event."
        );
      case ScanStatus.alreadyScanned:
        return (
          Icons.history,
          Colors.orange,
          "Already Scanned",
          "This ticket has already been used."
        );
      case ScanStatus.notFound:
        return (
          Icons.error,
          Colors.red,
          "Not Found",
          "The user or event associated with this QR code could not be found."
        );
      case ScanStatus.invalidQr:
        return (
          Icons.qr_code_scanner,
          Colors.red,
          "Invalid QR Code",
          "The scanned QR code is not in the correct format."
        );
      case ScanStatus.error:
        return (
          Icons.report_problem,
          Colors.red,
          "System Error",
          "An unexpected error occurred during verification."
        );
    }
  }

  String _formatTimestamp(Timestamp? timestamp, String format) {
    if (timestamp == null) return 'N/A';
    return DateFormat(format).format(timestamp.toDate());
  }
}
