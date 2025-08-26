
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/match_score_model.dart';
import '../service/match_youtube_service.dart';
import '../service/player_service.dart';
import '../service/match_score_service.dart';
import '../theme/color.dart';
import '../widget/animated_score_card.dart';
import '../widget/dialog/end_match_dialog.dart';
import '../widget/last_six_balls_widget.dart';
import '../widget/player_stats_card.dart';
import '../widget/scoring_inputs.dart';
import '../widget/shot_type_dialog.dart';
import '../provider/match_state.dart';
import '../widget/wicket_type_dialog.dart';
import 'full_match_detail.dart';

class AddScoreScreen extends StatefulWidget {
  final int matchId;
  final String token;

  // ✅ Optional preload data
  final Map<String, dynamic>? currentScoreData;
  final List<Map<String, dynamic>>? preloadedBattingSquad;
  final List<Map<String, dynamic>>? preloadedBowlingSquad;
  final VoidCallback? onScoreSubmitted;

  const AddScoreScreen({
    super.key,
    required this.matchId,
    required this.token,
    this.currentScoreData,
    this.preloadedBattingSquad,
    this.preloadedBowlingSquad,
    this.onScoreSubmitted, // ✅ Initialize here
  });

  @override
  State<AddScoreScreen> createState() => _AddScoreScreenState();
}
enum OutBatsman { striker, nonStriker }
// 🔒 Map UI labels → API wicket_type values (from your endpoint spec)
const Map<String, String> kWicketTypeMap = {
  'Bowled'            : 'Bowled',
  'Caught'            : 'Caught',
  'Caught Behind'     : 'Caught Behind',
  'Caught and Bowled' : 'Caught and Bowled',
  'Stumped'           : 'Stumped',
  'Run Out'           : 'Run Out',
  'LBW'               : 'LBW',
  'Retired Hurt'      : 'Retired Hurt',
  'Retired Out'       : 'Retired Out',
  'Mankaded'          : 'Mankaded',
  'Absent Hurt'       : 'Absent Hurt',
  'Hit the ball twice': 'Hit the ball twice',
  'Obstr the field'   : 'Obstr the field',
  'Timed Out'         : 'Timed Out',
  'Retired'           : 'Retired',
};


class _AddScoreScreenState extends State<AddScoreScreen>
{
  List<Map<String, dynamic>> _battingSidePlayers = [];
  List<Map<String, dynamic>> _bowlingSidePlayers = [];

  int? onStrikePlayerId, nonStrikePlayerId, bowlerId;
  String? onStrikeName, nonStrikeName, bowlerName;

  int? _teamOneId, _teamTwoId;
  List<int> _teamOne11 = [], _teamTwo11 = [];
  int? _firstInningTeamId;
  bool _firstInningClosed = false;
  String teamName = '';

  int runs = 0, wickets = 0;
  int overNumber = 0, ballNumber = 1;
  int? selectedRuns ;
  String? selectedExtra;
  bool isWicket = false;
  String? wicketType;
  bool _isFreeHit = false;
  String? matchName;
  final bool _inningsOver = false;
  bool _isSubmitting = false;
  bool _isEnding     = false;
  // Batsmen
  int onStrikeRuns    = 0;
  int nonStrikeRuns   = 0;
  String? _youtubeUrl;

// Extras & run rate
  int totalExtras     = 0;
  double currentRunRate = 0;

// Bowler figures
  int bowlerRunsConceded   = 0;
  int bowlerWickets        = 0;
  int bowlerMaidens        = 0;
  String bowlerOversBowled = '';
  double bowlerEconomy     = 0;
  bool _isScoringDisabled = false;

  final Set<int> _usedBatsmen = {};
  final Set<int> _usedBowlers = {};
  Map<int,double> _bowlerOversMap = {};
  int? _lastBowlerId;
  int _matchOvers = 0;
  int _bowlerMaxOvers = 0;
  final ChangeNotifier _lastSixBallsRefresher = ChangeNotifier();

  // squads for innings swap
  late List<Map<String, dynamic>> _team1Squad;
  late List<Map<String, dynamic>> _team2Squad;
  bool _isSecondInning = false;

  OutBatsman? _lastOutBatsman; // who got out (only for run-out)
  int? _outPlayerId;           // optional: player ID to replace
  int? _runOutBy;
  int? _catchBy;
  int _firstInningScore = 0;
  double requiredRunRate = 0.0;
  String? matchResultStatus; // 🏆 or ❌ or 🤝
  Color? matchResultColor;   // Green, Red, Orange
  bool isCloseMatch = false; // ⚠️ for UI animation
  String? _selectedShotType;
  String? _teamOneName;
  String? _teamTwoName;

// Batsmen
  int onStrikeBalls = 0;
  int nonStrikeBalls = 0;
  int? _currentWicketKeeperId;
  String? _currentWicketKeeperName;
  final List<int> _dismissedBatters = [];

