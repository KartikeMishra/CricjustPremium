// Full working Add Match Screen with dynamic team refresh on tournament selection

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class AddMatchScreen extends StatefulWidget {
  const AddMatchScreen({super.key});

  @override
  State<AddMatchScreen> createState() => _AddMatchScreenState();
}

class _AddMatchScreenState extends State<AddMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};

  String? _token;
  bool _isLoading = false;
  bool _isTournamentMatch = false;
  int? _selectedMatchType;

  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _playersTeam1 = [];
  List<Map<String, dynamic>> _playersTeam2 = [];
  List<Map<String, dynamic>> _venues = [];
  List<Map<String, dynamic>> _selectedPlayersTeam1 = [];
  List<Map<String, dynamic>> _selectedPlayersTeam2 = [];

  Map<String, dynamic>? _selectedTournament;
  Map<String, dynamic>? _selectedTeam1;
  Map<String, dynamic>? _selectedTeam2;
  Map<String, dynamic>? _selectedVenue;
  String? _selectedBallType;

  final List<String> _ballTypes = ['Leather', 'Tennis', 'Other'];

  @override
  void initState() {
    super.initState();
    for (var key in ['match_name', 'team_one_cap', 'team_one_wktkpr', 'team_two_cap', 'team_two_wktkpr', 'match_date', 'match_time', 'match_overs', 'ballers_max_overs', 'umpires']) {
      _controllers[key] = TextEditingController();
    }
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      setState(() => _token = token);
      await _fetchTournaments();
      await _fetchVenues();
    }
  }

  Future<void> _fetchTournaments() async {
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-tournaments?type=all');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() => _tournaments = List<Map<String, dynamic>>.from(data['data']));
    }
  }

  Future<void> _fetchTeams(int tournamentId) async {
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-teams?tournament_id=$tournamentId&api_logged_in_token=$_token');
    debugPrint('📥 Fetching Teams API');
    debugPrint('📌 URL: $url');
    debugPrint('📤 tournament_id: $tournamentId');
    debugPrint('📤 api_logged_in_token: $_token');
    final res = await http.get(url);
    debugPrint('📦 Response Status: ${res.statusCode}');
    debugPrint('📦 Response Body: ${res.body}');
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['status'] == 1 && data['data'] != null) {
        setState(() => _teams = List<Map<String, dynamic>>.from(data['data']));
      }
    }
  }

  Future<void> _fetchPlayers(int teamId, bool isTeam1) async {
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-players?team_id=$teamId&api_logged_in_token=$_token');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final players = List<Map<String, dynamic>>.from(data['data']);
      setState(() {
        if (isTeam1) {
          _playersTeam1 = players;
          _selectedPlayersTeam1.clear();
        } else {
          _playersTeam2 = players;
          _selectedPlayersTeam2.clear();
        }
      });
    }
  }

  Future<void> _fetchVenues() async {
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-venue?type=all&api_logged_in_token=$_token');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() => _venues = List<Map<String, dynamic>>.from(data['data']));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (picked != null) _controllers['match_date']!.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) _controllers['match_time']!.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _submitMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlayersTeam1.length != 11 || _selectedPlayersTeam2.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select exactly 11 players for both teams")));
      return;
    }

    final body = {
      'match_name': _controllers['match_name']!.text.trim(),
      'team_one': _selectedTeam1?['team_id'].toString() ?? '',
      'team_one_11': _selectedPlayersTeam1.map((e) => e['id']).join(','),
      'team_one_cap': _controllers['team_one_cap']!.text.trim(),
      'team_one_wktkpr': _controllers['team_one_wktkpr']!.text.trim(),
      'team_two': _selectedTeam2?['team_id'].toString() ?? '',
      'team_two_11': _selectedPlayersTeam2.map((e) => e['id']).join(','),
      'team_two_cap': _controllers['team_two_cap']!.text.trim(),
      'team_two_wktkpr': _controllers['team_two_wktkpr']!.text.trim(),
      'match_date': _controllers['match_date']!.text.trim(),
      'match_time': _controllers['match_time']!.text.trim(),
      'ball_type': _selectedBallType ?? '',
      'match_overs': _controllers['match_overs']!.text.trim(),
      'venue': _selectedVenue?['venue_id'].toString() ?? '',
    };

    if (_selectedTournament != null) {
      body['tournament_id'] = _selectedTournament!['tournament_id'].toString();
      body['tournament_match_type'] = _selectedMatchType?.toString() ?? '0';
    }
    if (_controllers['ballers_max_overs']!.text.isNotEmpty) body['ballers_max_overs'] = _controllers['ballers_max_overs']!.text.trim();
    if (_controllers['umpires']!.text.isNotEmpty) body['umpires'] = _controllers['umpires']!.text.trim();

    setState(() => _isLoading = true);
    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/add-cricket-match?api_logged_in_token=$_token');
    final res = await http.post(url, body: body);
    final jsonRes = json.decode(res.body);
    setState(() => _isLoading = false);

    if (jsonRes['status'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Match created successfully")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed: ${jsonRes['message'] ?? 'Unknown error'}")));
    }
  }

  Widget _buildDropdown<T>(String label, T? value, List<DropdownMenuItem<T>> items, void Function(T?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
    );
  }

  Widget _buildTextField(String key, String label, {bool required = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: required ? (val) => val == null || val.trim().isEmpty ? 'Required' : null : null,
      ),
    );
  }

  Widget _buildPlayerMultiSelect(String label, List<Map<String, dynamic>> players, List<Map<String, dynamic>> selectedPlayers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 6,
          children: selectedPlayers
              .map((p) => Chip(
            label: Text(p['display_name']),
            onDeleted: () => setState(() => selectedPlayers.remove(p)),
          ))
              .toList(),
        ),
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (textEditingValue) => players
              .where((p) => p['display_name'].toLowerCase().contains(textEditingValue.text.toLowerCase()) && !selectedPlayers.contains(p))
              .toList(),
          displayStringForOption: (option) => option['display_name'],
          onSelected: (player) => setState(() {
            if (selectedPlayers.length < 11) selectedPlayers.add(player);
          }),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: "Add Player", border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Match'), backgroundColor: Colors.blue),
      body: _token == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildDropdown<int>('Select Tournament', _selectedTournament?['tournament_id'], _tournaments.map<DropdownMenuItem<int>>((t) => DropdownMenuItem<int>(value: t['tournament_id'] as int, child: Text(t['tournament_name']))).toList(), (val) {
                final selected = _tournaments.firstWhere((t) => t['tournament_id'] == val);
                setState(() => _selectedTournament = selected);
                _fetchTeams(val!);
              }),
              if (_selectedTournament != null)
                _buildDropdown<int>('Match Type', _selectedMatchType, const [
                  DropdownMenuItem(value: 0, child: Text("Staging")),
                  DropdownMenuItem(value: 1, child: Text("Semifinal")),
                  DropdownMenuItem(value: 2, child: Text("Final")),
                  DropdownMenuItem(value: 3, child: Text("Qualifier")),
                  DropdownMenuItem(value: 4, child: Text("Eliminator")),
                ], (val) => setState(() => _selectedMatchType = val)),

              _buildDropdown<int>('Team One', _selectedTeam1?['team_id'], _teams.map((t) => DropdownMenuItem<int>(value: t['team_id'], child: Text(t['team_name']))).toList(), (val) {
                final selected = _teams.firstWhere((team) => team['team_id'] == val);
                setState(() => _selectedTeam1 = selected);
                _fetchPlayers(val!, true);
              }),
              _buildPlayerMultiSelect('Team One Players (11)', _playersTeam1, _selectedPlayersTeam1),
              _buildTextField('team_one_cap', 'Team One Captain ID', required: true),
              _buildTextField('team_one_wktkpr', 'Team One WK ID', required: true),

              _buildDropdown<int>('Team Two', _selectedTeam2?['team_id'], _teams.map((t) => DropdownMenuItem<int>(value: t['team_id'], child: Text(t['team_name']))).toList(), (val) {
                final selected = _teams.firstWhere((team) => team['team_id'] == val);
                setState(() => _selectedTeam2 = selected);
                _fetchPlayers(val!, false);
              }),
              _buildPlayerMultiSelect('Team Two Players (11)', _playersTeam2, _selectedPlayersTeam2),
              _buildTextField('team_two_cap', 'Team Two Captain ID', required: true),
              _buildTextField('team_two_wktkpr', 'Team Two WK ID', required: true),

              _buildTextField('match_name', 'Match Name', required: true),
              _buildTextField('match_date', 'Match Date', required: true, readOnly: true, onTap: _pickDate),
              _buildTextField('match_time', 'Match Time', required: true, readOnly: true, onTap: _pickTime),
              _buildDropdown<String>('Ball Type', _selectedBallType, _ballTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), (val) => setState(() => _selectedBallType = val)),
              _buildTextField('match_overs', 'Match Overs', required: true),
              _buildTextField('ballers_max_overs', 'Max Overs per Bowler'),
              _buildTextField('umpires', 'Umpires (comma-separated IDs)'),
              _buildDropdown<int>('Venue', _selectedVenue?['venue_id'], _venues.map<DropdownMenuItem<int>>((v) => DropdownMenuItem<int>(value: v['venue_id'] as int, child: Text(v['venue_name']))).toList(), (val) {
                final selected = _venues.firstWhere((v) => v['venue_id'] == val);
                setState(() => _selectedVenue = selected);
              }),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitMatch,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Match"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}