import 'dart:io';
import 'dart:typed_data';
import 'package:final_project/Pages/location_picker_page.dart';
import 'package:final_project/services/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class UploadEvent extends StatefulWidget {
  const UploadEvent({super.key});

  @override
  State<UploadEvent> createState() => _UploadEventState();
}

class _UploadEventState extends State<UploadEvent> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Uint8List? _selectedImageBytes;
  String? _selectedCategory;
  LatLng? _pickedLocation;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();
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

  void _resetForm() {
    _nameController.clear();
    _detailController.clear();
    _locationController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedDate = null;
      _selectedTime = null;
      _selectedCategory = null;
      _pickedLocation = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickLocation() async {
    if (!mounted) return;
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

  Future getImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = File(image.path);
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

  uploadItem() async {
    if (_isUploading) return;

    if (_selectedImageBytes == null ||
        _nameController.text.isEmpty ||
        _detailController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _pickedLocation == null ||
        _selectedCategory == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fill all fields and select an image, date, time, category, and location.")));
      return;
    }

    setState(() {
      _isUploading = true;
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
        _selectedImageBytes!,
        _nameController.text.trim(),
        _detailController.text.trim(),
        _locationController.text.trim(),
        _pickedLocation!.latitude,
        _pickedLocation!.longitude,
        combinedDateTime,
        _selectedCategory!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event has been uploaded successfully")));
      _resetForm();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading event: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Upload Event",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    getImage();
                  },
                  child: _selectedImageBytes == null
                      ? Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.camera_alt_outlined, size: 50.0),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _selectedImageBytes!,
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20.0),
              _buildDropdown("Category", _selectedCategory, _categories, (value) {
                setState(() {
                  _selectedCategory = value;
                });
              }),
              const SizedBox(height: 20.0),
              _buildTextField("Event Name", _nameController),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Expanded(
                    child: _buildPicker(
                        "Date",
                        _selectedDate == null
                            ? "Select Date"
                            : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                        Icons.calendar_today,
                        () => _selectDate(context)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildPicker(
                        "Time",
                        _selectedTime == null
                            ? "Select Time"
                            : _selectedTime!.format(context),
                        Icons.access_time,
                        () => _selectTime(context)),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              _buildTextField("Location Description", _locationController),
              const SizedBox(height: 20.0),
              _buildLocationPicker(),
              const SizedBox(height: 20.0),
              _buildDetailTextField("Event Detail", _detailController),
              const SizedBox(height: 40.0),
              Center(
                child: ElevatedButton(
                  onPressed: _isUploading ? null : uploadItem,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Add Event", style: TextStyle(fontSize: 20)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Event Coordinates",
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10)),
          child: Text(
            _pickedLocation == null
                ? "No location selected"
                : "Lat: ${_pickedLocation!.latitude.toStringAsFixed(4)}, Lon: ${_pickedLocation!.longitude.toStringAsFixed(4)}",
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
        const SizedBox(height: 10.0),
        Center(
          child: ElevatedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.map),
            label: const Text("Pick Location on Map"),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        )
      ],
    );
  }

  Widget _buildDetailTextField(String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(border: InputBorder.none, hintText: "Enter details here..."),
          ),
        )
      ],
    );
  }

  Widget _buildPicker(
      String title, String value, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5.0),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade700),
                const SizedBox(width: 10),
                Text(value, style: const TextStyle(fontSize: 16.0)),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildDropdown(String title, String? selectedValue, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonFormField<String>(
            hint: const Text("Select a category"),
            isExpanded: true,
            decoration: const InputDecoration(border: InputBorder.none),
            items: items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: onChanged,
            value: selectedValue,
          ),
        ),
      ],
    );
  }
}
