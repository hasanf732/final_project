import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  final _registrationStartDateController = TextEditingController();
  final _registrationEndDateController = TextEditingController();
  final _participantLimitController = TextEditingController();

  DateTime? _selectedStartDate;
  TimeOfDay? _selectedStartTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  DateTime? _selectedRegistrationStartDate;
  DateTime? _selectedRegistrationEndDate;
  bool _unlimitedParticipants = false;

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
          _selectedStartDate = (data['Date'] as Timestamp).toDate();
          _selectedStartTime = TimeOfDay.fromDateTime(_selectedStartDate!);
        }
        if (data['endDate'] != null) {
          _selectedEndDate = (data['endDate'] as Timestamp).toDate();
          _selectedEndTime = TimeOfDay.fromDateTime(_selectedEndDate!);
        }
        if (data['registrationStartDate'] != null) {
          _selectedRegistrationStartDate = (data['registrationStartDate'] as Timestamp).toDate();
          _registrationStartDateController.text = DateFormat('yyyy-MM-dd').format(_selectedRegistrationStartDate!);
        }
        if (data['registrationEndDate'] != null) {
          _selectedRegistrationEndDate = (data['registrationEndDate'] as Timestamp).toDate();
          _registrationEndDateController.text = DateFormat('yyyy-MM-dd').format(_selectedRegistrationEndDate!);
        }
        if (data['participantLimit'] != null) {
          if (data['participantLimit'] == -1) {
            _unlimitedParticipants = true;
          } else {
            _participantLimitController.text = data['participantLimit'].toString();
          }
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

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedStartTime) {
      setState(() {
        _selectedStartTime = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedStartDate ?? DateTime.now(),
      firstDate: _selectedStartDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? _selectedStartTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedEndTime) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  Future<void> _selectRegistrationStartDate(BuildContext context) async {
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

  Future<void> _selectRegistrationEndDate(BuildContext context) async {
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
                    child: Text(_selectedStartDate == null
                        ? 'No start date selected'
                        : 'Start Date: ${DateFormat('yyyy-MM-dd').format(_selectedStartDate!)}'),
                  ),
                  TextButton(
                    onPressed: () => _selectStartDate(context),
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_selectedStartTime == null
                        ? 'No start time selected'
                        : 'Start Time: ${_selectedStartTime!.format(context)}'),
                  ),
                  TextButton(
                    onPressed: () => _selectStartTime(context),
                    child: const Text('Select Time'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(_selectedEndDate == null
                        ? 'No end date selected'
                        : 'End Date: ${DateFormat('yyyy-MM-dd').format(_selectedEndDate!)}'),
                  ),
                  TextButton(
                    onPressed: () => _selectEndDate(context),
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_selectedEndTime == null
                        ? 'No end time selected'
                        : 'End Time: ${_selectedEndTime!.format(context)}'),
                  ),
                  TextButton(
                    onPressed: () => _selectEndTime(context),
                    child: const Text('Select Time'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text('Registration Settings', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _registrationStartDateController,
                      readOnly: true,
                      onTap: () => _selectRegistrationStartDate(context),
                      decoration: const InputDecoration(labelText: 'Registration Start'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _registrationEndDateController,
                      readOnly: true,
                      onTap: () => _selectRegistrationEndDate(context),
                      decoration: const InputDecoration(labelText: 'Registration End'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _participantLimitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !_unlimitedParticipants,
                      decoration: const InputDecoration(labelText: 'Participant Limit'),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final eventData = {
                      'Name': _nameController.text,
                      'Detail': _detailController.text,
                      'Location': _locationController.text,
                      'Date': _selectedStartDate != null && _selectedStartTime != null
                          ? Timestamp.fromDate(DateTime(
                              _selectedStartDate!.year,
                              _selectedStartDate!.month,
                              _selectedStartDate!.day,
                              _selectedStartTime!.hour,
                              _selectedStartTime!.minute,
                            ))
                          : null,
                      'endDate': _selectedEndDate != null && _selectedEndTime != null
                          ? Timestamp.fromDate(DateTime(
                              _selectedEndDate!.year,
                              _selectedEndDate!.month,
                              _selectedEndDate!.day,
                              _selectedEndTime!.hour,
                              _selectedEndTime!.minute,
                            ))
                          : null,
                      'registrationStartDate': _selectedRegistrationStartDate,
                      'registrationEndDate': _selectedRegistrationEndDate,
                      'participantLimit': _unlimitedParticipants ? -1 : int.tryParse(_participantLimitController.text),
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
