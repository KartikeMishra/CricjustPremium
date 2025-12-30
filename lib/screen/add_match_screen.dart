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
  int? _teamACaptainId, _teamAWicketKeeperId, _teamBCaptainId, _teamBWicketKeeperId;

  // 👨‍⚖️ Umpires
  List<Map<String, dynamic>> _umpires = [];
  final List<int> _selectedUmpires = []; // holds selected umpire IDs as integers

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
    _checkLoginAndFetchData();
    _loadUmpires();
  }

  @override
  void dispose() {
    _teamSearchCtrl.dispose();
    _teamScrollController.dispose();
    _venueScrollController.dispose();
    super.dispose();
  }

  // ---------- Helpers: Sheet Wrapper & Decorations ----------

  Widget _sheetWrapper({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
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
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  BoxDecoration _sectionCard(bool isDark) => BoxDecoration(
    color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
    boxShadow: [
      BoxShadow(
        color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black12,
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ---------- Bottom Sheets ----------

  Future<void> _showUmpireSelector() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return _sheetWrapper(
            context: context,
            title: 'Select Umpires',
            child: Column(
              children: [
                Expanded(
                  child: _umpires.isEmpty
                      ? Center(
                    child: Text(
                      'No umpires found',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  )
                      : ListView.separated(
                    itemCount: _umpires.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    itemBuilder: (_, i) {
                      final umpire = _umpires[i];
                      final id = int.tryParse(umpire['id'].toString());
                      final selected = _selectedUmpires.contains(id);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          child: const Icon(Icons.person),
                        ),
                        title: Text(
                          umpire['display_name'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          selected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: selected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black26),
                        ),
                        onTap: () {
                          setModalState(() {
                            if (selected) {
                              _selectedUmpires.remove(id);
                            } else if (id != null) {
                              _selectedUmpires.add(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
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
    _teamSearchCtrl.clear();

    final int tournamentId = _matchType == 'tournament' && _selectedTournamentId != null
        ? _selectedTournamentId!
        : 0;

    await _fetchTeams(tournamentId, reset: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModalState) {
          final otherId = isTeamA ? _selectedTeamBId : _selectedTeamAId;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          Future<void> triggerSearch() async {
            setModalState(() {
              _isLoadingMoreTeams = true;
              _hasMoreTeams = true;
            });
            _teamSkip = 0;
            _teams.clear();
            await _fetchTeams(tournamentId, reset: true);
            setModalState(() => _isLoadingMoreTeams = false);
          }

          return _sheetWrapper(
            context: context,
            title: 'Select $title',
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _teamSearchCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search team',
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _teamSearchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _teamSearchCtrl.clear();
                        triggerSearch();
                      },
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => triggerSearch(),
                ),
                const SizedBox(height: 12),

                // Teams List with infinite scroll
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (sn) {
                      if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 120 &&
                          !_isLoadingMoreTeams &&
                          _hasMoreTeams) {
                        setModalState(() => _isLoadingMoreTeams = true);
                        _fetchTeams(tournamentId, reset: false).then((more) {
                          setModalState(() {
                            _isLoadingMoreTeams = false;
                            if (more.isEmpty) _hasMoreTeams = false;
                          });
                        });
                      }
                      return false;
                    },
                    child: _teams.isEmpty && !_isLoadingMoreTeams
                        ? Center(
                      child: Text(
                        'No teams found',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    )
                        : ListView.separated(
                      controller: _teamScrollController,
                      itemCount: _teams.length + (_isLoadingMoreTeams ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      itemBuilder: (_, i) {
                        if (i >= _teams.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final team = _teams[i];
                        if (team['team_id'] == otherId) {
                          // Hide the other side's currently selected team
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: CircleAvatar(
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            child: const Icon(Icons.group),
                          ),
                          title: Text(
                            team['team_name'],
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            if (team['team_id'] == otherId) {
                              _showError('You cannot select the same team for both sides.');
                              return;
                            }
                            Navigator.pop(context);
                            setState(() {
                              if (isTeamA) {
                                _selectedTeamAId = team['team_id'];
                                _selectedTeamAName = team['team_name'];
                                _fetchPlayers(teamId: team['team_id'], isTeamA: true);
                              } else {
                                _selectedTeamBId = team['team_id'];
                                _selectedTeamBName = team['team_name'];
                                _fetchPlayers(teamId: team['team_id'], isTeamA: false);
                              }
                            });
                          },
                        );
                      },
                    ),
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
    _venueSkip = 0;
    _hasMoreVenues = true;
    _isLoadingMoreVenues = false;
    _venues = [];
    await _fetchVenues(reset: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return _sheetWrapper(
            context: context,
            title: 'Select Venue',
            child: NotificationListener<ScrollNotification>(
              onNotification: (sn) {
                if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 120 &&
                    !_isLoadingMoreVenues &&
                    _hasMoreVenues) {
                  setModalState(() => _isLoadingMoreVenues = true);
                  _fetchVenues(reset: false).then((more) {
                    setModalState(() {
                      _isLoadingMoreVenues = false;
                      if (more.isEmpty) _hasMoreVenues = false;
                    });
                  });
                }
                return false;
              },
              child: _venues.isEmpty && !_isLoadingMoreVenues
                  ? Center(
                child: Text(
                  'No venues found',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
              )
                  : ListView.builder(
                controller: _venueScrollController,
                itemCount: _venues.length + (_isLoadingMoreVenues ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _venues.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final venue = _venues[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      venue['venue_name'],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedVenue = venue);
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Data ----------

  Future<void> _checkLoginAndFetchData() async {
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
    await _fetchTournaments();
    await _fetchVenues(reset: true);
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
      final msg = e.toString().toLowerCase();
      if (msg.contains('session expired') || msg.contains('unauthorized')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
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
/*
  Future<void> _fetchTournaments() async {
    if (_apiToken == null || _apiToken!.isEmpty) return;

    try {
      final live = await TournamentService.fetchTournaments(
        apiToken: _apiToken!, // ✅ pass token
        type: 'live',
        limit: 20,
        skip: 0,
      );

      final upcoming = await TournamentService.fetchTournaments(
        apiToken: _apiToken!, // ✅ pass token
        type: 'upcoming',
        limit: 20,
        skip: 0,
      );

      setState(() {
        _tournaments = [...live, ...upcoming]
            .map((e) => {
          'tournament_id': e.tournamentId,
          'tournament_name': e.tournamentName,
        })
            .toList();
      });
    } catch (e) {
      // ✅ Auto logout on expired session
      if (e.toString().toLowerCase().contains('session expired')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        _showError('Failed to load tournaments: $e');
      }
    }
  }*/


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

      final mapped = result.map((e) => {'team_id': e.teamId, 'team_name': e.teamName}).toList();

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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ---------- Save Fixture (unchanged logic) ----------

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
    if (maxPerBowler > overs) {
      _showError('Max overs per bowler cannot exceed total overs');
      return;
    }
    if (_selectedUmpires.isEmpty) {
      _showError('Please select at least one umpire');
      return;
    }

    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/add-cricket-match?api_logged_in_token=$_apiToken',
    );

    final Map<String, String> form = {
      'match_name': _matchName!,
      'tournament_id': _matchType == 'tournament' ? '$_selectedTournamentId' : '0',
      'tournament_match_type': _matchType == 'tournament' ? '$_selectedTournamentMatchType' : '0',
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
      // ✅ correct API key (with 'a' in ballers)
      'ballers_max_overs': _maxOversPerBowler!,
      'umpires': _selectedUmpires.map((id) => id.toString()).join(','),
    };

    setState(() => _isSaving = true);
    try {
      final response = await http.post(uri, body: form);
      final jsonBody = json.decode(response.body);
      if (jsonBody['status'] == 1) {
        if (!mounted) return;
        // Return a value so the caller knows to refresh
        Navigator.pop(context, true);
      }
      else {
        final errorText = (jsonBody['error'] as Map?)?.values.join('\n') ?? 'Unknown error';
        _showError(errorText);
      }
    } catch (e) {
      _showError('Failed to save fixture: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------- UI ----------
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          )
              : const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            title: const Text(
              'Add Match',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5),
            ),
          ),
        ),
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ----- Match Type & Name -----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _sectionCard(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('One-to-One'),
                            selected: _matchType == 'one_to_one',
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _matchType == 'one_to_one' ? Colors.white : txt,
                              fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w700,
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
                    TextFormField(
                      style: TextStyle(color: txt),
                      decoration: InputDecoration(
                        labelText: 'Match Name',
                        labelStyle: TextStyle(color: txt),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onChanged: (v) => _matchName = v.trim(),
                    ),
                    if (_matchType == 'tournament') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedTournamentId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF262626) : null,
                        decoration: _dropdownDecoration(isDark, 'Select Tournament'),
                        items: _tournaments.map<DropdownMenuItem<int>>((t) {
                          return DropdownMenuItem<int>(
                            value: t['tournament_id'] as int,
                            child: Text(t['tournament_name'], style: TextStyle(color: txt)),
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
                      DropdownButtonFormField<int>(
                        value: _selectedTournamentMatchType,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF262626) : null,
                        decoration: _dropdownDecoration(isDark, 'Select Match Stage'),
                        items: _tournamentMatchTypes.entries.map<DropdownMenuItem<int>>(
                              (e) => DropdownMenuItem<int>(
                            value: e.key,
                            child: Text(e.value, style: TextStyle(color: txt)),
                          ),
                        ).toList(),
                        onChanged: (v) => setState(() => _selectedTournamentMatchType = v),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ----- Teams & Players -----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _sectionCard(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Select Teams', style: TextStyle(color: txt, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            ),
                            onPressed: () => _showTeamSelector('Team A', true),
                            child: Text(
                              _selectedTeamAName ?? 'Select Team A',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            ),
                            onPressed: () => _showTeamSelector('Team B', false),
                            child: Text(
                              _selectedTeamBName ?? 'Select Team B',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Team A players
                    _playerSelectorUI(isDark, txt, _teamAPlayers, _selectedTeamAPlayers, 'Team A', true),
                    // Team B players
                    _playerSelectorUI(isDark, txt, _teamBPlayers, _selectedTeamBPlayers, 'Team B', false),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ----- Venue & Date/Time -----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _sectionCard(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Match Details', style: TextStyle(color: txt, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                      ),
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(
                        _selectedVenue?['venue_name'] ?? 'Select Venue',
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _showVenueSelector,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            ),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _selectedDate == null
                                  ? 'Pick Date'
                                  : DateFormat('dd MMM yyyy').format(_selectedDate!),
                              style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                            ),
                            onPressed: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            ),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              _selectedTime == null ? 'Pick Time' : _selectedTime!.format(context),
                              style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                            ),
                            onPressed: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ----- Ball/Over Settings & Umpires -----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _sectionCard(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Match Settings', style: TextStyle(color: txt, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _ballType,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF262626) : null,
                      decoration: _dropdownDecoration(isDark, 'Ball Type'),
                      items: _ballTypes
                          .map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(color: txt))))
                          .toList(),
                      onChanged: (v) => setState(() => _ballType = v),
                    ),
                    const SizedBox(height: 12),
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
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (v) {
                              final val = int.tryParse(v);
                              setState(() {
                                if (val == null || val <= 0) {
                                  _matchOvers = null;
                                  _showError('Total overs must be greater than 0');
                                } else {
                                  _matchOvers = v;
                                }
                              });
                            },
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
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (v) => setState(() => _maxOversPerBowler = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showUmpireSelector,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Select Umpires', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          onDeleted: () => setState(() => _selectedUmpires.remove(id)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ----- Actions -----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionButton(
                    _isSaving ? 'Saving...' : 'Save Fixture',
                    Icons.save,
                    _isSaving ? null : _saveFixture,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (Kept for compatibility if referenced elsewhere)
  Widget _teamSelectorUI(bool isDark, Color txt) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Select Teams', style: TextStyle(color: txt, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => _showTeamSelector('Team A', true),
        child: Text(_selectedTeamAName ?? 'Select Team A', style: TextStyle(color: txt)),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => _showTeamSelector('Team B', false),
        child: Text(_selectedTeamBName ?? 'Select Team B', style: TextStyle(color: txt)),
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
        Text('Select $label Players', style: TextStyle(color: txt, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: players.map((p) {
            final id = int.parse(p['ID'].toString());
            final isSelected = selectedIds.contains(id);
            return FilterChip(
              label: Text(
                p['display_name'],
                style: TextStyle(color: isSelected ? Colors.white : txt, fontWeight: FontWeight.w600),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (selectedIds.length < 20) selectedIds.add(id);
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
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF262626) : null,
          decoration: _dropdownDecoration(isDark, 'Select Captain'),
          items: selectedIds.map((id) {
            final p = players.firstWhere((x) => x['ID'].toString() == id.toString());
            return DropdownMenuItem(value: id, child: Text(p['display_name'], style: TextStyle(color: txt)));
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
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF262626) : null,
          decoration: _dropdownDecoration(isDark, 'Select Wicket-Keeper'),
          items: selectedIds.map((id) {
            final p = players.firstWhere((x) => x['ID'].toString() == id.toString());
            return DropdownMenuItem(value: id, child: Text(p['display_name'], style: TextStyle(color: txt)));
          }).toList(),
          onChanged: (v) => setState(() {
            if (isTeamA) {
              _teamAWicketKeeperId = v;
            } else {
              _teamBWicketKeeperId = v;
            }
          }),
        ),
        const SizedBox(height: 8),
        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
      ],
    );
  }
}
