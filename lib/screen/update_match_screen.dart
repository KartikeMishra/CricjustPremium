import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/tournament_model.dart';
import '../service/player_service.dart';
import '../service/team_service.dart';
import '../service/tournament_service.dart';
import '../service/venue_service.dart';
import '../theme/color.dart';
import '../utils/net.dart';
import 'login_screen.dart';

class UpdateMatchScreen extends StatefulWidget {
  final int matchId;
  const UpdateMatchScreen({super.key, required this.matchId});

  @override
  State<UpdateMatchScreen> createState() => _UpdateMatchScreenState();
}

class _UpdateMatchScreenState extends State<UpdateMatchScreen> {
  // Match fields
  String? _matchType;
  String? _matchName;
  String? _ballType;
  String? _matchOvers;
  String? _maxOversPerBowler;

  // Tournament
  List<Map<String, dynamic>> _tournaments = [];
  int? _selectedTournamentId;
  int? _selectedTournamentMatchType;
  final Map<int, String> _tournamentMatchTypes = {
    0: 'Staging Match',
    1: 'Semifinal',
    2: 'Final',
    3: 'Qualifier',
    4: 'Eliminator',
  };

  // Teams
  final List<Map<String, dynamic>> _teams = [];
  int? _selectedTeamAId, _selectedTeamBId;
  String? _selectedTeamAName, _selectedTeamBName;

  // Players
  List<Map<String, dynamic>> _teamAPlayers = [], _teamBPlayers = [];
  List<int> _selectedTeamAPlayers = [], _selectedTeamBPlayers = [];
  int? _teamACaptainId,
      _teamAWicketKeeperId,
      _teamBCaptainId,
      _teamBWicketKeeperId;

  // Umpires
  List<Map<String, dynamic>> _umpires = [];
  List<int> _selectedUmpires = [];

  // Venue
  final List<Map<String, dynamic>> _venues = [];
  Map<String, dynamic>? _selectedVenue;

  // Date & Time
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Pagination
  static const int teamPageLimit = 20;
  static const int venuePageLimit = 20;
  int _teamSkip = 0, _venueSkip = 0;
  bool _isLoadingMoreTeams = false, _hasMoreTeams = true;
  bool _isLoadingMoreVenues = false, _hasMoreVenues = true;

  // State
  bool _isLoading = true;
  bool _isSaving = false;
  String? _apiToken;

  final ScrollController _teamScrollController = ScrollController();
  final ScrollController _venueScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_logged_in_token');
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      _apiToken = token;

