import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:random_string/random_string.dart';

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
  File? selectedImage;
  String? _selectedCategory;
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
      selectedImage = null;
      _selectedDate = null;
      _selectedTime = null;
      _selectedCategory = null;
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

  Future getImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImage = File(image.path);
      setState(() {});
    }
  }

  uploadItem() async {
    if (_isUploading) return;

    if (selectedImage != null &&
        _nameController.text.isNotEmpty &&
        _selectedDate != null &&
        _selectedCategory != null) {
      setState(() {
        _isUploading = true;
      });

      String addId = randomAlphaNumeric(10);

      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child("blogImage").child(addId);
      final UploadTask task = firebaseStorageRef.putFile(selectedImage!);

      try {
        var downloadUrl = await (await task).ref.getDownloadURL();
        Map<String, dynamic> addEvent = {
          "Name": _nameController.text,
          "Detail": _detailController.text,
          "Location": _locationController.text,
          "Time": _selectedTime?.format(context) ?? '',
          "Date": Timestamp.fromDate(_selectedDate!),
          "Image": downloadUrl,
          "Category": _selectedCategory,
          "ratings": {},
        };

        await DatabaseMethods().addEvent(addEvent, addId).then((value) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Event has been uploaded successfully")));
          _resetForm();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error uploading event: $e")));
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please fill all fields, including category, and select an image.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Upload Event",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    getImage();
                  },
                  child: selectedImage == null
                      ? Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.camera_alt_outlined, size: 50.0),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            selectedImage!,
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 20.0),
               _buildDropdown("Category", _selectedCategory, _categories, (value) {
                setState(() {
                  _selectedCategory = value;
                });
              }),
              SizedBox(height: 20.0),
              _buildTextField("Event Name", _nameController),
              SizedBox(height: 20.0),
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
                  SizedBox(width: 20),
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
              SizedBox(height: 20.0),
              _buildTextField("Location", _locationController),
              SizedBox(height: 20.0),
              _buildDetailTextField("Event Detail", _detailController),
              SizedBox(height: 40.0),
              Center(
                child: ElevatedButton(
                  onPressed: _isUploading ? null : uploadItem,
                  child: _isUploading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("Add Event", style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5.0),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(border: InputBorder.none),
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
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5.0),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(border: InputBorder.none, hintText: "Enter details here..."),
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
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5.0),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade700),
                SizedBox(width: 10),
                Text(value, style: TextStyle(fontSize: 16.0)),
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
        style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 5.0),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10)),
        child: DropdownButtonFormField<String>(
          value: selectedValue,
          hint: Text("Select a category"),
          isExpanded: true,
          decoration: InputDecoration(border: InputBorder.none),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

}
