// lib/screen/add_tournament_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/user_image_service.dart';
import '../theme/color.dart';
import 'all_tournaments_screen.dart';
import 'login_screen.dart';
import 'manage_groups_screen.dart';

class AddTournamentScreen extends StatefulWidget {
  const AddTournamentScreen({super.key});

  @override
  State<AddTournamentScreen> createState() => _AddTournamentScreenState();
}

class _AddTournamentScreenState extends State<AddTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _startDateController = TextEditingController();
  final _trialEndDateController = TextEditingController();
  final _maxAgeController = TextEditingController();

  int _playersPerTeam = 4;
  bool _isGroup = false;
  bool _isOpen = false;
  bool _isTrial = false;

  // Logo is a URL (API expects full URL)
  String? _logoUrl;
  bool _uploadingLogo = false;

  // Optional brochure as a file (kept, API accepts multipart)
  File? _brochureFile;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _startDateController.dispose();
    _trialEndDateController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // ----------------------- UI HELPERS -----------------------
  InputDecoration _input(String label, IconData icon, bool dark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: dark ? Colors.white10 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? Colors.white24 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? Colors.white24 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  Widget _sectionTitle(String text, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null)
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
        if (icon != null) const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ----------------------- PICKERS -----------------------
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

  // Pick + upload tournament logo → store FULL URL in _logoUrl
  Future<void> _pickAndUploadLogo(ImageSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70, // compress
      maxWidth: 900,    // resize
    );
    if (picked == null) return;

    final file = File(picked.path);
    final lower = picked.path.toLowerCase();

    // validate type + size
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only JPG and PNG images are allowed')));
      return;
    }
    final sizeMB = (await file.length()) / (1024 * 1024);
    if (sizeMB > 2.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be under 2 MB')));
      return;
    }

    setState(() => _uploadingLogo = true);
    try {
      final url = await UserImageService.uploadAndGetUrl(
        token: token,
        file: file,
        postTimeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      setState(() => _logoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  // ----------------------- SUBMIT -----------------------
  Future<void> _submitTournament() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadingLogo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the logo upload to finish')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_logged_in_token') ?? '';
      if (token.isEmpty) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
        ..fields['trial_end_date'] = _isTrial ? _trialEndDateController.text.trim() : '0000-00-00'
        ..fields['max_age'] = _maxAgeController.text.trim().isEmpty ? '0' : _maxAgeController.text.trim()
        ..fields['pp'] = _playersPerTeam.toString();

      // API expects full URL for logo
      if ((_logoUrl ?? '').isNotEmpty) {
        req.fields['tournament_logo'] = _logoUrl!;
      }

      // Optional brochure file
      if (_brochureFile != null) {
        req.files.add(await http.MultipartFile.fromPath('tournament_brochure', _brochureFile!.path));
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = json.decode(resp.body);

      setState(() => _isSubmitting = false);

      // Session invalid → redirect
      if (resp.statusCode == 200 &&
          data is Map &&
          data['status'] == 0 &&
          data['message'] != null &&
          data['message'].toString().toLowerCase().contains('invalid api logged in token')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
          await prefs.remove('api_logged_in_token');
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        }
        return;
      }

      if (resp.statusCode == 200 && data['status'] == 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Tournament added!')),
        );

        final list = data['data'] as List?;
        final tournamentId = (list != null && list.isNotEmpty) ? list[0]['tournament_id'] : null;

        if (_isGroup && tournamentId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ManageGroupsScreen(tournamentId: int.parse(tournamentId.toString())),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AllTournamentsScreen(type: 'recent')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to add tournament')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ----------------------- BUILD -----------------------
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text('Add Tournament',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: dark ? Colors.grey[850] : Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Basics
                  _sectionTitle('Basics', icon: Icons.info_outline),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: _input('Tournament Name', Icons.emoji_events, dark),
                    style: TextStyle(color: dark ? Colors.white : Colors.black87),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: _input('Description', Icons.description, dark),
                    style: TextStyle(color: dark ? Colors.white : Colors.black87),
                    maxLines: 3,
                  ),

                  // Logo Card
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!dark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(color: dark ? Colors.white12 : Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 28,
                              width: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.image, color: AppColors.primary, size: 16),
                            ),
                            const SizedBox(width: 10),
                            const Text('Tournament Logo',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (_logoUrl != null && _logoUrl!.isNotEmpty)
                                  ? Image.network(
                                _logoUrl!,
                                height: 64,
                                width: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 64,
                                  width: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                                  : Container(
                                height: 64,
                                width: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.image_outlined),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_logoUrl != null && _logoUrl!.isNotEmpty)
                                  SizedBox(
                                    height: 36,
                                    child: TextButton.icon(
                                      onPressed: _uploadingLogo ? null : () => setState(() => _logoUrl = null),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Remove'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey.shade600,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999),
                                          side: BorderSide(color: Colors.grey.shade500, width: 1),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  height: 36,
                                  child: TextButton.icon(
                                    onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.gallery),
                                    icon: const Icon(Icons.photo, size: 18),
                                    label: const Text('Gallery'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 36,
                                  child: TextButton.icon(
                                    onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: const Text('Camera'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      backgroundColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                        side: BorderSide(color: AppColors.primary, width: 1),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                                if (_uploadingLogo)
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Schedule
                  _sectionTitle('Schedule', icon: Icons.calendar_month),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () => _pickDate(_startDateController),
                    decoration: _input('Start Date (YYYY-MM-DD)', Icons.date_range, dark),
                    style: TextStyle(color: dark ? Colors.white : Colors.black87),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  if (_isTrial) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _trialEndDateController,
                      readOnly: true,
                      onTap: () => _pickDate(_trialEndDateController),
                      decoration: _input('Trial End Date', Icons.date_range, dark),
                      style: TextStyle(color: dark ? Colors.white : Colors.black87),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _sectionTitle('Visibility & Limits', icon: Icons.tune),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Power-Play Overs:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _playersPerTeam,
                        items: List.generate(8, (i) => DropdownMenuItem(value: i, child: Text('$i'))),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  SwitchListTile(
                    title: const Text('Publicly Visible'),
                    value: _isOpen,
                    onChanged: (v) => setState(() => _isOpen = v),
                    tileColor: dark ? Colors.white12 : Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  SwitchListTile(
                    title: const Text('Trial Tournament'),
                    value: _isTrial,
                    onChanged: (v) => setState(() => _isTrial = v),
                    tileColor: dark ? Colors.white12 : Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maxAgeController,
                    keyboardType: TextInputType.number,
                    decoration: _input('Max Age (optional)', Icons.cake, dark),
                    style: TextStyle(color: dark ? Colors.white : Colors.black87),
                  ),

                  const SizedBox(height: 22),
                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitTournament,
                      icon: _isSubmitting
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isSubmitting ? 'Saving…' : 'Submit Tournament'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
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