  List<String> timeline = [];
  final Set<String> _submittedBalls = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _lastSixBallsRefresher.dispose();
    super.dispose();
  }


  Future<void> _init() async {
    try {
      await _fetchMatchDetails();                     // ✅ Step 1
      await _loadSquads();                            // ✅ Step 2

      final scoreData = await _fetchCurrentScoreData(); // ✅ Step 3
      if (scoreData != null) {
        _parseCurrentScore(scoreData);
      }

      // hydrate bowler overs from scorecard
      await _refreshBowlerOversFromScorecard();        // ✅ Step 3.1
      await _updateLastCompletedOverBowler();          // ✅ allow consecutive-bowler check

      // ✅ Step 4: Manual player selection if API returns nothing
      if (onStrikePlayerId == null || nonStrikePlayerId == null || bowlerId == null) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          await _showSelectPlayerSheet(isBatsman: true, selectForStriker: true);   // striker
          await _showSelectPlayerSheet(isBatsman: true, selectForStriker: false);  // non-striker
          await _showSelectPlayerSheet(isBatsman: false);                          // bowler
        });
      }

      setState(() {}); // ✅ Final UI refresh
    } catch (e) {
      _showError('❌ Failed to load match or score data');
    }
  }

  /// Full pull‑to‑refresh (keeps logic intact)
  Future<void> _hardRefresh() async {
    try {
      final ok = await _fetchMatchDetails();
      if (ok) {
        await _loadSquads();
      }
      final fresh = await _fetchCurrentScoreData();
      if (fresh != null) {
        _parseCurrentScore(fresh, overridePlayers: false);
      }
      await _refreshBowlerOversFromScorecard();
      await _updateLastCompletedOverBowler();
      _refreshLastSixBalls(delayMs: 60);
      setState(() {});
    } catch (_) {
      // ignore
    }
  }

  /// 4.3 Reset and swap into 2nd innings
  void _startSecondInning() {
    if (_isSecondInning) return;

    setState(() {
      _isSecondInning   = true;
      _firstInningClosed = true;

      // reset counters
      overNumber  = 0;
      ballNumber  = 1;
      runs        = 0;
      wickets     = 0;
      totalExtras = 0;
      currentRunRate = 0;

      // clear players & tracking
      _resetInningPlayers();
      _usedBatsmen.clear();
      _usedBowlers.clear();
      _bowlerOversMap.clear();
      _lastBowlerId = null;

      // clear timeline / submitted keys
      timeline.clear();
      _submittedBalls.clear();

      // swap squads
      _battingSidePlayers = _team2Squad;
      _bowlingSidePlayers = _team1Squad;
    });

    debugPrint('🔄 Second innings local state reset & squads swapped.');
  }

  void _resetInningPlayers() {
    onStrikePlayerId = null;
    onStrikeName     = null;
    onStrikeRuns     = 0;

    nonStrikePlayerId = null;
    nonStrikeName     = null;
    nonStrikeRuns     = 0;

    bowlerId = null;
    bowlerName = null;
    bowlerRunsConceded = 0;
    bowlerWickets      = 0;
    bowlerMaidens      = 0;
    bowlerOversBowled  = '';
    bowlerEconomy      = 0.0;

    selectedRuns  = null;
    selectedExtra = null;
    isWicket      = false;
    wicketType    = null;
    _isFreeHit    = false;
  }

  Future<int?> _pickBowlingSidePlayer({
    required String title,
  }) async {
    int? selectedId;

    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.sports_cricket, size: 20),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView.builder(
              itemCount: _bowlingSidePlayers.length,
              itemBuilder: (_, i) {
                final p = _bowlingSidePlayers[i];
                final id = p['id'] as int;
                final name = (p['name'] ??
                    p['display_name'] ??
                    p['user_login'] ??
                    'Unknown') as String;
                return RadioListTile<int>(
                  title: Text(name),
                  value: id,
                  groupValue: selectedId,
                  onChanged: (v) {
                    selectedId = v;
                    (ctx as Element).markNeedsBuild();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedId != null) Navigator.pop(ctx, selectedId);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectInitialSecondInningPlayers() async {
    await _showSelectPlayerSheet(isBatsman: true, selectForStriker: true);
    await _showSelectPlayerSheet(isBatsman: true, selectForStriker: false);
    await _showSelectPlayerSheet(isBatsman: false);
  }

  Future<void> _undoLastBall() async {
    final ok = await MatchScoreService.undoLastBall(widget.matchId, widget.token, context);
    if (!ok) {
      _showError('❌ Could not undo last ball.');
      return;
    }

    // Remove last entry from timeline
    if (timeline.isNotEmpty) timeline.removeAt(0);
    _submittedBalls.clear(); // so ball can be submitted again

    // Re-fetch live score
    final fresh = await _fetchCurrentScoreData();
    if (fresh != null) {
      _parseCurrentScore(fresh);
    }
    await _refreshBowlerOversFromScorecard();
    // Reset used lists
    _usedBatsmen.clear();
    _usedBowlers.clear();
    _dismissedBatters.clear();
    _isScoringDisabled = false;

    final inningScore = fresh?['current_score']?['current_inning'];
    final batsmen = inningScore?['batting_score'] ?? [];
    final bowlers = inningScore?['bowling_score'] ?? [];
    final outPlayers = fresh?['current_score']?['current_inning']?['score']?['out_players'] ?? [];

    for (final b in batsmen) {
      final id = int.tryParse(b['player_id'].toString());
      if (id != null) _usedBatsmen.add(id);
    }

    for (final b in bowlers) {
      final id = int.tryParse(b['player_id'].toString());
      if (id != null) _usedBowlers.add(id);
    }

    for (final p in outPlayers) {
      final id = int.tryParse(p.toString());
      if (id != null) _dismissedBatters.add(id);
    }

    Provider.of<MatchState>(context, listen: false).updateScore(
      matchId: widget.matchId,
      runs: runs,
      wickets: wickets,
      over: overNumber,
      ball: ballNumber,
    );

    _resetInputs();
    _refreshLastSixBalls();
    setState(() {});
  }


  Future<void> _handleEndInning() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    try {
      final success = await MatchScoreService.endInning(
        matchId: widget.matchId,
        token: widget.token,
      );

      if (!success) {
        _showError('Failed to end innings ❌');
        return;
      }

      // Refresh match meta
      final ok = await _fetchMatchDetails();
      if (!ok) {
        _showError('Failed to refresh match details after ending innings.');
        return;
      }

      // Reload squads
      await _loadSquads();

      // Reset for 2nd innings
      _startSecondInning();
      setState(() {
        overNumber = 0;
        ballNumber = 1;
        runs = 0;
        wickets = 0;
        timeline = ['2nd innings started'];
      });

      // Select striker/non-striker/bowler (UI prompt)
      Future.delayed(const Duration(milliseconds: 300), _selectInitialSecondInningPlayers);

      // Immediately refresh score page from server
      Map<String, dynamic>? refreshed;
      for (int i = 0; i < 3; i++) {
        refreshed = await _fetchCurrentScoreData();
        if (refreshed != null) break;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (refreshed != null) {
        _parseCurrentScore(refreshed, overridePlayers: false);
        await _refreshBowlerOversFromScorecard();
        setState(() {});
      }
      _refreshLastSixBalls(delayMs: 120);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2nd Innings started ✅')),
      );
    } catch (e) {
      _showError('Error ending innings: $e');
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }


  int _parseInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<int?> _showExtraRunDialog(String title, String prefix) async {
    final controller = TextEditingController();

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(7, (i) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, i),
                    child: Text('$prefix + $i'),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("Custom:"),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: "Enter runs",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final val = int.tryParse(controller.text);
                      if (val != null) Navigator.pop(context, val);
                    },
                    child: const Text("OK"),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }



  Future<bool> _fetchMatchDetails() async {
    try {
      final uri = Uri.parse(
        'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-cricket-match'
            '?api_logged_in_token=${widget.token}&match_id=${widget.matchId}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        debugPrint('get-single-cricket-match HTTP ${res.statusCode}');
        return false;
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] != 1) {
        debugPrint('get-single-cricket-match status != 1 -> $body');
        return false;
      }

      final dataList = body['data'];
      if (dataList is! List || dataList.isEmpty) {
        debugPrint('get-single-cricket-match data empty');
        return false;
      }
      final data = dataList.first as Map<String, dynamic>;

      int toInt(dynamic v) {
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 0;
        return 0;
      }

      List<int> parseXI(dynamic raw) {
        if (raw == null) return [];
        if (raw is String) {
          if (raw.trim().isEmpty) return [];
          return raw
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 0)
              .where((e) => e > 0)
              .toList();
        }
        if (raw is List) {
          return raw.map((e) => toInt(e)).where((e) => e > 0).toList();
        }
        return [];
      }

      final matchNameLocal           = data['match_name']?.toString();
      final teamOneIdLocal           = toInt(data['team_one']);
      final teamTwoIdLocal           = toInt(data['team_two']);
      final teamOne11Local           = parseXI(data['team_one_11']);
      final teamTwo11Local           = parseXI(data['team_two_11']);
      final firstInningTeamIdLocal   = toInt(data['first_inning']);
      final firstInningClosedLocal   = toInt(data['is_first_inning_closed']) == 1;
      final matchOversLocal          = toInt(data['match_overs']);
      final bowlerMaxOversLocal      = toInt(data['ballers_max_overs']);

      // Pick current batting team name for UI
      final teamOneName = data['team_one_name']?.toString() ?? '';
      final teamTwoName = data['team_two_name']?.toString() ?? '';

      final currentBattingTeamId = !firstInningClosedLocal
          ? firstInningTeamIdLocal
          : (firstInningTeamIdLocal == teamOneIdLocal ? teamTwoIdLocal : teamOneIdLocal);
      final teamNameLocal = currentBattingTeamId == teamOneIdLocal ? teamOneName : teamTwoName;

      if (!mounted) return false;
      setState(() {
        matchName        = matchNameLocal;
        _teamOneId       = teamOneIdLocal;
        _teamTwoId       = teamTwoIdLocal;
        _teamOne11       = teamOne11Local;
        _teamTwo11       = teamTwo11Local;
        _firstInningTeamId = firstInningTeamIdLocal;
        _firstInningClosed = firstInningClosedLocal;
        _matchOvers      = matchOversLocal;
        _bowlerMaxOvers  = bowlerMaxOversLocal;

        _teamOneName     = teamOneName;
        _teamTwoName     = teamTwoName;

        teamName         = teamNameLocal;
      });

      debugPrint('match: $matchName, team1=$_teamOneId (${_teamOne11.length}), '
          'team2=$_teamTwoId (${_teamTwo11.length}), firstInning=$_firstInningTeamId, '
          'closed=$_firstInningClosed, overs=$_matchOvers, maxBowler=$_bowlerMaxOvers');

      return true;
    } catch (e, st) {
      debugPrint('fetchMatchDetails error: $e\n$st');
      return false;
    }
  }

  Future<void> _loadSquads() async {
    if (_teamOneId == null || _teamTwoId == null || _firstInningTeamId == null) {
      _showError("Match details not available for squads.");
      debugPrint('🚫 Missing IDs → team1=$_teamOneId, team2=$_teamTwoId, firstInning=$_firstInningTeamId');
      return;
    }

    // Decide who bats/bowls in the CURRENT inning
    final battingTeamId = !_firstInningClosed
        ? _firstInningTeamId!
        : (_firstInningTeamId == _teamOneId ? _teamTwoId! : _teamOneId!);
    final bowlingTeamId = battingTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!;

    final battingIds = battingTeamId == _teamOneId! ? _teamOne11 : _teamTwo11;
    final bowlingIds = bowlingTeamId == _teamOneId! ? _teamOne11 : _teamTwo11;

    debugPrint('🧠 Inning=${_firstInningClosed ? "2nd" : "1st"} '
        '| BattingTeamID=$battingTeamId | BowlingTeamID=$bowlingTeamId');
    debugPrint('📋 Batting XI IDs  : ${battingIds.join(",")}');
    debugPrint('📋 Bowling XI IDs  : ${bowlingIds.join(",")}');

    try {
      final t1 = await PlayerService.fetchTeamPlayers(teamId: _teamOneId!, apiToken: widget.token);
      final t2 = await PlayerService.fetchTeamPlayers(teamId: _teamTwoId!, apiToken: widget.token);

      _team1Squad = t1
          .map<Map<String, dynamic>>((p) {
        final id = int.tryParse('${p['ID']}') ?? 0;
        return {'id': id, 'name': p['display_name'] as String};
      })
          .where((p) => p['id'] > 0)
          .toList();

      _team2Squad = t2
          .map<Map<String, dynamic>>((p) {
        final id = int.tryParse('${p['ID']}') ?? 0;
        return {'id': id, 'name': p['display_name'] as String};
      })
          .where((p) => p['id'] > 0)
          .toList();

      debugPrint('🧍 Team1 squad fetched = ${_team1Squad.length}, Team2 squad fetched = ${_team2Squad.length}');

      final fullBattingSquad = battingTeamId == _teamOneId! ? _team1Squad : _team2Squad;
      final fullBowlingSquad = bowlingTeamId == _teamOneId! ? _team1Squad : _team2Squad;

      final mappedBatting = fullBattingSquad.where((p) => battingIds.contains(p['id'] as int)).toList();
      final mappedBowling = fullBowlingSquad.where((p) => bowlingIds.contains(p['id'] as int)).toList();

      debugPrint('✅ Final battingSidePlayers  = ${mappedBatting.length}');
      debugPrint('✅ Final bowlingSidePlayers  = ${mappedBowling.length}');

      setState(() {
        _battingSidePlayers = mappedBatting;
        _bowlingSidePlayers = mappedBowling;
      });

      if (_battingSidePlayers.isEmpty) {
        debugPrint('⚠️ Empty battingSidePlayers. Check team_11 values & player IDs.');
      }
    } catch (e, st) {
      _showError("Failed to load squads");
      debugPrint('❌ Error loading squads: $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> _fetchCurrentScoreData() async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-current-match-score'
          '?match_id=${widget.matchId}',
    );
    final res = await http.get(uri);
    final body = json.decode(res.body);
    if (body['status'] != 1 || body['current_score'] == null) return null;
    return body;
  }
  void _checkMatchResult(Map<String, dynamic> scoreData) {
    final cs = scoreData['current_score'];
    final firstInning = cs?['first_inning'];
    final currentInning = cs?['current_inning']?['score'];

    if (firstInning == null || currentInning == null) return;

    final teamAId = firstInning['team_id'];
    final teamAName = firstInning['team_name']?.toString() ?? 'Team A';
    final teamAScore = int.tryParse(firstInning['score']?['total_runs'].toString() ?? '') ?? 0;

    final teamBId = cs?['current_inning']?['team_id'];
    final teamBName = cs?['current_inning']?['team_name']?.toString() ?? 'Team B';
    final teamBScore = int.tryParse(currentInning['total_runs'].toString()) ?? 0;
    final teamBWickets = int.tryParse(currentInning['total_wkts'].toString()) ?? 0;

    // Only proceed if it's second innings
    if (teamAId == null || teamBId == null || teamAId == teamBId) return;

    final target = teamAScore + 1;

    if (teamBScore >= target) {
      final remainingWickets = 10 - teamBWickets;
      _showMatchEndDialog("🎉 $teamBName won by $remainingWickets wicket(s)");
      _isScoringDisabled = true;
      return;
    }

    if (teamBWickets >= 10 && teamBScore < target) {
      final margin = target - 1 - teamBScore;
      _showMatchEndDialog("🏆 $teamAName won by $margin run(s)");
      _isScoringDisabled = true;
      return;
    }

    if (teamBWickets >= 10 && teamBScore == target - 1) {
      _showMatchEndDialog("🤝 Match Tied");
      _isScoringDisabled = true;
      return;
    }
  }

  final Map<int, Map<String, dynamic>> _bowlerStatsMap = {};

  void _parseCurrentScore(Map<String, dynamic> body, {bool overridePlayers = true}) {
    debugPrint('🔄 _parseCurrentScore called');

    final csRoot = body['current_score'] as Map<String, dynamic>?;
    if (csRoot == null) {
      debugPrint('⚠️ No current_score in response');
      return;
    }
    final inning = csRoot['current_inning'] as Map<String, dynamic>?;
    if (inning == null || inning['score'] == null) {
      debugPrint('⚠️ No current_inning/score');
      return;
    }
    final cs = inning['score'] as Map<String, dynamic>;

    // Build a map of all bowlers’ stats from bowling_score
    _bowlerStatsMap.clear();
    final bowlingList = inning['bowling_score'] as List<dynamic>? ?? [];
    for (final b in bowlingList) {
      final pid = _parseInt(b['player_id']);
      final data = b['data'] as Map<String, dynamic>? ?? {};
      _bowlerStatsMap[pid] = {
        'runs'   : _parseInt(data['runs']),
        'wickets': _parseInt(data['wickets']),
        'maiden' : _parseInt(data['maiden']),
        'overs'  : data['overs']?.toString() ?? '0',
        'econ'   : double.tryParse(data['economy'].toString()) ?? 0.0,
      };
    }

    // Also add the current bowler from cs['bowler']
    final bwSingle = cs['bowler'] as Map<String, dynamic>?;
    if (bwSingle != null) {
      final pid = _parseInt(bwSingle['id']);
      final data = bwSingle['data'] as Map<String, dynamic>? ?? {};
      _bowlerStatsMap[pid] = {
        'runs'   : _parseInt(data['runs']),
        'wickets': _parseInt(data['wickets']),
        'maiden' : _parseInt(data['maiden']),
        'overs'  : data['overs']?.toString() ?? '0',
        'econ'   : double.tryParse(data['economy'].toString()) ?? 0.0,
      };
    }

    // Parse completed overs & balls, normalizing 6+ balls
    int doneOvers = _parseInt(cs['overs_done']);
    int doneBalls = _parseInt(cs['balls_done']);
    if (doneBalls >= 6) {
      final extra = doneBalls ~/ 6;
      doneOvers += extra;
      doneBalls = doneBalls % 6;
    }
    final totalBalls = doneOvers * 6 + doneBalls;

    // Rebuild submittedBalls set
    _submittedBalls.clear();
    for (int i = 0; i < totalBalls; i++) {
      final o = i ~/ 6, b = (i % 6) + 1;
      _submittedBalls.add('$o.$b');
    }

    final nextBall   = (doneBalls % 6) + 1;
    final overAdjust = (doneBalls % 6 == 0 && doneBalls > 0) ? 1 : 0;
    final nextOver   = doneOvers + overAdjust;

    // Grab striker/non-striker
    final on  = cs['on_strike']  as Map<String, dynamic>?;
    final non = cs['non_strike'] as Map<String, dynamic>?;

    if (!mounted) return;
    setState(() {
      runs           = _parseInt(cs['total_runs']);
      wickets        = _parseInt(cs['total_wkts']);
      totalExtras    = _parseInt(cs['total_extra']);
      currentRunRate = double.tryParse(cs['current_run_rate'].toString()) ?? 0.0;

      // Use next delivery values to avoid duplicate submission error
      overNumber = nextOver;
      ballNumber = nextBall;

      _isScoringDisabled = wickets >= 10;

      // First-innings total
      final firstScore = csRoot['first_inning']?['score'] as Map<String, dynamic>?;
      if (_firstInningClosed && firstScore != null) {
        _firstInningScore = _parseInt(firstScore['total_runs']);
      }

      if (overridePlayers) {
        if (on != null) {
          onStrikePlayerId = _parseInt(on['id']);
          onStrikeName     = on['name']?.toString();
          onStrikeRuns     = _parseInt(on['runs']);
        }
        if (non != null) {
          nonStrikePlayerId = _parseInt(non['id']);
          nonStrikeName     = non['name']?.toString();
          nonStrikeRuns     = _parseInt(non['runs']);
        }
        if (bwSingle != null) {
          final sid = _parseInt(bwSingle['id']);
          bowlerId   = sid;
          bowlerName = bwSingle['name']?.toString();
          final stats = _bowlerStatsMap[sid]!;
          bowlerRunsConceded = stats['runs'] as int;
          bowlerWickets      = stats['wickets'] as int;
          bowlerMaidens      = stats['maiden'] as int;
          bowlerOversBowled  = stats['overs'] as String;
          bowlerEconomy      = stats['econ'] as double;
        }
      }

      final tl = inning['timeline'] as List<dynamic>?;
      if (tl != null && tl.isNotEmpty) {
        timeline = tl
            .map((e) => e.toString())
            .where((s) => RegExp(r'^\d+\.\d+:').hasMatch(s))
            .toList();
      } else {
        timeline = ['Loaded: $runs–$wickets at $doneOvers.$doneBalls'];
      }

      if (_firstInningClosed) {
        final target    = _firstInningScore + 1;
        final runsLeft  = target - runs;
        final ballsLeft = (_matchOvers * 6) - (doneOvers * 6 + doneBalls);
        requiredRunRate = ballsLeft > 0 ? runsLeft / (ballsLeft / 6) : 0.0;

        if (runs >= target && (wickets < 10 || ballsLeft > 0)) {
          matchResultStatus = '';
          matchResultColor  = Colors.transparent;
        } else if (runs >= target) {
          matchResultStatus = '🏆 Match Won!';
          matchResultColor  = Colors.green;
        } else if (wickets >= 10 || ballsLeft == 0) {
          if (runs == _firstInningScore) {
            matchResultStatus = '🤝 Match Tied';
            matchResultColor  = Colors.orange;
          } else {
            matchResultStatus = '❌ Match Lost';
            matchResultColor  = Colors.red;
          }
        } else if (runsLeft <= 10 && ballsLeft <= 6) {
          isCloseMatch = true;
        }
      }
    });
  }

  /// ------------- SUBMIT SCORE (logic preserved; UI-only polish) -------------
  Future<void> _submitScore() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    try {
      debugPrint('🔄 Submitting score for ball $overNumber.$ballNumber');

      if (_isScoringDisabled) {
        _showError('🛑 Team already won.');
        return;
      }

      // Check innings completion via API
      final current = await _fetchCurrentScoreData();
      if (current != null) {
        final cs = current['current_score']?['current_inning']?['score'];
        final doneOvers  = _parseInt(cs?['overs_done']);
        final doneBalls  = _parseInt(cs?['balls_done']);
        final totalBalls = doneOvers * 6 + doneBalls;
        final maxBalls   = _matchOvers * 6;
        if (totalBalls >= maxBalls) {
          _showError('🚫 Innings already completed.');
          _showMatchEndDialog("Innings Over - $_matchOvers Overs Completed");
          return;
        }
      }

      if (onStrikePlayerId == null || nonStrikePlayerId == null || bowlerId == null) {
        _showError('Please select striker, non-striker, and bowler');
        return;
      }

      // Compute runs & extras...
      int batterRuns = 0, extraRuns = 0;
      String extraType = '0';
      bool legalDelivery = true;
      if (selectedExtra != null) {
        extraType = selectedExtra!;
        switch (selectedExtra) {
          case 'Wide':
            extraRuns = selectedRuns ?? 1;
            legalDelivery = false;
            break;
          case 'No Ball':
            batterRuns = selectedRuns ?? 0;
            extraRuns = 0;
            legalDelivery = false;
            _isFreeHit = true;
            break;
          case 'Bye':
          case 'Leg Bye':
            extraRuns = selectedRuns ?? 0;
            legalDelivery = true;
            break;
          default:
            batterRuns = selectedRuns ?? 0;
        }
      } else {
        batterRuns = selectedRuns ?? 0;
      }

      // Handle wicket
      bool wicketFalls = isWicket;

      if (wicketType == 'Retired Hurt' || wicketType == 'Absent Hurt') {
        wicketFalls = false;
      }

      if (_isFreeHit && wicketType != 'Run Out') {
        wicketFalls = false;
      }

      if (wicketFalls) wickets++;

      // Map to API names
      final formattedWicketType = wicketFalls ? (kWicketTypeMap[wicketType] ?? '0') : null;

      int? outPlayerId;
      int? runOutBy, catchBy;
      bool? outAtStriker;

      // NEW: per-ball wicketkeeper override (does NOT alter team default)
      int? wicketKeeperForThisBall;

      if (wicketFalls && formattedWicketType != null) {
        switch (formattedWicketType) {
          case 'Run Out':
          case 'Mankaded':
            final choice = await showDialog<OutBatsman>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Which batsman was run out?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: OutBatsman.values.map((o) {
                    return RadioListTile<OutBatsman>(
                      title: Text(o == OutBatsman.striker ? 'Striker' : 'Non-Striker'),
                      value: o, groupValue: null,
                      onChanged: (v) => Navigator.pop(ctx, v),
                    );
                  }).toList(),
                ),
              ),
            );
            outAtStriker = (choice ?? OutBatsman.striker) == OutBatsman.striker;
            outPlayerId  = outAtStriker ? onStrikePlayerId! : nonStrikePlayerId!;

            runOutBy = await _pickBowlingSidePlayer(title: 'Who effected the run out?');
            if (runOutBy == null) { _showError('Please select the fielder for Run Out'); return; }
            break;

          case 'Caught':
            outAtStriker = true; outPlayerId = onStrikePlayerId!;
            catchBy = await _pickBowlingSidePlayer(title: 'Who took the catch?');
            if (catchBy == null) { _showError('Please select the catcher'); return; }
            break;

          case 'Caught Behind':
            outAtStriker = true; outPlayerId = onStrikePlayerId!;
            final pickedKeeperId = await _pickBowlingSidePlayer(
              title: 'Select wicketkeeper (Caught Behind)',
            );
            catchBy = pickedKeeperId ?? _currentWicketKeeperId;
            wicketKeeperForThisBall = catchBy;
            if (catchBy == null) { _showError('Please select the wicketkeeper'); return; }
            break;

          case 'Caught and Bowled':
            outAtStriker = true; outPlayerId = onStrikePlayerId!;
            catchBy = bowlerId;
            break;

          case 'Stumped':
            outAtStriker = true; outPlayerId = onStrikePlayerId!;
            final pickedKeeperId = await _pickBowlingSidePlayer(
              title: 'Who did the stumping (WK)?',
            );
            catchBy = pickedKeeperId ?? _currentWicketKeeperId;
            wicketKeeperForThisBall = catchBy;
            if (catchBy == null) { _showError('Please select the wicketkeeper'); return; }
            break;

          default:
            outAtStriker = true;
            outPlayerId  = onStrikePlayerId!;
            break;
        }
      }

      // CREDIT runs to the current striker BEFORE any swap
      if (!wicketFalls && batterRuns > 0) {
        onStrikeRuns += batterRuns;
      }

      final int submitStrikerId    = onStrikePlayerId!;
      final int submitNonStrikerId = nonStrikePlayerId!;

      final bool isEndOfOver = ballNumber == 6;
      final bool oddRun      = batterRuns.isOdd;

      if (selectedExtra == 'Wide' || selectedExtra == 'Bye' || selectedExtra == 'Leg Bye') {
        if (extraRuns.isOdd) {
          _swapStrike();
        }
      }

      if (selectedExtra == 'No Ball' && oddRun) {
        _swapStrike();
      }

      if (legalDelivery && !wicketFalls) {
        if (oddRun) {
          _swapStrike();
        }
        if (isEndOfOver) {
          _swapStrike();
        }
      }
      if (!_usedBatsmen.contains(submitStrikerId)) {
        _usedBatsmen.add(submitStrikerId);
      }

      final req = MatchScoreRequest(
        matchId: widget.matchId,
        battingTeamId: !_firstInningClosed
            ? _firstInningTeamId!
            : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!),
        onStrikePlayerId: submitStrikerId,
        onStrikePlayerOrder: 1,
        nonStrikePlayerId: submitNonStrikerId,
        nonStrikePlayerOrder: 2,
        bowler: bowlerId!,
        overNumber: overNumber + 1,
        ballNumber: ballNumber,
        runs: batterRuns,

        // extras
        extraRunType: extraType,
        extraRun: extraRuns > 0 ? extraRuns : null,

        // wicket payload
        outPlayer: wicketFalls ? outPlayerId : null,
        isWicket: wicketFalls ? 1 : 0,
        wicketType: formattedWicketType,
        runOutBy: runOutBy,
        catchBy: catchBy,

        // per-ball WK override (falls back to team default if null)
        wktkprId: wicketKeeperForThisBall ?? _currentWicketKeeperId,
        shot: _selectedShotType,
      );

      final success = await MatchScoreService.submitScore(req, widget.token, context);
      if (!success) { _showError('❌ Failed to submit score.'); return; }

      _submittedBalls.add('$overNumber.$ballNumber');
      timeline.insert(0,
          '$overNumber.$ballNumber: '
              '${selectedExtra != null ? "$selectedExtra +${selectedRuns ?? 0}" : "$selectedRuns"}'
              '${wicketFalls ? " 🧨 Wicket($wicketType)" : ""}'
      );

      if (legalDelivery) {
        _usedBowlers.add(bowlerId!);
        _advanceBall();
      }

      if (wicketFalls) {
        await _showBatsmanSelectionAfterWicket(selectForStriker: outAtStriker ?? true);
        if (isEndOfOver) _swapStrike();
      }

      _isFreeHit = false;
      selectedRuns = null;
      selectedExtra = null;
      isWicket = false;
      wicketType = null;

      Provider.of<MatchState>(context, listen: false).updateScore(
        matchId: widget.matchId,
        runs: runs, wickets: wickets,
        over: overNumber, ball: ballNumber,
      );
      final refreshed = await _fetchCurrentScoreData();
      if (refreshed != null) {
        _parseCurrentScore(refreshed, overridePlayers: false);
        await _refreshBowlerOversFromScorecard();
        _checkMatchResult(refreshed);
        setState(() {});
      }
      _refreshLastSixBalls(delayMs: 120);

    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  void _showMatchEndDialog(
      String message, {
        List<Map<String, dynamic>>? teams,
        int? matchIdOverride,
        String? tokenOverride,
      }) {
    final isTie = message.toLowerCase().contains('tie');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.emoji_events, size: 22),
            SizedBox(width: 8),
            Text('Match Result'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),

          if (teams != null)
            ElevatedButton(
              child: const Text('End Match'),
              onPressed: () async {
                Navigator.pop(context); // close this result dialog

                final newMatchId = await showEndMatchDialog(
                  context: context,
                  matchId: matchIdOverride ?? widget.matchId,
                  token: tokenOverride ?? widget.token,
                  teams: teams,
                );

                if (!mounted) return;

                if (newMatchId != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddScoreScreen(
                        matchId: newMatchId,
                        token: tokenOverride ?? widget.token,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Match ended')),
                  );
                }
              },
            ),

          if (isTie && teams != null)
            ElevatedButton(
              child: const Text('Start Super Over'),
              onPressed: () async {
                Navigator.pop(context); // close this result dialog

                final newMatchId = await showEndMatchDialog(
                  context: context,
                  matchId: matchIdOverride ?? widget.matchId,
                  token: tokenOverride ?? widget.token,
                  teams: teams,
                );
                if (!mounted) return;

                if (newMatchId != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddScoreScreen(
                        matchId: newMatchId,
                        token: tokenOverride ?? widget.token,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No Super Over started')),
                  );
                }
              },
            ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullMatchDetail(
                    matchId: matchIdOverride ?? widget.matchId,
                  ),
                ),
              );
            },
            child: const Text('View Match'),
          ),
        ],
      ),
    );
  }
  Future<void> _onUpdateYoutubePressed() async {
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(text: _youtubeUrl ?? '');

    String? validate(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return 'Paste a YouTube URL';
      final ok = s.contains('youtu.be') || s.contains('youtube.com');
      return ok ? null : 'Enter a valid YouTube link';
    }

    final newUrl = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update YouTube Link'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            validator: validate,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'YouTube URL',
              hintText: 'https://youtu.be/... or https://www.youtube.com/watch?v=...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newUrl == null) return;

    final resp = await MatchYoutubeService.updateYoutube(
      apiToken: widget.token,
      matchId: widget.matchId,
      youtubeUrl: newUrl,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.message), backgroundColor: resp.ok ? Colors.green : Colors.red),
    );

    if (resp.ok) {
      setState(() => _youtubeUrl = newUrl);
      await _fetchMatchDetails();
    }
  }


  void _advanceBall() {
    final isEndOfOver = ballNumber == 6;

    if (isEndOfOver) {
      overNumber++;
      ballNumber = 1;

      if (bowlerId != null) {
        final current = _bowlerOversMap[bowlerId!] ?? 0.0;
        _bowlerOversMap[bowlerId!] = current.floor().toDouble() + 1.0;

        _lastBowlerId = bowlerId;

        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_over_bowler_${widget.matchId}', bowlerId!);
        }();
      }

      Future.delayed(const Duration(milliseconds: 100), _showBowlerSelectionAfterOver);
    } else {
      ballNumber++;
    }

    setState(() {});
  }


  Future<String?> showPlayerChangeReasonDialog(BuildContext context) async {
    final reasons = [
      'Retired Hurt',
      'Tactical Change',
      'Injury Substitution',
      'Out of form',
      'Other',
    ];

    String? selectedReason;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reason for Player Change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) {
            return RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: selectedReason,
              onChanged: (value) {
                selectedReason = value;
                Navigator.of(context).pop(value);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
  void _swapStrike() {
    final tmpId    = onStrikePlayerId;
    final tmpName  = onStrikeName;
    final tmpRuns  = onStrikeRuns;
    final tmpBalls = onStrikeBalls;

    onStrikePlayerId = nonStrikePlayerId;
    onStrikeName     = nonStrikeName;
    onStrikeRuns     = nonStrikeRuns;
    onStrikeBalls    = nonStrikeBalls;

    nonStrikePlayerId = tmpId;
    nonStrikeName     = tmpName;
    nonStrikeRuns     = tmpRuns;
    nonStrikeBalls    = tmpBalls;

    setState(() {});
  }


  void _resetInputs()
  {
    selectedRuns = null;
    selectedExtra = null;
    isWicket = false;
    wicketType = null;
  }

  void _showBowlerSelectionAfterOver() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSelectPlayerSheet(isBatsman: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Over completed. Please select a new bowler.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.teal,
        ),
      );
    }
    );
  }
  void _refreshLastSixBalls({int delayMs = 0}) {
    if (!mounted) return;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _lastSixBallsRefresher.notifyListeners();
    });
  }

  /// Replacement flow
  Future<void> _showBatsmanSelectionAfterWicket({ bool? selectForStriker }) async {
    if (!mounted) return;
    final wt = wicketType;

    // Retired/Absent Hurt → NOT OUT, replace batter (does not submit ball)
    if (wt == 'Retired Hurt' || wt == 'Absent Hurt') {
      OutBatsman? retiredChoice = await showDialog<OutBatsman>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Which batsman ${wt == 'Absent Hurt' ? 'is absent' : 'retired hurt'}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: OutBatsman.values.map((o) {
              return RadioListTile<OutBatsman>(
                title: Text(o == OutBatsman.striker ? 'Striker' : 'Non-Striker'),
                value: o,
                groupValue: null,
                onChanged: (v) => Navigator.pop(ctx, v),
              );
            }).toList(),
          ),
        ),
      );

      retiredChoice ??= OutBatsman.striker;
      final replaceAtStriker = (retiredChoice == OutBatsman.striker);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${replaceAtStriker ? (onStrikeName ?? "Striker") : (nonStrikeName ?? "Non-striker")} ${wt == "Absent Hurt" ? "absent" : "retired hurt"}. Select replacement.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

      final newId = await Future.delayed(
        const Duration(milliseconds: 150),
            () => _showSelectPlayerSheet(isBatsman: true, selectForStriker: replaceAtStriker),
      );
      if (newId == null) return;

      final player = _battingSidePlayers.firstWhere((p) => p['id'] == newId);
      final name   = (player['display_name'] ?? player['name'] ?? '').toString();

      setState(() {
        if (replaceAtStriker) {
          onStrikePlayerId = newId;
          onStrikeName     = name;
          onStrikeRuns     = 0;
          onStrikeBalls    = 0;
        } else {
          nonStrikePlayerId = newId;
          nonStrikeName     = name;
          nonStrikeRuns     = 0;
          nonStrikeBalls    = 0;
        }
        isWicket   = false;
        wicketType = null;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$name comes in (replacement for $wt)'), backgroundColor: Colors.green.shade600),
        );

      return;
    }

    final isRunOut = wt == 'Run Out' || wt == 'Run Out (Mankaded)';
    if (isRunOut && selectForStriker == null) {
      final outChoice = await showDialog<OutBatsman>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Which batsman was run out?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: OutBatsman.values.map((o) {
              return RadioListTile<OutBatsman>(
                title: Text(o == OutBatsman.striker ? 'Striker' : 'Non-Striker'),
                value: o,
                groupValue: null,
                onChanged: (v) => Navigator.pop(ctx, v),
              );
            }).toList(),
          ),
        ),
      );
      if (outChoice != null) {
        selectForStriker = (outChoice == OutBatsman.striker);
      }
    }

    selectForStriker ??= true;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Batsman out. Please select replacement.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );

    final newId = await Future.delayed(
      const Duration(milliseconds: 150),
          () => _showSelectPlayerSheet(
        isBatsman: true,
        selectForStriker: selectForStriker,
      ),
    );
    if (newId == null) return;

    final player = _battingSidePlayers.firstWhere((p) => p['id'] == newId);
    final name   = (player['display_name'] ?? player['name'] ?? '').toString();
    setState(() {
      if (selectForStriker == true) {
        onStrikePlayerId = newId;
        onStrikeName     = name;
        onStrikeRuns     = 0;
        onStrikeBalls    = 0;
      } else {
        nonStrikePlayerId = newId;
        nonStrikeName     = name;
        nonStrikeRuns     = 0;
        nonStrikeBalls    = 0;
      }
      isWicket   = false;
      wicketType = null;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name added to batting.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
  }



  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }


  String _formatOversDisplayFromDouble(double ob) {
    final completed = ob.floor();
    final balls = ((ob - completed) * 6).round().clamp(0, 5);
    return '$completed.$balls';
  }

  int _completedOversFromDouble(double ob) => ob.floor();

  Future<int?> _showSelectPlayerSheet({
    required bool isBatsman,
    bool? selectForStriker, // true = striker, false = non-striker, null = auto/ask
  }) async {
    final all = isBatsman ? _battingSidePlayers : _bowlingSidePlayers;

    if (isBatsman) {
      final available = all.where((p) {
        final id = p['id'] as int;
        if (_usedBatsmen.contains(id)) return false;
        if (_dismissedBatters.contains(id)) return false;
        return true;
      }).toList();

      if (available.isEmpty) {
        _showError("No more batsmen available to select.");
        return null;
      }
      return await _buildPlayerSheet(available, isBatsman, selectForStriker);
    }

    try {
      await _refreshBowlerOversFromScorecard();
      await _updateLastCompletedOverBowler();
    } catch (_) {}

    final available = all
        .where((p) => (p['id'] as int) != _lastBowlerId)
        .toList()
      ..sort((a, b) {
        final ao = _bowlerOversMap[(a['id'] as int)] ?? 0.0;
        final bo = _bowlerOversMap[(b['id'] as int)] ?? 0.0;
        return ao.compareTo(bo);
      });

    if (available.isEmpty) {
      _showError("No more bowlers available to select.");
      return null;
    }

    return await _buildPlayerSheet(available, isBatsman, selectForStriker);
  }

  Future<int?> _buildPlayerSheet(
      List<Map<String, dynamic>> available,
      bool isBatsman,
      bool? selectForStriker,
      ) async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          color: Theme.of(context).canvasColor,
          height: 460,
          child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (_, i) {
              final p = available[i];
              final id = p['id'] as int;
              final name = (p['name'] ?? p['display_name'] ?? p['user_login'] ?? 'Unnamed').toString();

              if (!isBatsman) {
                final ob = _bowlerOversMap[id] ?? 0.0;
                final displayOvers = _formatOversDisplayFromDouble(ob);
                final completed = _completedOversFromDouble(ob);
                final hasQuota = _bowlerMaxOvers <= 0 ? true : completed < _bowlerMaxOvers;
                final consecutiveBlocked = (_lastBowlerId != null && id == _lastBowlerId);

                return ListTile(
                  leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                  title: Text(name),
                  subtitle: Text('$displayOvers / $_bowlerMaxOvers.0 overs'),
                  enabled: !consecutiveBlocked && hasQuota,
                  onTap: () {
                    if (!hasQuota) {
                      _showError('Bowler has reached the maximum overs.');
                      return;
                    }
                    if (consecutiveBlocked) {
                      _showError('Same bowler cannot bowl consecutive overs.');
                      return;
                    }

                    bowlerId = id;
                    bowlerName = name;

                    final stats = _bowlerStatsMap[id];
                    if (stats != null) {
                      bowlerRunsConceded = (stats['runs'] as int?) ?? 0;
                      bowlerWickets      = (stats['wickets'] as int?) ?? 0;
                      bowlerMaidens      = (stats['maiden'] as int?) ?? 0;
                      bowlerOversBowled  = (stats['overs']?.toString()) ?? displayOvers;
                      bowlerEconomy      = (stats['econ'] as double?) ?? 0.0;
                    } else {
                      bowlerRunsConceded = 0;
                      bowlerWickets      = 0;
                      bowlerMaidens      = 0;
                      bowlerOversBowled  = displayOvers;
                      bowlerEconomy      = 0.0;
                    }

                    setState(() {});
                    Navigator.pop(context, id);
                  },
                );
              }

              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                title: Text(name),
                onTap: () {
                  if (selectForStriker == true && id == nonStrikePlayerId) {
                    _showError('This player is already the non-striker.');
                    return;
                  }
                  if (selectForStriker == false && id == onStrikePlayerId) {
                    _showError('This player is already the striker.');
                    return;
                  }

                  if (selectForStriker == true) {
                    onStrikePlayerId = id;
                    onStrikeName     = name;
                    onStrikeRuns     = 0;
                    onStrikeBalls    = 0;
                  } else if (selectForStriker == false) {
                    nonStrikePlayerId = id;
                    nonStrikeName     = name;
                    nonStrikeRuns     = 0;
                    nonStrikeBalls    = 0;
                  } else {
                    if (onStrikePlayerId == null) {
                      onStrikePlayerId = id; onStrikeName = name;
                      onStrikeRuns = 0; onStrikeBalls = 0;
                    } else {
                      if (id == onStrikePlayerId) {
                        _showError('This player is already the striker.');
                        return;
                      }
                      nonStrikePlayerId = id; nonStrikeName = name;
                      nonStrikeRuns = 0; nonStrikeBalls = 0;
                    }
                  }

                  setState(() {});
                  Navigator.pop(context, id);
                },
              );
            },
          ),
        ),
      ),
    );
  }
  Future<void> _updateLastCompletedOverBowler() async {
    try {
      final current = await MatchScoreService.getCurrentScore(widget.matchId, widget.token);
      if (current != null) {
        final inning = current['current_inning'] as Map<String, dynamic>?;
        final lastList = inning?['last_ball_data'] as List<dynamic>?;

        int? serverPrevOverBowler;

        if (lastList != null && lastList.isNotEmpty) {
          for (int i = lastList.length - 1; i >= 0; i--) {
            final m = lastList[i] as Map<String, dynamic>;
            final bn = int.tryParse('${m['ball_number']}') ?? -1;
            if (bn == 6) {
              serverPrevOverBowler = int.tryParse('${m['bowler_id'] ?? m['bowler']}');
              if (serverPrevOverBowler != null && serverPrevOverBowler > 0) break;
            }
          }
        }

        if (serverPrevOverBowler != null && serverPrevOverBowler > 0) {
          _lastBowlerId = serverPrevOverBowler;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_over_bowler_${widget.matchId}', _lastBowlerId!);
          return;
        }
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('last_over_bowler_${widget.matchId}');
    if (saved != null && saved > 0) _lastBowlerId = saved;
  }

  void _goToSuperOver(int newMatchId) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AddScoreScreen(
          matchId: newMatchId,
          token: widget.token,
        ),
      ),
          (route) => false,
    );
  }
  Future<void> _refreshBowlerOversFromScorecard() async {
    if (_teamOneId == null || _teamTwoId == null || _firstInningTeamId == null) return;

    final battingTeamId = !_firstInningClosed
        ? _firstInningTeamId!
        : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!);

    final fieldingTeamId = (battingTeamId == _teamOneId!) ? _teamTwoId! : _teamOneId!;

    final map = await MatchScoreService.fetchBowlerOversFromScorecard(
      matchId: widget.matchId,
      fieldingTeamId: fieldingTeamId,
    );

    setState(() {
      _bowlerOversMap = map;
    });
  }

  // ---------- BEAUTIFIED UI (logic unchanged) ----------
  @override
  Widget build(BuildContext context) {
    if (_teamOneId == null ||
        _teamTwoId == null ||
        _firstInningTeamId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final completedBalls = (overNumber * 6) + (ballNumber - 1);
    final uiOvers = completedBalls ~/ 6;
    final uiBalls = completedBalls % 6;

    final int battingTeamId = !_firstInningClosed
        ? _firstInningTeamId!
        : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: isDark
          ? null
          : const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0F7FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
              title: Text(
                matchName ?? 'Match Score',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  tooltip: 'Pull to refresh',
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _hardRefresh,
                ),
                IconButton(
                  tooltip: 'Update YouTube link',
                  icon: const Icon(Icons.ondemand_video, color: Colors.white),
                  onPressed: _onUpdateYoutubePressed,
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator.adaptive(
            onRefresh: _hardRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              children: [

                // SCORE HEADER
                _GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: AnimatedScoreCard(
                    matchType: matchName ?? 'Match',
                    teamName: teamName,
                    isSecondInnings: _firstInningClosed,
                    runs: runs,
                    wickets: wickets,
                    overs: uiOvers,
                    balls: uiBalls,
                    totalOvers: _matchOvers,
                    targetScore: _firstInningClosed ? _firstInningScore : null,
                  ),
                ),

                const SizedBox(height: 10),

                // PLAYER STATS
                _GlassCard(
                  child: PlayerStatsCard(
                    onStrikeName: onStrikeName,
                    onStrikeRuns: onStrikeRuns,
                    nonStrikeName: nonStrikeName,
                    nonStrikeRuns: nonStrikeRuns,
                    bowlerName: bowlerName,
                    bowlerOvers: bowlerOversBowled,
                    maidens: bowlerMaidens,
                    runsConceded: bowlerRunsConceded,
                    wickets: bowlerWickets,
                    economy: bowlerEconomy,
                    extras: totalExtras,
                    runRate: currentRunRate,
                    onEditBatsman: () => _showSelectPlayerSheet(isBatsman: true, selectForStriker: true),
                    onEditNonBatsman: () => _showSelectPlayerSheet(isBatsman: true, selectForStriker: false),
                    onEditBowler: () => _showSelectPlayerSheet(isBatsman: false),
                    compact: true,
                  ),
                ),

                const SizedBox(height: 10),

                // LAST 6 BALLS
                _GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: (_teamOneId == null || _teamTwoId == null)
                      ? const Center(child: CircularProgressIndicator())
                      : LastSixBallsWidget(
                    key: ValueKey('lsb-${widget.matchId}-$battingTeamId'),
                    matchId: widget.matchId,
                    teamId: battingTeamId,
                    refresher: _lastSixBallsRefresher,
                    autoRefreshEvery: const Duration(seconds: 20),
                  ),
                ),

                const SizedBox(height: 12),

                // SCORING INPUTS
                _GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: ScoringInputs(
                    selectedRuns: selectedRuns,
                    selectedExtra: selectedExtra,
                    isWicket: isWicket,
                    isSubmitting: _isSubmitting,

                    onRunSelected: (r) async {
                      if (_isSubmitting) return;
                      setState(() => selectedRuns = r);

                      if (r > 0) {
                        final Map<String, String>? shot = await showShotTypeDialog(context, r.toString(), 0);
                        if (shot == null) return;
                        setState(() => _selectedShotType = shot['type']);
                      }
                      await _submitScore();
                    },

                    onExtraSelected: (type) async {
                      if (_isSubmitting) return;
                      final run = await _showExtraRunDialog(type, type);
                      if (run == null) return;

                      setState(() {
                        selectedExtra = type;
                        selectedRuns  = run;
                      });

                      if (type == 'No Ball' && run > 0) {
                        final Map<String, dynamic>? shot =
                        await showShotTypeDialog(context, run.toString(), 1);
                        if (shot == null) return;
                        setState(() => _selectedShotType = shot['type']?.toString());
                      }

                      await _submitScore();
                    },

                    onWicketSelected: () async {
                      if (_isSubmitting) return;

                      final res = await WicketTypeDialog.show(context);
                      if (res == null) return;

                      final String type = (res['type'] ?? '').toString();
                      final int runsSel = res['runs'] ?? 0;

                      if (type == 'Retired Hurt' || type == 'Absent Hurt') {
                        setState(() {
                          isWicket     = false;
                          wicketType   = type;
                          selectedRuns = runsSel;
                        });

                        await _showBatsmanSelectionAfterWicket(selectForStriker: null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Batter retired hurt (not out). Wickets unchanged.')),
                        );
                        return;
                      }

                      setState(() {
                        isWicket     = true;
                        wicketType   = type;
                        selectedRuns = runsSel;
                      });
                      await _submitScore();
                    },

                    onSwapStrike: _swapStrike,
                    onUndo: _undoLastBall,
                    onEndInning: _handleEndInning,
                    onEndMatch: () async {
                      if ((_teamOneName == null || _teamOneName!.trim().isEmpty) ||
                          (_teamTwoName == null || _teamTwoName!.trim().isEmpty)) {
                        await _fetchMatchDetails();
                      }

                      final teams = [
                        if (_teamOneId != null)
                          {'team_id': _teamOneId!, 'team_name': (_teamOneName ?? '').trim()},
                        if (_teamTwoId != null)
                          {'team_id': _teamTwoId!, 'team_name': (_teamTwoName ?? '').trim()},
                      ].map((t) {
                        final name = (t['team_name'] as String);
                        return {'team_id': t['team_id'], 'team_name': name.isEmpty ? 'Team ${t['team_id']}' : name};
                      }).toList();

                      final newMatchId = await showEndMatchDialog(
                        context: context,
                        matchId: widget.matchId,
                        token: widget.token,
                        teams: teams,
                      );
                      if (!mounted) return;

                      if (newMatchId != null && newMatchId > 0) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => AddScoreScreen(
                              matchId: newMatchId,
                              token: widget.token,
                            ),
                          ),
                              (route) => false,
                        );
                      } else {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => FullMatchDetail(matchId: widget.matchId),
                          ),
                              (route) => false,
                        );
                      }
                    },
                    onViewMatch: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => FullMatchDetail(matchId: widget.matchId)),
                      );
                    },
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

/// Pretty container used to make the screen look modern without changing logic
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: padding ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101317) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(isDark ? 0.2 : 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
