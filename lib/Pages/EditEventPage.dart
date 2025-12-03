import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditEventPage extends StatefulWidget {
  final String eventId;
  const EditEventPage({super.key, required this.eventId});

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _authorizeAndLoadEventData();
  }

  Future<void> _authorizeAndLoadEventData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
        });
      }
      return;
    }

    DocumentSnapshot eventDoc = await DatabaseMethods().getEventById(widget.eventId);
    if (mounted && eventDoc.exists) {
      final data = eventDoc.data() as Map<String, dynamic>;
      final creatorId = data['creatorId'];

      if (creatorId == currentUser.uid) {
        _nameController.text = data['Name'] ?? '';
        _detailController.text = data['Detail'] ?? '';
        _locationController.text = data['Location'] ?? '';
        if (data['Date'] != null) {
          _selectedDate = (data['Date'] as Timestamp).toDate();
          _selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
        }
        setState(() {
          _isAuthorized = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _isAuthorized = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('You are not authorized to edit this event.'),
            ),
          );
          Navigator.of(context).pop();
        }
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Container(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Event Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _detailController,
                decoration: const InputDecoration(labelText: 'Event Detail'),
                maxLines: 3,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Event Location'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(_selectedDate == null
                        ? 'No date selected'
                        : 'Date: ${_selectedDate!.toLocal()}'.split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_selectedTime == null
                        ? 'No time selected'
                        : 'Time: ${_selectedTime!.format(context)}'),
                  ),
                  TextButton(
                    onPressed: () => _selectTime(context),
                    child: const Text('Select Time'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final eventData = {
                      'Name': _nameController.text,
                      'Detail': _detailController.text,
                      'Location': _locationController.text,
                      'Date': _selectedDate != null && _selectedTime != null
                          ? Timestamp.fromDate(DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              _selectedTime!.hour,
                              _selectedTime!.minute,
                            ))
                          : null,
                    };
                    await DatabaseMethods().updateEvent(widget.eventId, eventData);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
