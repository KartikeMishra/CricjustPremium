import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../model/tournament_model.dart';
import '../theme/color.dart';

class UpdateTournamentScreen extends StatefulWidget {
  final TournamentModel tournament;

  const UpdateTournamentScreen({super.key, required this.tournament});

  @override
  State<UpdateTournamentScreen> createState() => _UpdateTournamentScreenState();
}

class _UpdateTournamentScreenState extends State<UpdateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _logoController;
  late TextEditingController _startDateController;
  late TextEditingController _trialEndController;
  late TextEditingController _maxAgeController;
  late TextEditingController _ppController;

  bool _isGroup = false;
  bool _isOpen = false;
  bool _isTrial = false;

  bool _isSubmitting = false;

  late String _apiToken;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.tournament.tournamentName,
    );
    _descController = TextEditingController(
      text: widget.tournament.tournamentDesc,
    );
    _logoController = TextEditingController(
      text: widget.tournament.tournamentLogo,
    );
    _startDateController = TextEditingController(
      text: widget.tournament.startDate,
    );

    // if you had trialEndDate, maxAge, pp in your model, initialize here; else leave blank
    _trialEndController = TextEditingController();
    _maxAgeController = TextEditingController();
    _ppController = TextEditingController();

    _isGroup = widget.tournament.isGroup;
    _isOpen = widget.tournament.isOpen;
    _isTrial = false;

    _loadToken();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _logoController.dispose();
    _startDateController.dispose();
    _trialEndController.dispose();
    _maxAgeController.dispose();
    _ppController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _apiToken = prefs.getString('api_logged_in_token') ?? '';
  }

  Future<void> _pickDate(
    TextEditingController ctrl, {
    bool includeTime = false,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;

    if (!includeTime) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(date);
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(date);
    } else {
      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      ctrl.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/update-tournament'
      '?api_logged_in_token=$_apiToken&tournament_id=${widget.tournament.tournamentId}',
    );

    final body = {
      'tournament_name': _nameController.text.trim(),
      'tournament_desc': _descController.text.trim(),
      'tournament_logo': _logoController.text.trim(),
      'is_group': _isGroup ? '1' : '0',
      'is_trial': _isTrial ? '1' : '0',
      'is_open': _isOpen ? '1' : '0',
      'start_date': _startDateController.text.trim(),
      'trial_end_date': _trialEndController.text.trim(),
      'max_age': _maxAgeController.text.trim(),
      'pp': _ppController.text.trim(),
    };

    final response = await http.post(uri, body: body);
    setState(() => _isSubmitting = false);

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Update failed')),
      );
    }
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          'Update Tournament',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name & Description
                  TextFormField(
                    controller: _nameController,
                    decoration: _input('Tournament Name', Icons.emoji_events),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: _input('Description', Icons.description),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // Logo URL
                  TextFormField(
                    controller: _logoController,
                    decoration: _input('Tournament Logo URL', Icons.image),
                  ),
                  const SizedBox(height: 12),

                  // Switches
                  SwitchListTile(
                    title: const Text('Enable Group Stage'),
                    value: _isGroup,
                    onChanged: (v) => setState(() => _isGroup = v),
                  ),
                  SwitchListTile(
                    title: const Text('Enable Trial'),
                    value: _isTrial,
                    onChanged: (v) => setState(() => _isTrial = v),
                  ),
                  SwitchListTile(
                    title: const Text('Publicly Visible'),
                    value: _isOpen,
                    onChanged: (v) => setState(() => _isOpen = v),
                  ),

                  const SizedBox(height: 12),

                  // Dates
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () => _pickDate(_startDateController),
                    decoration: _input(
                      'Start Date (YYYY-MM-DD)',
                      Icons.date_range,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _trialEndController,
                    readOnly: true,
                    onTap: () =>
                        _pickDate(_trialEndController, includeTime: true),
                    decoration: _input(
                      'Trial End Date (YYYY-MM-DD HH:mm:ss)',
                      Icons.schedule,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Numbers
                  TextFormField(
                    controller: _maxAgeController,
                    decoration: _input('Max Age (optional)', Icons.numbers),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ppController,
                    decoration: _input('Players Per Team (pp)', Icons.people),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitUpdate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.blue.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.white12
                                : Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Update Tournament",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
