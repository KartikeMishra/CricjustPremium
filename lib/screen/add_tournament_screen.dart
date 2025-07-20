import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/color.dart';
import 'login_screen.dart';
import 'all_tournaments_screen.dart';
import 'manage_groups_screen.dart';

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

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submitTournament() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
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

      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/add-tournament?api_logged_in_token=$token',
      );
      final req = http.MultipartRequest('POST', uri)
        ..fields['tournament_name'] = _nameController.text.trim()
        ..fields['tournament_desc'] = _descController.text.trim()
        ..fields['start_date'] = _startDateController.text.trim()
        ..fields['is_group'] = _isGroup ? '1' : '0'
        ..fields['is_open'] = _isOpen ? '1' : '0'
        ..fields['is_trial'] = _isTrial ? '1' : '0'
        ..fields['trial_end_date'] = _isTrial
            ? _trialEndDateController.text.trim()
            : '0000-00-00'
        ..fields['max_age'] = _maxAgeController.text.trim().isEmpty
            ? '0'
            : _maxAgeController.text.trim()
        ..fields['pp'] = _playersPerTeam.toString();

      // ✅ Conditionally add tournament_logo
      if (_logoImage != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'tournament_logo',
            _logoImage!.path,
          ),
        );
      }

      // ✅ Conditionally add brochure
      if (_brochureFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'tournament_brochure',
            _brochureFile!.path,
          ),
        );
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = json.decode(resp.body);
      setState(() => _isSubmitting = false);

      if (resp.statusCode == 200 && data['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Tournament added!')),
        );

        final tournamentList = data['data'] as List;
        final tournamentId = tournamentList.isNotEmpty
            ? tournamentList[0]['tournament_id']
            : null;

        if (_isGroup && tournamentId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ManageGroupsScreen(
                tournamentId: int.parse(tournamentId.toString()),
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AllTournamentsScreen(type: 'recent'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to add tournament'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  InputDecoration _fieldDecoration(String label, IconData icon, bool dark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: dark ? Colors.white12 : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],

      // ─── Gradient / dark header ───────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: dark
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: dark ? const Color(0xFF1E1E1E) : null,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Add Tournament',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: dark ? Colors.grey[850] : Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _fieldDecoration(
                      'Tournament Name',
                      Icons.emoji_events,
                      dark,
                    ),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: _fieldDecoration(
                      'Description',
                      Icons.description,
                      dark,
                    ),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () => _pickDate(_startDateController),
                    decoration: _fieldDecoration(
                      'Start Date',
                      Icons.date_range,
                      dark,
                    ),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Power-Play Overs:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _playersPerTeam,
                        items: List.generate(
                          8,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (v) => setState(() => _playersPerTeam = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Group Stage'),
                    value: _isGroup,
                    onChanged: (v) => setState(() => _isGroup = v),
                    tileColor: dark ? Colors.white12 : Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Publicly Visible'),
                    value: _isOpen,
                    onChanged: (v) => setState(() => _isOpen = v),
                    tileColor: dark ? Colors.white12 : Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Trial Tournament'),
                    value: _isTrial,
                    onChanged: (v) => setState(() => _isTrial = v),
                    tileColor: dark ? Colors.white12 : Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  if (_isTrial) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _trialEndDateController,
                      readOnly: true,
                      onTap: () => _pickDate(_trialEndDateController),
                      decoration: _fieldDecoration(
                        'Trial End Date',
                        Icons.date_range,
                        dark,
                      ),
                      style: TextStyle(
                        color: dark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maxAgeController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      'Max Age (optional)',
                      Icons.cake,
                      dark,
                    ),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Glassy Submit Button ────────────────────────
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitTournament,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white12
                                : AppColors.primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: dark
                                  ? Colors.white24
                                  : AppColors.primary.withOpacity(0.7),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: dark
                                    ? Colors.white12
                                    : AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 0.5,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _isSubmitting
                                ? const [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Saving…',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ]
                                : const [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Submit Tournament',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
