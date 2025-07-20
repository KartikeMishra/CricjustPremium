import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screen/login_screen.dart';
import '../theme/color.dart';

class AddTeamScreen extends StatefulWidget {
  const AddTeamScreen({super.key});

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
  int? _selectedTournamentId;
  int? _selectedGroupId;
  bool? _isGroupTournament;

  final List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _selectedPlayers = [];
  final Map<int, Map<String, dynamic>> _playerProfileCache = {};
  String _teamType = 'match'; // 'match' or 'tournament'

  String _selectedRole = 'All';
  String _selectedBatterType = 'All';

  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _groups = [];

  final List<String> _roleFilters = [
    'All',
    'Batter',
    'Bowler',
    'All-Rounder',
    'Wicket-Keeper',
  ];
  final List<String> _batterFilters = [
    'All',
    'Left Hand Batter',
    'Right Hand Batter',
  ];

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
      _fetchTournaments();
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
    final selected = _selectedPlayers.any(
      (x) => x['ID'].toString() == id.toString(),
    );
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
                    errorBuilder: (_, __, ___) => Image.asset(
                      'lib/asset/images/Random_Image.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'lib/asset/images/Random_Image.png',
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
            color: selected ? Colors.red : AppColors.primary,
          ),
          onPressed: () => _togglePlayer(p),
        ),
      ),
    );
  }

  Future<void> _fetchTournaments() async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-tournaments-for-create-match?api_logged_in_token=$_apiToken&limit=20&skip=0',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body);
        final List data = jsonBody['data'] ?? [];

        setState(() {
          _tournaments = List<Map<String, dynamic>>.from(
            data,
          ); // ← no filter here
        });
      } else {
        print('Tournament fetch failed: ${res.statusCode}');
      }
    } catch (e) {
      print('Tournament fetch error: $e');
    }
  }

  Future<void> _fetchGroups(int tournamentId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-groups?api_logged_in_token=$_apiToken&tournament_id=$tournamentId',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body);
        final List data = jsonBody['data'] ?? [];
        setState(() {
          _groups = List<Map<String, dynamic>>.from(data);
          _selectedGroupId = null;
        });
      }
    } catch (e) {
      print('Group fetch error: $e');
    }
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
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-players?api_logged_in_token=$_apiToken&limit=20&skip=$skip&search=$query',
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

        await Future.wait(
          data.map((p) async {
            final idRaw = p['ID'];
            final playerId = idRaw is int
                ? idRaw
                : int.tryParse(idRaw.toString()) ?? 0;
            if (playerId != 0 && !_playerProfileCache.containsKey(playerId)) {
              await fetchPlayerProfile(playerId);
            }
          }),
        );
      }
    } catch (e) {
      print('Search error: $e');
    }

    setState(() => _loadingSearch = false);
  }

  Future<void> fetchPlayerProfile(int playerId) async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-player-public-info?player_id=$playerId',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['status'] == 1 && body['player_info'] != null) {
          final playerInfo = body['player_info'];

          if (playerInfo['user_profile_image'] != null) {
            playerInfo['user_profile_image'] = playerInfo['user_profile_image']
                .toString()
                .replaceAll('&amp;', '&');
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
        _selectedPlayers.removeWhere(
          (x) => x['ID'].toString() == id.toString(),
        );
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
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
    if (_teamType == 'tournament') {
      if (_selectedTournamentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a tournament')),
        );
        return;
      }

      if (_isGroupTournament == true && _selectedGroupId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a group')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/add-team?api_logged_in_token=$_apiToken',
    );

    final body = {
      'team_name': _teamNameCtrl.text.trim(),
      'team_description': _descCtrl.text.trim(),
      'team_logo':
          'https://cricjust.in/wp-content/uploads/user_images/21611-1725762281.jpg',
      'tournament_id': _selectedTournamentId.toString(),
      'group_id': _selectedGroupId.toString(),
    };

    for (int i = 0; i < _selectedPlayers.length; i++) {
      body['team_players[$i]'] = _selectedPlayers[i]['ID'].toString();
    }

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
            _selectedTournamentId = null;
            _selectedGroupId = null;
            _groups.clear();
          });
        } else {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget buildGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          border: isDark ? Border.all(color: Colors.white24) : null,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.white24 : Colors.black26,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[100];
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final chipBgColor = isDark ? Colors.blueGrey.shade800 : Colors.blue.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: Theme.of(context).brightness == Brightness.dark
              ? const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                )
              : const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: true,
            title: const Text(
              'Add Team',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),

      body: _apiToken == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: cardColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Team Type Switch
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'match',
                                      groupValue: _teamType,
                                      onChanged: (val) {
                                        setState(() {
                                          _teamType = val!;
                                          _selectedTournamentId = null;
                                          _selectedGroupId = null;
                                          _isGroupTournament = false;
                                        });
                                      },
                                    ),
                                    const Text('Match Team'),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'tournament',
                                      groupValue: _teamType,
                                      onChanged: (val) {
                                        setState(() {
                                          _teamType = val!;
                                          _selectedTournamentId = null;
                                          _selectedGroupId = null;
                                          _isGroupTournament = false;
                                        });
                                      },
                                    ),
                                    const Text('Tournament Team'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Tournament & Group Dropdowns (if Tournament Team selected)
                            if (_teamType == 'tournament') ...[
                              DropdownButtonFormField<int>(
                                value: _selectedTournamentId,
                                decoration: _input(
                                  'Select Tournament',
                                  Icons.emoji_events,
                                ),
                                items: _tournaments.map((t) {
                                  final id = int.tryParse(
                                    t['tournament_id'].toString(),
                                  );
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Row(
                                      children: [
                                        if ((t['tournament_logo'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundImage: NetworkImage(
                                                t['tournament_logo'],
                                              ),
                                              backgroundColor: Colors.grey[300],
                                            ),
                                          ),
                                        Flexible(
                                          child: Text(
                                            t['tournament_name'] ?? 'Unnamed',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedTournamentId = val;
                                    _selectedGroupId = null;
                                    final selected = _tournaments.firstWhere(
                                      (t) =>
                                          t['tournament_id'].toString() ==
                                          val.toString(),
                                      orElse: () => {},
                                    );
                                    _isGroupTournament =
                                        selected['is_group'] == '1';
                                  });
                                  if (_isGroupTournament == true &&
                                      val != null) {
                                    _fetchGroups(val);
                                  }
                                },
                                selectedItemBuilder: (context) {
                                  return _tournaments.map((t) {
                                    return Text(
                                      t['tournament_name'] ?? 'Unnamed',
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  }).toList();
                                },
                              ),
                              const SizedBox(height: 14),

                              if (_isGroupTournament == true)
                                DropdownButtonFormField<int>(
                                  value: _selectedGroupId,
                                  decoration: _input(
                                    'Select Group',
                                    Icons.group_work,
                                  ),
                                  items: _groups.map((g) {
                                    final id = int.tryParse(
                                      g['group_id'].toString(),
                                    );
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text(g['group_name'] ?? 'Unnamed'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedGroupId = val);
                                  },
                                  validator: (val) {
                                    if (_isGroupTournament == true &&
                                        val == null) {
                                      return 'Please select a group';
                                    }
                                    return null;
                                  },
                                ),
                            ],

                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _teamNameCtrl,
                              decoration: _input('Team Name', Icons.group),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _descCtrl,
                              decoration: _input(
                                'Team Description',
                                Icons.description,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Filter Players',
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ..._roleFilters.map(
                            (role) => FilterChip(
                              label: Text(role),
                              selected: _selectedRole == role,
                              onSelected: (_) =>
                                  setState(() => _selectedRole = role),
                              backgroundColor: chipBgColor,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ..._batterFilters.map(
                            (type) => FilterChip(
                              label: Text(type),
                              selected: _selectedBatterType == type,
                              onSelected: (_) =>
                                  setState(() => _selectedBatterType = type),
                              backgroundColor: chipBgColor,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: _input(
                                'Search players...',
                                Icons.search,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: isDark ? 2 : 4,
                              shadowColor: isDark
                                  ? Colors.white24
                                  : Colors.black45,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isDark
                                    ? const BorderSide(color: Colors.white24)
                                    : BorderSide.none,
                              ),
                            ),
                            icon: _loadingSearch
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            onPressed: _loadingSearch
                                ? null
                                : () => _performSearch(reset: false),
                            label: _loadingSearch
                                ? const Text("Loading...")
                                : const Text(
                                    "Load More",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _loadingSearch && _searchResults.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) =>
                                  _buildPlayerCard(_searchResults[index]),
                            ),
                      const Divider(height: 30, thickness: 1.2),
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
                        children: _selectedPlayers.map((p) {
                          final name = p['display_name'] ?? '';
                          return Chip(
                            label: Text(name),
                            onDeleted: () => _togglePlayer(p),
                            backgroundColor: chipBgColor,
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      buildGlassButton(
                        label: 'Save Team',
                        icon: Icons.save,
                        onPressed: _isSubmitting ? () {} : _confirmAndSave,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
