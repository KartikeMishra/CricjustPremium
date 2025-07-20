import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/player_service.dart';
import '../service/team_service.dart';
import '../service/tournament_service.dart';
import '../service/venue_service.dart';
import '../theme/color.dart';
import 'login_screen.dart';

class MatchUIScreen extends StatefulWidget {
  const MatchUIScreen({super.key});

  @override
  State<MatchUIScreen> createState() => _MatchUIScreenState();
}

class _MatchUIScreenState extends State<MatchUIScreen> {
  static const int teamPageLimit = 20;
  static const int venuePageLimit = 20;

  String? _matchType;
  String? _matchName;

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
  List<Map<String, dynamic>> _teams = [];
  int? _selectedTeamAId, _selectedTeamBId;
  String? _selectedTeamAName, _selectedTeamBName;

  // Players
  List<Map<String, dynamic>> _teamAPlayers = [], _teamBPlayers = [];
  List<int> _selectedTeamAPlayers = [], _selectedTeamBPlayers = [];
  int? _teamACaptainId,
      _teamAWicketKeeperId,
      _teamBCaptainId,
      _teamBWicketKeeperId;
  // 👨‍⚖️ Umpires
  List<Map<String, dynamic>> _umpires = [];
  final List<int> _selectedUmpires =
      []; // holds selected umpire IDs as integers

  // Venue
  List<Map<String, dynamic>> _venues = [];
  Map<String, dynamic>? _selectedVenue;

  // Date & Time
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final bool _isMatchSaved = false;
  int? _savedMatchId; // if API returns match_id, save it here

  // Other
  final List<String> _ballTypes = ['Leather', 'Tennis', 'Other'];
  String? _ballType, _matchOvers, _maxOversPerBowler;
  String? _apiToken;
  final TextEditingController _teamSearchCtrl = TextEditingController();

  // Scroll Controllers
  final ScrollController _teamScrollController = ScrollController();
  final ScrollController _venueScrollController = ScrollController();
  int _teamSkip = 0, _venueSkip = 0;
  bool _isLoadingMoreTeams = false, _hasMoreTeams = true;
  bool _isLoadingMoreVenues = false, _hasMoreVenues = true;
  bool _isSaving = false;

