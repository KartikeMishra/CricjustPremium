// lib/screen/update_team_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../service/team_service.dart';
import '../service/player_service.dart';
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
                      SizedBox(
                        height: 300,
                        child: _loadingSearch && _searchResults.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (ctx, i) =>
                                    _buildPlayerCard(_searchResults[i]),
                              ),
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
