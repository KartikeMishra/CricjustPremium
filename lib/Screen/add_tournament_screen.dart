import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/color.dart';
import 'login_screen.dart';
import 'all_tournaments_screen.dart';

class AddTournamentScreen extends StatefulWidget {
  const AddTournamentScreen({super.key});

  @override
  State<AddTournamentScreen> createState() => _AddTournamentScreenState();
}

class _AddTournamentScreenState extends State<AddTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _trialEndDateController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  int _playersPerTeam = 4;
  bool _isGroup = false;
  bool _isOpen = false;
  bool _isTrial = false;

  File? _logoImage;
  File? _brochureFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (selected != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(selected);
    }
  }

  Future<void> _submitTournament() async {
    if (!_formKey.currentState!.validate()) return;
    if (_logoImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload tournament logo')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    final uri = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/add-tournament?api_logged_in_token=$token');
    final request = http.MultipartRequest('POST', uri);

    request.fields['tournament_name'] = _nameController.text.trim();
    request.fields['tournament_desc'] = _descController.text.trim();
    request.fields['start_date'] = _startDateController.text.trim();
    request.fields['is_group'] = _isGroup ? '1' : '0';
    request.fields['is_open'] = _isOpen ? '1' : '0';
    request.fields['is_trial'] = _isTrial ? '1' : '0';
    request.fields['trial_end_date'] = _isTrial ? _trialEndDateController.text.trim() : '0000-00-00';
    request.fields['max_age'] = _maxAgeController.text.trim().isEmpty ? '0' : _maxAgeController.text.trim();
    request.fields['pp'] = _playersPerTeam.toString();

    request.files.add(await http.MultipartFile.fromPath('tournament_logo', _logoImage!.path));
    if (_brochureFile != null) {
      request.files.add(await http.MultipartFile.fromPath('tournament_brochure', _brochureFile!.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    setState(() => _isSubmitting = false);

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Tournament added successfully')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AllTournamentsScreen(type: 'recent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Failed to add tournament')),
      );
    }
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Tournament'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _input('Tournament Name', Icons.emoji_events),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: _input('Description', Icons.description),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                onTap: () => _pickDate(_startDateController),
                decoration: _input('Start Date', Icons.date_range),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Power Play Over: ", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _playersPerTeam,
                    items: List.generate(8, (i) => 0 + i).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (v) => setState(() => _playersPerTeam = v!),
                  )
                ],
              ),
              SwitchListTile(
                title: const Text('Enable Group Stage'),
                value: _isGroup,
                onChanged: (v) => setState(() => _isGroup = v),
              ),
              SwitchListTile(
                title: const Text('Publicly Visible'),
                value: _isOpen,
                onChanged: (v) => setState(() => _isOpen = v),
              ),
              SwitchListTile(
                title: const Text('Trial Tournament'),
                value: _isTrial,
                onChanged: (v) => setState(() => _isTrial = v),
              ),
              if (_isTrial)
                TextFormField(
                  controller: _trialEndDateController,
                  readOnly: true,
                  onTap: () => _pickDate(_trialEndDateController),
                  decoration: _input('Trial End Date', Icons.date_range),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxAgeController,
                keyboardType: TextInputType.number,
                decoration: _input('Maximum Age (optional)', Icons.cake),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitTournament,
                  icon: const Icon(Icons.check_circle_outline),
                  label: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Tournament'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
