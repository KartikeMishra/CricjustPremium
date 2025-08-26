// lib/screen/update_team_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';            // ← NEW
import 'package:shared_preferences/shared_preferences.dart';

import '../service/team_service.dart';
import '../service/player_service.dart';
import '../service/user_image_service.dart';               // ← NEW
import '../theme/color.dart';

class UpdateTeamScreen extends StatefulWidget {
  final int teamId;
  const UpdateTeamScreen({super.key, required this.teamId});

  @override
  _UpdateTeamScreenState createState() => _UpdateTeamScreenState();
}

class _UpdateTeamScreenState extends State<UpdateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadingSearch = false;
  bool _submitting = false;
  int _currentPage = 0;
  Timer? _debounce;

  final List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedPlayers = [];

  // ▼▼ NEW: logo URL (server wants a URL string) + spinner
  String? _logoUrl;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
    _searchCtrl.addListener(_onSearchChanged);
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
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _originCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';

    final team = await TeamService.fetchTeamDetail(
      teamId: widget.teamId,
      apiToken: token,
    );

    if (team != null) {
      _nameCtrl.text = team.teamName;
      _descCtrl.text = team.teamDescription;
      _originCtrl.text = team.teamOrigin;

      // NEW: prefill existing logo if present
      if ((team.teamLogo).toString().isNotEmpty) {
        _logoUrl = team.teamLogo;
      }

      _selectedPlayers = await PlayerService.fetchTeamPlayers(
        teamId: widget.teamId,
        apiToken: token,
      );
    }

    setState(() => _loading = false);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = _searchCtrl.text.trim();
      if (q.isEmpty) {
        setState(() => _searchResults.clear());
      } else {
        _performSearch(reset: true);
      }
    });
  }

  Future<void> _performSearch({bool reset = false}) async {
    if (_loadingSearch) return;
    if (reset) {
      _currentPage = 0;
      _searchResults.clear();
    }
    setState(() => _loadingSearch = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    final skip = _currentPage * 20;

    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-players'
          '?api_logged_in_token=$token'
          '&limit=20'
          '&skip=$skip'
          '&search=${Uri.encodeQueryComponent(_searchCtrl.text.trim())}',
    );

    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final List data = body['data'] ?? [];
        setState(() {
          _searchResults.addAll(List<Map<String, dynamic>>.from(data));
          _currentPage++;
        });
      }
    } catch (_) {}

    setState(() => _loadingSearch = false);
  }

  void _togglePlayer(Map<String, dynamic> p) {
    final idRaw = p['ID'] ?? p['id'];
    final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;
    setState(() {
      final exists = _selectedPlayers.any(
            (x) => x['ID'].toString() == id.toString(),
      );
      if (exists) {
        _selectedPlayers.removeWhere(
              (x) => x['ID'].toString() == id.toString(),
        );
      } else {
        _selectedPlayers.add(p);
      }
    });
  }

  // ▼▼ NEW: pick + upload logo (returns a URL stored in _logoUrl)
  Future<void> _pickAndUploadLogo(ImageSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75, // compress
      maxWidth: 1000,   // resize
    );
    if (picked == null) return;

    final file = File(picked.path);
    final lower = picked.path.toLowerCase();

    // light validation (same as other screens)
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPG/PNG allowed')),
      );
      return;
    }
    final sizeMB = (await file.length()) / (1024 * 1024);
    if (sizeMB > 2.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be under 2 MB')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo uploaded ✔️')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one player')),
      );
      return;
    }

    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';

    final playerIds = _selectedPlayers
        .map((p) => p['ID'] is int ? p['ID'] : int.tryParse(p['ID'].toString()))
        .whereType<int>()
        .toList();

    final ok = await TeamService.updateTeam(
      teamId: widget.teamId,
      apiToken: token,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      origin: _originCtrl.text.trim(),
      playerIds: playerIds,
      // ▼▼ NEW: send only if we have a value
      logoUrl: (_logoUrl != null && _logoUrl!.trim().isNotEmpty) ? _logoUrl : null,
    );

    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Team updated!' : 'Update failed')),
    );
    if (ok) Navigator.pop(context, true);
  }

  Widget _buildPlayerCard(Map<String, dynamic> p) {
    final idRaw = p['ID'] ?? p['id'];
    final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;
    final name = p['display_name'] ?? p['user_login'] ?? 'Player $id';
    final selected = _selectedPlayers.any(
          (x) => x['ID'].toString() == id.toString(),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(name),
        trailing: IconButton(
          icon: Icon(
            selected ? Icons.remove_circle : Icons.add_circle,
            color: selected ? Colors.red : AppColors.primary,
          ),
          onPressed: () => _togglePlayer(p),
        ),
      ),
    );
  }

  // ▼▼ Small, self-contained UI block for the logo (kept simple)
  Widget _logoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Team Logo', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (_logoUrl != null && _logoUrl!.isNotEmpty)
                  ? Image.network(
                _logoUrl!,
                height: 60, width: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 60, width: 60,
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image),
                ),
              )
                  : Container(
                height: 60, width: 60,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(width: 12),
            if (_logoUrl != null && _logoUrl!.isNotEmpty)
              IconButton(
                tooltip: 'Remove',
                onPressed: _uploadingLogo ? null : () => setState(() => _logoUrl = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text('Gallery'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _uploadingLogo ? null : () => _pickAndUploadLogo(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 12),
            if (_uploadingLogo)
              const SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Team', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ▼▼ NEW: Logo picker (everything else below is unchanged)
                _logoPicker(),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _input('Team Name', Icons.group),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: _input(
                          'Description',
                          Icons.description,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _originCtrl,
                        decoration: _input('Origin', Icons.location_pin),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search players...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _loadingSearch
                        ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _loadingSearch && _searchResults.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) => _buildPlayerCard(_searchResults[i]),
                ),

                const SizedBox(height: 16),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selected Players (${_selectedPlayers.length})',
                    style: Theme.of(context).textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedPlayers
                      .map(
                        (p) => Chip(
                      label: Text(
                        p['display_name'] ??
                            p['user_login'] ??
                            'Player ${p['ID']}',
                      ),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => _togglePlayer(p),
                      backgroundColor: Colors.blue.shade50,
                    ),
                  )
                      .toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: _submitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Update Team'),
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