      await _loadUmpires();
      await _fetchTournaments();
      await _fetchVenues(reset: true);
      await _fetchMatchDetails();
    } catch (e, s) {
      debugPrint('Initialize failed: $e\n$s');
      _showError('Could not load match. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _fetchMatchDetails() async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-cricket-match'
          '?api_logged_in_token=$_apiToken&match_id=${widget.matchId}',
    );

    try {
      final response = await Net.get(uri);
      if (response.statusCode != 200) {
        _showError('Server error ${response.statusCode}. Please try again.');
        return;
      }

      Map<String, dynamic> body;
      try {
        body = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        _showError('Invalid response from server.');
        return;
      }

      if ((body['status'] as int? ?? 0) != 1) {
        final msg = (body['message'] ?? body['error'] ?? 'Failed to load match').toString();
        _showError(msg);
        return;
      }

      final rawList = (body['data'] as List?) ?? const [];
      if (rawList.isEmpty) {
        _showError('No match found for #${widget.matchId}.');
        return;
      }

      final data = Map<String, dynamic>.from(rawList.first as Map);

      if (!mounted) return;
      setState(() {
        _matchName = data['match_name'] as String? ?? '';
        _matchType = (data['tournament_id'] as int? ?? 0) > 0 ? 'tournament' : 'one_to_one';

        if (_matchType == 'tournament') {
          _selectedTournamentId = data['tournament_id'] as int?;
          _selectedTournamentMatchType = data['tournament_match_type'] as int?;
        }

        _selectedTeamAId = data['team_one'] as int?;
        _selectedTeamBId = data['team_two'] as int?;
        _selectedTeamAName = data['team_one_name'] as String?;
        _selectedTeamBName = data['team_two_name'] as String?;

        _selectedTeamAPlayers = (data['team_one_11'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList();
        _selectedTeamBPlayers = (data['team_two_11'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList();

        _teamACaptainId = data['team_one_cap'] as int?;
        _teamAWicketKeeperId = data['team_one_wktkpr'] as int?;
        _teamBCaptainId = data['team_two_cap'] as int?;
        _teamBWicketKeeperId = data['team_two_wktkpr'] as int?;

        final venueId = data['venue'] as int?;
        if (venueId != null) {
          _selectedVenue = _venues.firstWhere(
                (v) => v['venue_id'] == venueId,
            orElse: () => {'venue_id': venueId, 'venue_name': 'ID $venueId'},
          );
        }

        _selectedDate = DateTime.tryParse(data['match_date'] as String? ?? '');
        final tm = (data['match_time'] as String? ?? '00:00:00').split(':');
        _selectedTime = TimeOfDay(
          hour: int.tryParse(tm[0]) ?? 0,
          minute: int.tryParse(tm[1]) ?? 0,
        );

        _ballType = data['ball_type'] as String?;
        _matchOvers = (data['match_overs'] as dynamic)?.toString();
        _maxOversPerBowler = (data['ballers_max_overs'] as dynamic)?.toString();

        _selectedUmpires = (data['umpires'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => int.tryParse(s) ?? 0)
            .where((i) => i != 0)
            .toList();
      });

      if (_selectedTeamAId != null) {
        await _fetchPlayers(teamId: _selectedTeamAId!, isTeamA: true);
      }
      if (_selectedTeamBId != null) {
        await _fetchPlayers(teamId: _selectedTeamBId!, isTeamA: false);
      }
    } on SocketException {
      _showError('Network error. Check your internet and try again.');
    } on TimeoutException {
      _showError('Request timed out. Please try again.');
    } on http.ClientException {
      _showError('Server dropped the connection. Please try again.');
    } catch (e, s) {
      debugPrint('fetchMatchDetails error: $e\n$s');
      _showError('Something went wrong while loading the match.');
    }
  }


  Future<void> _loadUmpires() async {
    final result = await TeamService.fetchUmpires(apiToken: _apiToken!);
    setState(() => _umpires = result);
  }

  Future<void> _showUmpireSelector() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Select Umpires',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _umpires.length,
                    itemBuilder: (_, i) {
                      final ump = _umpires[i];
                      final id = int.parse(ump['id'].toString());
                      final selected = _selectedUmpires.contains(id);
                      return ListTile(
                        title: Text(
                          ump['display_name'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        tileColor: selected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : null,
                        trailing: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected ? AppColors.primary : Colors.grey,
                        ),
                        onTap: () {
                          setModalState(() {
                            if (selected) {
                              _selectedUmpires.remove(id);
                            } else {
                              _selectedUmpires.add(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
// -------------------------
// Fetch tournaments (Frontend + Update match usage)
// -------------------------
  static Future<List<TournamentModel>> fetchTournaments({
    String? apiToken,
    String? type, // "recent", "live", or "upcoming"
    int? limit,
    int? skip,
  }) async {
    final Map<String, String> params = {};
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (limit != null) params['limit'] = limit.toString();
    if (skip != null) params['skip'] = skip.toString();

    Uri uri;

    // ✅ Use correct endpoint based on token presence
    if (apiToken != null && apiToken.isNotEmpty) {
      // User-specific tournaments (for logged-in users)
      uri = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-tournament')
          .replace(queryParameters: {
        'api_logged_in_token': apiToken,
        if (limit != null) 'limit': limit.toString(),
        if (skip != null) 'skip': skip.toString(),
      });
    } else {
      // Public frontend tournaments (recent/live/upcoming)
      uri = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/get-tournaments')
          .replace(queryParameters: params);
    }

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = json.decode(response.body);
      if (body['status'] != 1) {
        throw Exception(body['message'] ?? 'Failed to load tournaments');
      }

      final listJson = (body['data'] as List?) ?? [];
      return listJson.map((e) => TournamentModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch tournaments: $e');
    }
  }

  Future<void> _fetchTournaments() async {
    if (_apiToken == null || _apiToken!.isEmpty) return;

    try {
      // ✅ Fetch only user-created tournaments
      final userTournaments = await TournamentService.fetchUserTournaments(
        apiToken: _apiToken!,
        limit: 20,
        skip: 0,
      );

      setState(() {
        _tournaments = userTournaments
            .map((e) => {
          'tournament_id': e.tournamentId,
          'tournament_name': e.tournamentName,
        })
            .toList();
      });
    } catch (e) {
      final err = e.toString().toLowerCase();

      // ✅ Handle token/session expiration
      if (err.contains('session expired') || err.contains('unauthorized')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
          _showError('Session expired. Please login again.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        _showError('Failed to load tournaments: $e');
      }
    }
  }


  Future<List<Map<String, dynamic>>> _fetchVenues({bool reset = true}) async {
    if (reset) {
      _venueSkip = 0;
      _hasMoreVenues = true;
      _venues.clear();
    }
    final fetched = await VenueService.fetchVenues(
      apiToken: _apiToken!,
      limit: venuePageLimit,
      skip: _venueSkip,
      search: '',
    );
    final jsonList = fetched.map((e) => e.toJson()).toList();
    setState(() {
      _venues.addAll(jsonList);
      _venueSkip += jsonList.length;
      _hasMoreVenues = jsonList.length == venuePageLimit;
    });
    return jsonList;
  }

  Future<List<Map<String, dynamic>>> _fetchTeams(
    int tournamentId, {
    bool reset = true,
  }) async {
    if (reset) {
      _teamSkip = 0;
      _hasMoreTeams = true;
      _teams.clear();
    }
    final fetched = await TeamService.fetchTeams(
      apiToken: _apiToken!,
      tournamentId: tournamentId != 0 ? tournamentId : null,
      skip: _teamSkip,
      limit: teamPageLimit,
      search: '',
    );
    final mapped = fetched
        .map((e) => {'team_id': e.teamId, 'team_name': e.teamName})
        .toList();
    setState(() {
      _teams.addAll(mapped);
      _teamSkip += mapped.length;
      _hasMoreTeams = mapped.length == teamPageLimit;
    });
    return mapped;
  }

  Future<void> _fetchPlayers({
    required int teamId,
    required bool isTeamA,
  }) async {
    final players = await PlayerService.fetchTeamPlayers(
      teamId: teamId,
      apiToken: _apiToken!,
    );
    setState(() {
      if (isTeamA) {
        _teamAPlayers = players;
      } else {
        _teamBPlayers = players;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _updateMatch() async {
    // 1️⃣ Field‐by‐field validation
    if (_matchName == null || _matchName!.isEmpty) {
      _showError('Please enter match name');
      return;
    }
    if (_matchType == null) {
      _showError('Please select match type');
      return;
    }
    if (_matchType == 'tournament') {
      if (_selectedTournamentId == null) {
        _showError('Please select tournament');
        return;
      }
      if (_selectedTournamentMatchType == null) {
        _showError('Please select match stage');
        return;
      }
    }
    if (_selectedTeamAId == null || _selectedTeamBId == null) {
      _showError('Please select both teams');
      return;
    }
    if (_selectedTeamAPlayers.length < 2) {
      _showError('Select at least 2 players for Team A');
      return;
    }
    if (_selectedTeamBPlayers.length < 2) {
      _showError('Select at least 2 players for Team B');
      return;
    }
    if (_teamACaptainId == null || _teamAWicketKeeperId == null) {
      _showError('Select captain and wicket-keeper for Team A');
      return;
    }
    if (_teamBCaptainId == null || _teamBWicketKeeperId == null) {
      _showError('Select captain and wicket-keeper for Team B');
      return;
    }
    if (_selectedVenue == null) {
      _showError('Please select a venue');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showError('Please select match date and time');
      return;
    }
    if (_ballType == null) {
      _showError('Please select ball type');
      return;
    }
    final overs = int.tryParse(_matchOvers ?? '');
    if (overs == null || overs <= 0) {
      _showError('Enter valid number of total overs');
      return;
    }
    final maxPerBowler = int.tryParse(_maxOversPerBowler ?? '');
    if (maxPerBowler == null || maxPerBowler <= 0) {
      _showError('Enter valid max overs per bowler');
      return;
    }
    if (_selectedUmpires.isEmpty) {
      _showError('Please select at least one umpire');
      return;
    }

    // 2️⃣ All validations passed – proceed to call the API
    setState(() => _isSaving = true);
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/update-cricket-match'
      '?api_logged_in_token=$_apiToken&match_id=${widget.matchId}',
    );
    final form = {
      'match_name': _matchName!,
      'tournament_id': _matchType == 'tournament'
          ? '$_selectedTournamentId'
          : '0',
      'tournament_match_type': _matchType == 'tournament'
          ? '$_selectedTournamentMatchType'
          : '0',
      'team_one': '$_selectedTeamAId',
      'team_one_11': _selectedTeamAPlayers.join(','),
      'team_one_cap': '$_teamACaptainId',
      'team_one_wktkpr': '$_teamAWicketKeeperId',
      'team_two': '$_selectedTeamBId',
      'team_two_11': _selectedTeamBPlayers.join(','),
      'team_two_cap': '$_teamBCaptainId',
      'team_two_wktkpr': '$_teamBWicketKeeperId',
      'venue': '${_selectedVenue!['venue_id']}',
      'match_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'match_time':
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime!.minute.toString().padLeft(2, '0')}:00',
      'ball_type': _ballType!,
      'match_overs': _matchOvers!,
      'ballers_max_overs': _maxOversPerBowler!,
      'umpires': _selectedUmpires.join(','),
    };

    final response = await http.post(uri, body: form);
    setState(() => _isSaving = false);

    final jsonBody = json.decode(response.body);
    if (jsonBody['status'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match updated!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showError(
        (jsonBody['error'] as Map?)?.values.join('\n') ?? 'Update failed',
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  bool get _allFieldsValid {
    final overs = int.tryParse(_matchOvers ?? '');
    final maxPer = int.tryParse(_maxOversPerBowler ?? '');

    // at least 1 player, not exactly 11
    final teamAok = _selectedTeamAPlayers.isNotEmpty;
    final teamBok = _selectedTeamBPlayers.isNotEmpty;

    return _apiToken != null &&
        (_matchName?.isNotEmpty ?? false) &&
        _matchType != null &&
        (_matchType == 'tournament'
            ? (_selectedTournamentId != null &&
                  _selectedTournamentMatchType != null)
            : true) &&
        _selectedTeamAId != null &&
        _selectedTeamBId != null &&
        teamAok &&
        teamBok &&
        _teamACaptainId != null &&
        _teamAWicketKeeperId != null &&
        _teamBCaptainId != null &&
        _teamBWicketKeeperId != null &&
        _selectedVenue != null &&
        _selectedDate != null &&
        _selectedTime != null &&
        _ballType != null &&
        (overs != null && overs > 0) &&
        (maxPer != null && maxPer > 0) &&
        _selectedUmpires.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.grey[50]!;
    final txt = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: isDark
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
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Update Match',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match Type Chips
            Center(
              child: Wrap(
                spacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('One-to-One'),
                    selected: _matchType == 'one_to_one',
                    onSelected: (_) => setState(() {
                      _matchType = 'one_to_one';
                      _selectedTournamentId = null;
                      _selectedTournamentMatchType = null;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Tournament'),
                    selected: _matchType == 'tournament',
                    onSelected: (_) => setState(() {
                      _matchType = 'tournament';
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Match Name
            TextFormField(
              initialValue: _matchName,
              style: TextStyle(color: txt),
              decoration: InputDecoration(
                labelText: 'Match Name',
                labelStyle: TextStyle(color: txt),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => _matchName = v.trim(),
            ),
            const SizedBox(height: 16),
            if (_matchType == 'tournament') ...[
              DropdownButtonFormField<int>(
                value: _selectedTournamentId,
                decoration: _dropdownDecoration(isDark, 'Select Tournament'),
                items: _tournaments.map((t) {
                  return DropdownMenuItem<int>(
                    value: t['tournament_id'] as int,
                    child: Text(
                      t['tournament_name'],
                      style: TextStyle(color: txt),
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  _selectedTournamentId = v;
                  await _fetchTeams(v!, reset: true);
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedTournamentMatchType,
                decoration: _dropdownDecoration(isDark, 'Select Match Stage'),
                items: _tournamentMatchTypes.entries.map((e) {
                  return DropdownMenuItem<int>(
                    value: e.key,
                    child: Text(e.value, style: TextStyle(color: txt)),
                  );
                }).toList(),
                onChanged: (v) =>
                    setState(() => _selectedTournamentMatchType = v),
              ),
              const SizedBox(height: 20),
            ],
            // Teams
            OutlinedButton(
              onPressed: () => _showTeamSelector('Team A', true),
              child: Text(
                _selectedTeamAName ?? 'Select Team A',
                style: TextStyle(color: txt),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _showTeamSelector('Team B', false),
              child: Text(
                _selectedTeamBName ?? 'Select Team B',
                style: TextStyle(color: txt),
              ),
            ),
            const SizedBox(height: 16),
            // Players
            _playerSelectorUI(
              isDark,
              txt,
              _teamAPlayers,
              _selectedTeamAPlayers,
              'Team A',
              true,
            ),
            _playerSelectorUI(
              isDark,
              txt,
              _teamBPlayers,
              _selectedTeamBPlayers,
              'Team B',
              false,
            ),
            // Venue
            OutlinedButton(
              onPressed: _showVenueSelector,
              child: Text(
                _selectedVenue?['venue_name'] ?? 'Select Venue',
                style: TextStyle(color: txt),
              ),
            ),
            const SizedBox(height: 16),
            // Date & Time
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      _selectedDate == null
                          ? 'Pick Date'
                          : DateFormat('dd MMM yyyy').format(_selectedDate!),
                      style: TextStyle(color: txt),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(
                      _selectedTime == null
                          ? 'Pick Time'
                          : _selectedTime!.format(context),
                      style: TextStyle(color: txt),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Ball Type
            DropdownButtonFormField<String>(
              value: _ballType,
              decoration: _dropdownDecoration(isDark, 'Ball Type'),
              items: ['Leather', 'Tennis', 'Other']
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text(b, style: TextStyle(color: txt)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _ballType = v),
            ),
            const SizedBox(height: 12),
            // Overs Inputs
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _matchOvers,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: 'Total Overs',
                      helperText: 'Must be > 0',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => _matchOvers = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxOversPerBowler,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: 'Max Overs/Bowler',
                      helperText: 'Must be > 0',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => _maxOversPerBowler = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showUmpireSelector,
              child: const Text("Select Umpires"),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedUmpires.map((id) {
                final ump = _umpires.firstWhere(
                  (u) => int.parse(u['id'].toString()) == id,
                  orElse: () => {},
                );
                return Chip(
                  label: Text(ump['display_name'] ?? 'Unknown'),
                  onDeleted: () => setState(() => _selectedUmpires.remove(id)),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            // Update button
            Center(
              child: _actionButton(
                _isSaving ? 'Updating...' : 'Update Match',
                Icons.save,
                _isSaving ? null : _updateMatch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTeamSelector(String title, bool isTeamA) async {
    _teamSkip = 0;
    _hasMoreTeams = true;
    _teams.clear();
    await _fetchTeams(
      _matchType == 'tournament' && _selectedTournamentId != null
          ? _selectedTournamentId!
          : 0,
      reset: true,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (_, modalSet) {
          _teamScrollController.addListener(() async {
            if (_teamScrollController.position.pixels >=
                    _teamScrollController.position.maxScrollExtent - 100 &&
                !_isLoadingMoreTeams &&
                _hasMoreTeams) {
              modalSet(() => _isLoadingMoreTeams = true);
              final more = await _fetchTeams(
                _matchType == 'tournament' && _selectedTournamentId != null
                    ? _selectedTournamentId!
                    : 0,
                reset: false,
              );
              modalSet(() {
                _isLoadingMoreTeams = false;
                if (more.isEmpty) _hasMoreTeams = false;
              });
            }
          });

          final otherId = isTeamA ? _selectedTeamBId : _selectedTeamAId;
          final visible = _teams.where((t) => t['team_id'] != otherId).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Select $title',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: _teamScrollController,
                    itemCount: visible.length + (_isLoadingMoreTeams ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= visible.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final team = visible[i];
                      return ListTile(
                        title: Text(team['team_name']),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            if (isTeamA) {
                              _selectedTeamAId = team['team_id'];
                              _selectedTeamAName = team['team_name'];
                              _fetchPlayers(
                                teamId: team['team_id'],
                                isTeamA: true,
                              );
                            } else {
                              _selectedTeamBId = team['team_id'];
                              _selectedTeamBName = team['team_name'];
                              _fetchPlayers(
                                teamId: team['team_id'],
                                isTeamA: false,
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showVenueSelector() async {
    await _fetchVenues(reset: true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (_, modalSet) {
          _venueScrollController.addListener(() async {
            if (_venueScrollController.position.pixels >=
                    _venueScrollController.position.maxScrollExtent - 100 &&
                !_isLoadingMoreVenues &&
                _hasMoreVenues) {
              modalSet(() => _isLoadingMoreVenues = true);
              final more = await _fetchVenues(reset: false);
              modalSet(() {
                _isLoadingMoreVenues = false;
                if (more.isEmpty) _hasMoreVenues = false;
              });
            }
          });
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Select Venue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: _venueScrollController,
                    itemCount: _venues.length + (_isLoadingMoreVenues ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _venues.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final v = _venues[i];
                      return ListTile(
                        title: Text(v['venue_name']),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _selectedVenue = v);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _playerSelectorUI(
    bool isDark,
    Color txt,
    List<Map<String, dynamic>> players,
    List<int> selectedIds,
    String label,
    bool isTeamA,
  ) {
    if (players.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select $label Players',
          style: TextStyle(color: txt, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: players.map((p) {
            final id = int.parse(p['ID'].toString());
            return FilterChip(
              label: Text(
                p['display_name'],
                style: TextStyle(
                  color: selectedIds.contains(id) ? Colors.white : txt,
                ),
              ),
              selected: selectedIds.contains(id),
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              onSelected: (sel) {
                setState(() {
                  if (sel && selectedIds.length < 20) selectedIds.add(id);
                  if (!sel) selectedIds.remove(id);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: isTeamA ? _teamACaptainId : _teamBCaptainId,
          decoration: _dropdownDecoration(isDark, 'Select Captain'),
          items: selectedIds.map((id) {
            final p = players.firstWhere(
              (x) => x['ID'].toString() == id.toString(),
            );
            return DropdownMenuItem<int>(
              value: id,
              child: Text(p['display_name'], style: TextStyle(color: txt)),
            );
          }).toList(),
          onChanged: (v) => setState(() {
            if (isTeamA) {
              _teamACaptainId = v;
            } else {
              _teamBCaptainId = v;
            }
          }),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: isTeamA ? _teamAWicketKeeperId : _teamBWicketKeeperId,
          decoration: _dropdownDecoration(isDark, 'Select Wicket-Keeper'),
          items: selectedIds.map((id) {
            final p = players.firstWhere(
              (x) => x['ID'].toString() == id.toString(),
            );
            return DropdownMenuItem<int>(
              value: id,
              child: Text(p['display_name'], style: TextStyle(color: txt)),
            );
          }).toList(),
          onChanged: (v) => setState(() {
            if (isTeamA) {
              _teamAWicketKeeperId = v;
            } else {
              _teamBWicketKeeperId = v;
            }
          }),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _actionButton(String text, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(bool isDark, String hint) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );
}
