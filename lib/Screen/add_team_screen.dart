import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screen/login_screen.dart';

class AddTeamScreen extends StatefulWidget {
  const AddTeamScreen({Key? key}) : super(key: key);

  @override
  _AddTeamScreenState createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends State<AddTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _loadingSearch = false;
  int _currentPage = 0;
  Timer? _debounce;
  String? _apiToken;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedPlayers = [];
  final Map<int, Map<String, dynamic>> _playerProfileCache = {};

  String _selectedRole = 'All';
  String _selectedBatterType = 'All';

  final List<String> _roleFilters = [
    'All', 'Batter', 'Bowler', 'All-Rounder', 'Wicket-Keeper'
  ];
  final List<String> _batterFilters = [
    'All', 'Left Hand Batter', 'Right Hand Batter'
  ];

  @override
  void initState() {
    super.initState();
    _checkLogin();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _teamNameCtrl.dispose();
    _descCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => _apiToken = token);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = _searchCtrl.text.trim();
      if (q.isNotEmpty) {
        _performSearch(reset: true);
      } else {
        setState(() => _searchResults.clear());
      }
    });
  }

  Future<void> _performSearch({bool reset = false}) async {
    if (_apiToken == null || _loadingSearch) return;
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      if (reset) {
        _currentPage = 0;
        _searchResults.clear();
        _playerProfileCache.clear();
      }
      _loadingSearch = true;
    });

    final skip = _currentPage * 20;
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-players'
          '?api_logged_in_token=$_apiToken&limit=20&skip=$skip&search=$query',
    );

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final List data = body['data'] ?? [];
        setState(() {
          _searchResults.addAll(List<Map<String, dynamic>>.from(data));
          _currentPage++;
        });

        await Future.wait(data.map((p) async {
          final idRaw = p['ID'];
          final playerId = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;
          if (playerId != 0 && !_playerProfileCache.containsKey(playerId)) {
            await fetchPlayerProfile(playerId);
          }
        }));
      }
    } catch (e) {
      print('Search error: $e');
    }

    setState(() => _loadingSearch = false);
  }

  Future<void> fetchPlayerProfile(int playerId) async {
    final url = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-player-public-info?player_id=$playerId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['status'] == 1 && body['player_info'] != null) {
          final playerInfo = body['player_info'];

          if (playerInfo['user_profile_image'] != null) {
            playerInfo['user_profile_image'] =
                playerInfo['user_profile_image'].toString().replaceAll('&amp;', '&');
          }

          if (playerInfo['teams'] is List) {
            for (var team in playerInfo['teams']) {
              if (team['team_name'] != null) {
                team['team_name'] = team['team_name'].toString().trim();
              }
            }
          }

          setState(() {
            _playerProfileCache[playerId] = playerInfo;
          });
        }
      }
    } catch (e) {
      print('Profile fetch error for $playerId: $e');
    }
  }

  void _togglePlayer(Map<String, dynamic> p) {
    final id = p['ID'] is int ? p['ID'] : int.tryParse(p['ID'].toString()) ?? 0;
    setState(() {
      if (_selectedPlayers.any((x) => x['ID'].toString() == id.toString())) {
        _selectedPlayers.removeWhere((x) => x['ID'].toString() == id.toString());
      } else {
        _selectedPlayers.add(p);
      }
    });
  }

  Future<void> _confirmAndSave() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Save'),
        content: const Text('Are you sure you want to save this team?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text('Yes, Save'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      await saveTeam();
    }
  }

  Future<void> saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one player')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final url = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/add-team?api_logged_in_token=$_apiToken');

    final body = {
      'team_name': _teamNameCtrl.text.trim(),
      'team_description': _descCtrl.text.trim(),
      'team_logo': 'https://cricjust.in/wp-content/uploads/user_images/21611-1725762281.jpg',
    };

    for (int i = 0; i < _selectedPlayers.length; i++) {
      body['team_players[$i]'] = _selectedPlayers[i]['ID'].toString();
    }
    ;

    try {
      final response = await http.post(url, body: body);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team added successfully')),
          );
          setState(() {
                _teamNameCtrl.clear();
                _descCtrl.clear();
                _searchCtrl.clear();
                _searchResults.clear();
                _selectedPlayers.clear();
                _playerProfileCache.clear();
                _currentPage = 0;
              });
            }
         else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to add team')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPlayerCard(Map<String, dynamic> p) {
    final idRaw = p['ID'];
    final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;
    final profile = _playerProfileCache[id];

    if (_selectedRole != 'All') {
      final type = (profile?['player_type'] ?? '').toString().toLowerCase();
      if (type != _selectedRole.toLowerCase()) return const SizedBox.shrink();
    }

    if (_selectedBatterType != 'All' && profile != null) {
      final bType = (profile['batter_type'] ?? '').toString().toLowerCase();
      if (!_selectedBatterType.toLowerCase().contains(bType)) {
        return const SizedBox.shrink();
      }
    }

    final name = p['display_name'] ?? '';
    final login = p['user_login'] ?? '';
    final selected = _selectedPlayers.any((x) => x['ID'].toString() == id.toString());
    final imageUrl = profile?['user_profile_image'];
    final playerType = profile?['player_type'] ?? 'Fetching...';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: null,
          child: ClipOval(
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'lib/asset/images/Random_Image.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                );
              },
            )
                : Image.asset(
              'lib/asset/images/Random_Image.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(login),
            Text(playerType),
            if (profile?['batter_type'] != null) Text(profile!['batter_type']),
            if (profile?['bowler_type'] != null) Text(profile!['bowler_type']),
            if (profile?['teams'] != null)
              Text(
                (profile!['teams'] as List)
                    .map((t) => t['team_name'].toString())
                    .join(', '),
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(
            selected ? Icons.remove_circle : Icons.add_circle,
            color: selected ? Colors.red : Colors.blue,
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
        title: const Text('Add Team'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _teamNameCtrl,
                    decoration: const InputDecoration(labelText: 'Team Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Team Description'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ..._roleFilters.map((role) => FilterChip(
                  label: Text(role),
                  selected: _selectedRole == role,
                  onSelected: (_) {
                    setState(() => _selectedRole = role);
                  },
                )),
                const SizedBox(width: 16),
                ..._batterFilters.map((type) => FilterChip(
                  label: Text(type),
                  selected: _selectedBatterType == type,
                  onSelected: (_) {
                    setState(() => _selectedBatterType = type);
                  },
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search players...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  icon: const Icon(Icons.download),
                  onPressed: _loadingSearch ? null : () => _performSearch(reset: false),
                  label: _loadingSearch
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Load More'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loadingSearch && _searchResults.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) => _buildPlayerCard(_searchResults[index]),
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selected Players (${_selectedPlayers.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _selectedPlayers.map((p) {
                final name = p['display_name'] ?? '';
                return Chip(
                  label: Text(name),
                  onDeleted: () => _togglePlayer(p),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                icon: const Icon(Icons.save),
                onPressed: _isSubmitting ? null : _confirmAndSave,
                label: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Save Team'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