  Future<void> _loadUmpires() async {
    final prefs = await SharedPreferences.getInstance();
    _apiToken = prefs.getString('api_logged_in_token');
    if (_apiToken == null) return;

    final result = await TeamService.fetchUmpires(apiToken: _apiToken!);
    setState(() {
      _umpires = result;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkLoginAndFetchData(); // Your original call
    _loadUmpires(); // Add umpire loading here
  }

  @override
  void dispose() {
    _teamSearchCtrl.dispose();
    _teamScrollController.dispose();
    _venueScrollController.dispose();
    super.dispose();
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
                      final umpire = _umpires[i];
                      final id = int.tryParse(umpire['id'].toString());
                      final selected = _selectedUmpires.contains(id);

                      return ListTile(
                        title: Text(
                          umpire['display_name'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        tileColor: selected
                            ? AppColors.primary.withOpacity(0.2)
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
                              _selectedUmpires.add(id!);
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

  Future<void> _showTeamSelector(String title, bool isTeamA) async {
    _teamSkip = 0;
    _hasMoreTeams = true;
    _isLoadingMoreTeams = false;
    _teams = [];

    final int tournamentId =
        _matchType == 'tournament' && _selectedTournamentId != null
        ? _selectedTournamentId!
        : 0;

    await _fetchTeams(tournamentId, reset: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setModalState) {
          _teamScrollController.addListener(() async {
            if (_teamScrollController.position.pixels >=
                    _teamScrollController.position.maxScrollExtent - 100 &&
                !_isLoadingMoreTeams &&
                _hasMoreTeams) {
              setModalState(() => _isLoadingMoreTeams = true);
              final more = await _fetchTeams(tournamentId, reset: false);
              setModalState(() {
                _isLoadingMoreTeams = false;
                if (more.isEmpty) _hasMoreTeams = false;
              });
            }
          });

          final otherId = isTeamA ? _selectedTeamBId : _selectedTeamAId;
          final visibleTeams = _teams
              .where((t) => t['team_id'] != otherId)
              .toList();
          final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  'Select $title',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: _teamScrollController,
                    itemCount:
                        visibleTeams.length + (_isLoadingMoreTeams ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= visibleTeams.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final team = visibleTeams[i];
                      return ListTile(
                        textColor: isDark ? Colors.white : null,
                        tileColor: isDark ? Colors.grey[800] : null,
                        title: Text(team['team_name']),
                        onTap: () {
                          if (team['team_id'] == otherId) {
                            _showError(
                              'You cannot select the same team for both sides.',
                            );
                            return;
                          }

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

  Future<void> _checkLoginAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token');
    if (token == null || token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    _apiToken = token;
    await _fetchTournaments();
    await _fetchVenues(reset: true);
  }

  Future<void> _fetchTournaments() async {
    try {
      final live = await TournamentService.fetchTournaments(
        type: 'live',
        limit: 20,
        skip: 0,
      );
      final upcoming = await TournamentService.fetchTournaments(
        type: 'upcoming',
        limit: 20,
        skip: 0,
      );
      setState(() {
        _tournaments = [...live, ...upcoming]
            .map(
              (e) => {
                'tournament_id': e.tournamentId,
                'tournament_name': e.tournamentName,
              },
            )
            .toList();
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _resetTournamentState() {
    setState(() {
      _teams.clear();
      _teamAPlayers.clear();
      _teamBPlayers.clear();
      _selectedTournamentId = null;
      _selectedTournamentMatchType = null;
      _selectedTeamAId = null;
      _selectedTeamBId = null;
      _selectedTeamAName = null;
      _selectedTeamBName = null;
      _selectedTeamAPlayers.clear();
      _selectedTeamBPlayers.clear();
      _teamACaptainId = null;
      _teamAWicketKeeperId = null;
      _teamBCaptainId = null;
      _teamBWicketKeeperId = null;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchVenues({bool reset = true}) async {
    if (_apiToken == null) return [];

    if (reset) {
      _venueSkip = 0;
      _hasMoreVenues = true;
    }

    try {
      final venues = await VenueService.fetchVenues(
        apiToken: _apiToken!,
        limit: venuePageLimit,
        skip: _venueSkip,
        search: '',
      );
      final jsonList = venues.map((e) => e.toJson()).toList();
      setState(() {
        if (reset) {
          _venues = jsonList;
        } else {
          _venues.addAll(jsonList);
        }
        _venueSkip += jsonList.length;
        _hasMoreVenues = jsonList.length == venuePageLimit;
      });
      return jsonList;
    } catch (e) {
      _showError(e.toString());
      return [];
    }
  }

  Future<void> _fetchPlayers({
    required int teamId,
    required bool isTeamA,
  }) async {
    if (_apiToken == null) return;

    try {
      final players = await PlayerService.fetchTeamPlayers(
        teamId: teamId,
        apiToken: _apiToken!,
      );

      setState(() {
        if (isTeamA) {
          _teamAPlayers = players;
          _selectedTeamAPlayers.clear();
          _teamACaptainId = null;
          _teamAWicketKeeperId = null;
        } else {
          _teamBPlayers = players;
          _selectedTeamBPlayers.clear();
          _teamBCaptainId = null;
          _teamBWicketKeeperId = null;
        }
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<List<Map<String, dynamic>>> _fetchTeams(
    int tournamentId, {
    bool reset = true,
  }) async {
    if (_apiToken == null) return [];

    if (reset) {
      _teamSkip = 0;
      _hasMoreTeams = true;
      _teams.clear();
    }

    try {
      final result = await TeamService.fetchTeams(
        apiToken: _apiToken!,
        tournamentId: tournamentId != 0 ? tournamentId : null,
        skip: _teamSkip,
        limit: 20,
        search: _teamSearchCtrl.text,
      );

      final mapped = result
          .map((e) => {'team_id': e.teamId, 'team_name': e.teamName})
          .toList();

      setState(() {
        _teams.addAll(mapped);
        _teamSkip += 20;
        _hasMoreTeams = result.length == 20;
      });

      return mapped;
    } catch (e) {
      _showError('Failed to load teams');
      return [];
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
  // REPLACE this method inside your MatchUIScreen:

  bool get _allFieldsValid {
    final overs = int.tryParse(_matchOvers ?? '');
    final maxPerBowler = int.tryParse(_maxOversPerBowler ?? '');

    return _apiToken != null &&
        (_matchName?.isNotEmpty ?? false) &&
        _matchType != null &&
        (_matchType == 'tournament'
            ? (_selectedTournamentId != null &&
                  _selectedTournamentMatchType != null)
            : true) &&
        _selectedTeamAId != null &&
        _selectedTeamBId != null &&
        _selectedTeamAPlayers.length == 11 &&
        _selectedTeamBPlayers.length == 2 &&
        _teamACaptainId != null &&
        _teamAWicketKeeperId != null &&
        _teamBCaptainId != null &&
        _teamBWicketKeeperId != null &&
        _selectedVenue != null &&
        _selectedDate != null &&
        _selectedTime != null &&
        _ballType != null &&
        (overs != null && overs > 0) &&
        (maxPerBowler != null && maxPerBowler > 0) &&
        _selectedUmpires.isNotEmpty;
  }

  Future<void> _saveFixture() async {
    // ✅ Custom field-by-field validation
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
      _showError('Select exactly 2 players for Team A');
      return;
    }

    if (_selectedTeamBPlayers.length < 2) {
      _showError('Select exactly 2 players for Team B');
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

    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/add-cricket-match'
      '?api_logged_in_token=$_apiToken',
    );

    final Map<String, String> form = {
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
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00',
      'ball_type': _ballType!,
      'match_overs': _matchOvers!,
      'bowlers_max_overs': _maxOversPerBowler!,
      'umpires': _selectedUmpires.map((id) => id.toString()).join(','),
    };

    setState(() => _isSaving = true);
    try {
      final response = await http.post(uri, body: form);
      final jsonBody = json.decode(response.body);
      if (jsonBody['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fixture saved!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        final errorText =
            (jsonBody['error'] as Map?)?.values.join('\n') ?? 'Unknown error';
        _showError(errorText);
      }
    } catch (e) {
      _showError('Failed to save fixture: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _showVenueSelector() async {
    _venueSkip = 0;
    _hasMoreVenues = true;
    _isLoadingMoreVenues = false;
    _venues = [];
    await _fetchVenues(reset: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setModalState) {
          _venueScrollController.addListener(() async {
            if (_venueScrollController.position.pixels >=
                    _venueScrollController.position.maxScrollExtent - 100 &&
                !_isLoadingMoreVenues &&
                _hasMoreVenues) {
              setModalState(() => _isLoadingMoreVenues = true);
              final more = await _fetchVenues(reset: false);
              setModalState(() {
                _isLoadingMoreVenues = false;
                if (more.isEmpty) _hasMoreVenues = false;
              });
            }
          });

          final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  'Select Venue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
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
                      final venue = _venues[i];
                      return ListTile(
                        textColor: isDark ? Colors.white : null,
                        tileColor: isDark ? Colors.grey[800] : null,
                        title: Text(venue['venue_name']),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _selectedVenue = venue);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.grey[50]!;
    final txt = isDark ? Colors.white : Colors.black87;
    final card = isDark ? Colors.grey[850]! : Colors.white;

    return Scaffold(
      backgroundColor: bg,
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
            iconTheme: const IconThemeData(color: Colors.white),
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Add Match',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📝 Match Name

            // 🏷️ Match Type Selector (Centered and Positioned at Top)
            Center(
              child: Wrap(
                spacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('One-to-One'),
                    selected: _matchType == 'one_to_one',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _matchType == 'one_to_one' ? Colors.white : txt,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() {
                      _matchType = 'one_to_one';
                      _resetTournamentState();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Tournament'),
                    selected: _matchType == 'tournament',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _matchType == 'tournament' ? Colors.white : txt,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() {
                      _matchType = 'tournament';
                      _resetTournamentState();
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // 📝 Match Name
            TextFormField(
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

            // 🏆 Tournament Dropdowns (if applicable)
            if (_matchType == 'tournament') ...[
              // 🏆 Select Tournament
              DropdownButtonFormField<int>(
                value: _selectedTournamentId,
                isExpanded: true,
                decoration: _dropdownDecoration(isDark, 'Select Tournament'),
                items: _tournaments.map<DropdownMenuItem<int>>((t) {
                  return DropdownMenuItem<int>(
                    value: t['tournament_id'] as int,
                    child: Text(
                      t['tournament_name'],
                      style: TextStyle(color: txt),
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  _selectedTournamentId = v;
                  await _fetchTeams(v, reset: true);
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),

              // 🏁 Select Match Stage (Staging, Semi, Final, etc.)
              DropdownButtonFormField<int>(
                value: _selectedTournamentMatchType,
                isExpanded: true,
                decoration: _dropdownDecoration(isDark, 'Select Match Stage'),
                items: _tournamentMatchTypes.entries.map<DropdownMenuItem<int>>(
                  (e) {
                    return DropdownMenuItem<int>(
                      value: e.key,
                      child: Text(e.value, style: TextStyle(color: txt)),
                    );
                  },
                ).toList(),
                onChanged: (v) {
                  setState(() => _selectedTournamentMatchType = v);
                },
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'Select Teams',
              style: TextStyle(color: txt, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTeamSelector('Team A', true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _selectedTeamAName ?? 'Select Team A',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: txt),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTeamSelector('Team B', false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _selectedTeamBName ?? 'Select Team B',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: txt),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 👥 Players
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

            // 📍 Venue
            OutlinedButton(
              onPressed: _showVenueSelector,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined),
                  const SizedBox(width: 6),
                  Text(
                    _selectedVenue?['venue_name'] ?? 'Select Venue',
                    style: TextStyle(color: txt),
                  ),
                ],
              ),
            ),

            // 📅 Date & Time
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate == null
                              ? 'Pick Date'
                              : DateFormat(
                                  'dd MMM yyyy',
                                ).format(_selectedDate!),
                          style: TextStyle(color: txt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _selectedTime == null
                              ? 'Pick Time'
                              : _selectedTime!.format(context),
                          style: TextStyle(color: txt),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 🏐 Ball Type
            DropdownButtonFormField<String>(
              value: _ballType,
              isExpanded: true,
              decoration: _dropdownDecoration(isDark, 'Ball Type'),
              items: _ballTypes.map((b) {
                return DropdownMenuItem(
                  value: b,
                  child: Text(b, style: TextStyle(color: txt)),
                );
              }).toList(),
              onChanged: (v) => setState(() => _ballType = v),
            ),
            const SizedBox(height: 12),

            // Total Overs & Max Overs per Bowler
            Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                    onChanged: (v) => setState(() => _matchOvers = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
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
                    onChanged: (v) => setState(() => _maxOversPerBowler = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  _showUmpireSelector, // ✅ use this method (already created above)
              child: const Text("Select Umpires"),
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedUmpires.map((id) {
                final umpire = _umpires.firstWhere(
                  (u) => int.tryParse(u['id'].toString()) == id,
                  orElse: () => {},
                );
                return Chip(
                  label: Text(umpire['display_name'] ?? 'Unknown'),
                  onDeleted: () {
                    setState(() => _selectedUmpires.remove(id));
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // 💾 Save & Start Match Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                  _isSaving ? 'Saving...' : 'Save Fixture',
                  Icons.save,
                  _isSaving ? null : _saveFixture,
                ),

                /*
            _actionButton('Start Match', Icons.play_arrow, () {
              // Add start match logic here
            }),*/
              ],
            ),
          ],
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

  Widget _teamSelectorUI(bool isDark, Color txt) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Select Teams',
        style: TextStyle(color: txt, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
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
    ],
  );

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
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (selectedIds.length < 11) selectedIds.add(id);
                  } else {
                    selectedIds.remove(id);
                  }
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
            return DropdownMenuItem(
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
            return DropdownMenuItem(
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
}
