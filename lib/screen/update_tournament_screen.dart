// lib/screen/update_tournament_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../model/tournament_model.dart';
import '../service/user_image_service.dart';
import '../theme/color.dart';
import 'login_screen.dart';

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
  late TextEditingController _logoController; // holds full URL after upload
  late TextEditingController _startDateController;
  late TextEditingController _trialEndController;
  late TextEditingController _maxAgeController;
  late TextEditingController _ppController;

  bool _isGroup = false;
  bool _isOpen = false;
  bool _isTrial = false;

  bool _isSubmitting = false;
  bool _uploadingLogo = false;

  String _apiToken = '';

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.tournament.tournamentName);
    _descController = TextEditingController(text: widget.tournament.tournamentDesc);
    _logoController = TextEditingController(text: widget.tournament.tournamentLogo);
    _startDateController = TextEditingController(text: widget.tournament.startDate);

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
    if (_apiToken.isEmpty && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // ---------- STYLES ----------
  ButtonStyle _pillBtn(Color bg, {bool outlined = false}) {
    final fg = outlined ? bg : Colors.white;
    return TextButton.styleFrom(
      foregroundColor: fg,
      backgroundColor: outlined ? Colors.transparent : bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: outlined ? BorderSide(color: bg, width: 1) : BorderSide.none,
      ),
      visualDensity: VisualDensity.compact,
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

  InputDecoration _beautyInput(String label, IconData icon, bool dark) {
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

  // ---------- HELPERS ----------
  Future<void> _pickDate(TextEditingController ctrl, {bool includeTime = false}) async {
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
      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      ctrl.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    }
  }

  Future<void> _pickAndUploadLogo(ImageSource source) async {
    if (_apiToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _apiToken = prefs.getString('api_logged_in_token') ?? '';
      if (_apiToken.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }
    }

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 900,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final lower = picked.path.toLowerCase();

    final sizeMB = (await file.length()) / (1024 * 1024);
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only JPG and PNG images are allowed')));
      return;
    }
    if (sizeMB > 2.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be under 2 MB')));
      return;
    }

    setState(() => _uploadingLogo = true);
    try {
      final url = await UserImageService.uploadAndGetUrl(
        token: _apiToken,
        file: file,
        postTimeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      _logoController.text = url;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo uploaded')));
      setState(() {}); // refresh preview
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadingLogo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please wait for logo upload to finish')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_apiToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _apiToken = prefs.getString('api_logged_in_token') ?? '';
        if (_apiToken.isEmpty) {
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          return;
        }
      }

      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/update-tournament'
            '?api_logged_in_token=$_apiToken&tournament_id=${widget.tournament.tournamentId}',
      );

      final body = {
        'tournament_name': _nameController.text.trim(),
        'tournament_desc': _descController.text.trim(),
        'tournament_logo': _logoController.text.trim(), // URL
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

      // Invalid token → force login
      if (response.statusCode == 200 &&
          data is Map &&
          data['status'] == 0 &&
          data['message'] != null &&
          data['message'].toString().toLowerCase().contains('invalid api logged in token')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_logged_in_token');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        return;
      }

      if (response.statusCode == 200 && data['status'] == 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournament updated successfully')));
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Update failed')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('Update Tournament',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: isDark ? Colors.grey[850] : Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('Basics', icon: Icons.info_outline),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _nameController,
                    decoration: _beautyInput('Tournament Name', Icons.emoji_events, isDark),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: _beautyInput('Description', Icons.description, isDark),
                    maxLines: 3,
                  ),

                  // --- Logo Card ---
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Tournament Logo', icon: Icons.image),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (_logoController.text.isNotEmpty)
                                  ? Image.network(
                                _logoController.text,
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
                            // Controls
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_logoController.text.isNotEmpty)
                                  SizedBox(
                                    height: 36,
                                    child: TextButton.icon(
                                      onPressed: _uploadingLogo ? null : () => setState(() => _logoController.text = ''),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Remove'),
                                      style: _pillBtn(Colors.grey.shade500, outlined: true),
                                    ),
                                  ),
                                SizedBox(
                                  height: 36,
                                  child: TextButton.icon(
                                    onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.gallery),
                                    icon: const Icon(Icons.photo, size: 18),
                                    label: const Text('Gallery'),
                                    style: _pillBtn(AppColors.primary),
                                  ),
                                ),
                                SizedBox(
                                  height: 36,
                                  child: TextButton.icon(
                                    onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: const Text('Camera'),
                                    style: _pillBtn(AppColors.primary, outlined: true),
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

                  _sectionTitle('Visibility & Format', icon: Icons.tune),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Enable Group Stage'),
                    value: _isGroup,
                    onChanged: (v) => setState(() => _isGroup = v),
                    tileColor: isDark ? Colors.white10 : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  SwitchListTile(
                    title: const Text('Enable Trial'),
                    value: _isTrial,
                    onChanged: (v) => setState(() => _isTrial = v),
                    tileColor: isDark ? Colors.white10 : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  SwitchListTile(
                    title: const Text('Publicly Visible'),
                    value: _isOpen,
                    onChanged: (v) => setState(() => _isOpen = v),
                    tileColor: isDark ? Colors.white10 : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),

                  const SizedBox(height: 6),
                  _sectionTitle('Schedule', icon: Icons.calendar_month),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () => _pickDate(_startDateController),
                    decoration: _beautyInput('Start Date (YYYY-MM-DD)', Icons.date_range, isDark),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _trialEndController,
                    readOnly: true,
                    onTap: () => _pickDate(_trialEndController, includeTime: true),
                    decoration: _beautyInput('Trial End Date (YYYY-MM-DD HH:mm:ss)', Icons.schedule, isDark),
                  ),

                  const SizedBox(height: 6),
                  _sectionTitle('Limits', icon: Icons.rule),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _maxAgeController,
                    decoration: _beautyInput('Max Age (optional)', Icons.numbers, isDark),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ppController,
                    decoration: _beautyInput('Players Per Team (pp)', Icons.people, isDark),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isSubmitting || _uploadingLogo) ? null : _submitUpdate,
                      icon: _isSubmitting
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isSubmitting ? 'Saving…' : 'Update Tournament'),
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
