
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/match_score_model.dart';
import '../service/match_youtube_service.dart';
import '../service/player_service.dart';
import '../service/match_score_service.dart';
import '../service/role_players_service.dart';
import '../theme/color.dart';
import '../utils/score_log.dart';
import '../widget/animated_score_card.dart';
import '../widget/dialog/end_match_dialog.dart';
import '../widget/last_six_balls_widget.dart';
import '../widget/player_stats_card.dart';
import '../widget/scoring_inputs.dart';
import '../widget/shot_type_dialog.dart';
import '../provider/match_state.dart';
import '../widget/wicket_type_dialog.dart';
import 'full_match_detail.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import '../controller/scoring_ui_controller.dart';

// Flip to true only when you want to see verbose logs
const bool kEnableVerboseLogs = false;

void logv(String msg) {
  if (kDebugMode && kEnableVerboseLogs) debugPrint(msg);
}
// Redact token from URLs in logs
String _redactToken(String url) {
  return url.replaceAll(RegExp(r'(api_logged_in_token=)([^&]+)'), r'$1████');
}

/// Pretty full payload logger (URL + BODY)
void logFullSubmit(String url, Map<String, String?> body) {
  if (!kEnableVerboseLogs) return;
  final clean = Map<String, String?>.from(body)
    ..removeWhere((k, v) => v == null || v.toString().isEmpty);

  debugPrint('• [SAVE-SCORE][REQ-POST]');
  debugPrint('  URL  => ${_redactToken(url)}');
  debugPrint('  BODY => ${jsonEncode(clean)}');
}

class Perf {
  static final Map<String, Stopwatch> _sw = {};

  static void start(String tag) {
    _sw[tag] = Stopwatch()..start();
    debugPrint('⏱️ START $tag');
  }

  static void end(String tag) {
    final sw = _sw[tag];
    if (sw == null) return;
    sw.stop();
    debugPrint('⏱️ END   $tag → ${sw.elapsedMilliseconds} ms');
    _sw.remove(tag);
  }
}


// compact one-line submit log
void logBallSubmit(Map<String, String> fields) {
  if (!kDebugMode) return; // avoid release spam

  final payload = <String, String?>{
    'over': fields['over_number'],
    'ball': fields['ball_number'],
    'runs': fields['runs'],
    'extra_type': fields['extra_run_type'],
    'extra': fields['extra_run'],
    'is_wicket': fields['is_wicket'],
    'wicket_type': fields['wicket_type'],
    'out_player': fields['out_player'],
    'run_out_by': fields['run_out_by'],
    'catch_by': fields['catch_by'],

    // 🔻 add these two (and keep striker id)
    'striker': fields['on_strike_player_id'],
    'striker_order': fields['on_strike_player_order'],
    'non_striker': fields['non_strike_player_id'],
    'non_striker_order': fields['non_strike_player_order'],

    'bowler': fields['bowler'],
    'shot': fields['shot'],
  }..removeWhere((k, v) => v == null || v.isEmpty);

  debugPrint('📤 SUBMIT ${fields['over_number']}.${fields['ball_number']} → ${jsonEncode(payload)}');
}


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

  final RegExp _timelineRegex = RegExp(r'^\d+\.\d+:');
  late final ScoringUIController ui;
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
  int _legalBallsInOver = 0;

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
    ui = ScoringUIController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    ui.dispose();
    _lastSixBallsRefresher.dispose();
    super.dispose();
  }


// Batting order tracker (per innings)
  final Map<int, int> _battingOrder = {}; // playerId -> battingOrder (1..11)
  int _nextBattingOrder = 1;

  void _resetBattingOrder() {
    _battingOrder.clear();
    _nextBattingOrder = 1;
  }

  void _assignBattingOrderIfMissing(int playerId) {
    if (playerId <= 0) return;
    if (!_battingOrder.containsKey(playerId)) {
      _battingOrder[playerId] = _nextBattingOrder++;
    }
  }

  Future<void> _init() async {
    try {
      // 1️⃣ FAST + CRITICAL (UI can render after this)
      await _fetchMatchDetails();

      final scoreData = await _fetchCurrentScoreData();
      if (scoreData != null) {
        _parseCurrentScore(scoreData);
      }

      if (mounted) setState(() {}); // 👈 UI COMES UP HERE

      // 2️⃣ HEAVY WORK → BACKGROUND (non-blocking UX)
      unawaited(() async {
        await _loadSquads();
        await _refreshBowlerOversFromScorecard();
        await _updateLastCompletedOverBowler();

        if (!mounted) return;

        // fallback player selection
        if (onStrikePlayerId == null ||
            nonStrikePlayerId == null ||
            bowlerId == null) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _showSelectPlayerSheet(isBatsman: true, selectForStriker: true);
          await _showSelectPlayerSheet(isBatsman: true, selectForStriker: false);
          await _showSelectPlayerSheet(isBatsman: false);
        }

        setState(() {}); // background sync
      }());

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sports_cricket, size: 20),
              const SizedBox(width: 8),
              Expanded( // ← allow the text to wrap instead of overflowing
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
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
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // ← avoid overflow on long names
                  ),
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

    // ---- NEW: Batting-order repair after undo ----
    // Build the set of batters who have actually appeared this innings
    final Set<int> _presentBatters = {
      ..._usedBatsmen,
      ..._dismissedBatters,
      if (onStrikePlayerId != null) onStrikePlayerId!,
      if (nonStrikePlayerId != null) nonStrikePlayerId!,
    };

    // Prune any order entries that belong to now-removed/undone players
    _battingOrder.removeWhere((pid, _) => !_presentBatters.contains(pid));

    // Recompute next order as max(existing)+1 (or 1 if none)
    int maxOrder = 0;
    for (final o in _battingOrder.values) {
      if (o > maxOrder) maxOrder = o;
    }
    _nextBattingOrder = maxOrder + 1;

    // Seed orders for any present batters that are missing
    for (final pid in _presentBatters) {
      _assignBattingOrderIfMissing(pid);
    }
    // ---- END NEW ----

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

      // Reset for 2nd innings (your logic)
      _startSecondInning();

      // NEW: reset batting order numbering for the new innings
      _resetBattingOrder(); // ← ensures orders start from 1 again

      setState(() {
        overNumber = 0;
        ballNumber = 1;
        runs = 0;
        wickets = 0;
        timeline = ['2nd innings started'];
      });

      // Select striker/non-striker/bowler (UI prompt)
      // NEW: after user picks, seed batting orders for the two openers
      Future.delayed(const Duration(milliseconds: 300), () async {
        await _selectInitialSecondInningPlayers();
        if (onStrikePlayerId != null) _assignBattingOrderIfMissing(onStrikePlayerId!);
        if (nonStrikePlayerId != null) _assignBattingOrderIfMissing(nonStrikePlayerId!);
      });

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
  void _applyBowlerStatsFromApi({int? id}) {
    final int? bid = id ?? bowlerId;
    if (bid == null) return;

    final s = _bowlerStatsMap[bid];
    final oversFromMap = _bowlerOversMap[bid];

    if (s == null && oversFromMap == null) return;

    setState(() {
      bowlerRunsConceded = (s?['runs'] as int?) ?? bowlerRunsConceded;
      bowlerWickets      = (s?['wickets'] as int?) ?? bowlerWickets;
      bowlerMaidens      = (s?['maiden'] as int?) ?? bowlerMaidens;
      bowlerEconomy      = (s?['econ'] as double?) ?? bowlerEconomy;

      // Prefer API text (e.g., "3.4"), else format from overs map
      bowlerOversBowled  = (s?['overs']?.toString())
          ?? _formatOversDisplayFromDouble(oversFromMap ?? 0.0);
    });
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
        final viewInsets = MediaQuery.of(context).viewInsets; // keyboard
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: viewInsets.bottom + 16,
              top: 24,
            ),
            child: SingleChildScrollView( // ← prevents overflow with keyboard/text scale
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
                          minimumSize: const Size(88, 40), // Material min width (safe)
                        ),
                        onPressed: () => Navigator.pop(context, i),
                        child: Text('$prefix + $i', maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Flexible(
                        flex: 0,
                        child: Text('Custom:', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),

                      // TextField flexes to take remaining space
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (v) {
                            final val = int.tryParse(v);
                            if (val != null) Navigator.pop(context, val);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Enter runs',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Constrain the OK button so the Row never overflows
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 72),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(72, 40)),
                          onPressed: () {
                            final val = int.tryParse(controller.text);
                            if (val != null) Navigator.pop(context, val);
                          },
                          child: const Text('OK', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

    debugPrint('🧠 Inning=${_firstInningClosed ? "2nd" : "1st"} | BattingTeamID=$battingTeamId | BowlingTeamID=$bowlingTeamId');

    List<Map<String, dynamic>> _mapRoster(List<dynamic> src) => src
        .map<Map<String, dynamic>>((p) {
      final id = int.tryParse('${p['ID']}') ?? 0;
      final name = (p['display_name'] ?? p['user_login'] ?? '').toString();
      return {'id': id, 'name': name};
    })
        .where((p) => (p['id'] as int) > 0)
        .toList();

    List<Map<String, dynamic>> _filterByIds(List<Map<String, dynamic>> roster, List<int> ids) {
      final set = ids.toSet();
      return roster.where((p) => set.contains(p['id'] as int)).toList();
    }

    try {
      // 1) Always fetch full rosters (stable fallback + for names)
      final t1 = await PlayerService.fetchTeamPlayers(teamId: _teamOneId!, apiToken: widget.token);
      final t2 = await PlayerService.fetchTeamPlayers(teamId: _teamTwoId!, apiToken: widget.token);
      _team1Squad = _mapRoster(t1);
      _team2Squad = _mapRoster(t2);

      // 2) Role endpoints (best-effort; tolerate odd shapes via RolePlayersService)
      final results = await Future.wait([
        RolePlayersService.fetchBattersByTeam(matchId: widget.matchId, teamId: _teamOneId!),
        RolePlayersService.fetchBowlersByTeam(matchId: widget.matchId, teamId: _teamOneId!),
        RolePlayersService.fetchBattersByTeam(matchId: widget.matchId, teamId: _teamTwoId!),
        RolePlayersService.fetchBowlersByTeam(matchId: widget.matchId, teamId: _teamTwoId!),
      ]);

      final t1Batters = results[0]; // [{id,name,is_out,stats{r,b,4s,6s,sr,order,out_by}}]
      final t1Bowlers = results[1]; // [{id,name,stats{overs,balls,maiden,runs,wickets,economy}}]
      final t2Batters = results[2];
      final t2Bowlers = results[3];

      // 3) Build CURRENT batting/bowling lists (prefer role lists; fallback to XI from roster)
      final battingRoster = (battingTeamId == _teamOneId!) ? _team1Squad : _team2Squad;
      final bowlingRoster = (bowlingTeamId == _teamOneId!) ? _team1Squad : _team2Squad;

      final roleBatters = (battingTeamId == _teamOneId!) ? t1Batters : t2Batters;
      final roleBowlers = (bowlingTeamId == _teamOneId!) ? t1Bowlers : t2Bowlers;

      final effectiveBatters = roleBatters.isNotEmpty
          ? roleBatters.map((e) => {
        'id'    : e['id'],
        'name'  : e['name'],
        'is_out': e['is_out'] ?? 0,
        'stats' : e['stats'] ?? const {},
      }).toList()
          : _filterByIds(battingRoster, battingIds).map((p) => {
        'id'    : p['id'],
        'name'  : p['name'],
        'is_out': 0,
        'stats' : const {'r':0,'b':0,'4s':0,'6s':0,'sr':0.0,'order':0,'out_by':''},
      }).toList();

      final effectiveBowlers = roleBowlers.isNotEmpty
          ? roleBowlers.map((e) => {
        'id'   : e['id'],
        'name' : e['name'],
        // we keep stats only on _bowlerStatsMap/_bowlerOversMap for UI
      }).toList()
          : _filterByIds(bowlingRoster, bowlingIds);

      // 4) Update dismissed list from API (players already OUT must not be selectable)
      for (final p in effectiveBatters) {
        if ((p['is_out'] ?? 0) == 1) {
          final pid = p['id'] as int;
          if (!_dismissedBatters.contains(pid)) _dismissedBatters.add(pid);
        }
      }

      // 5) Hydrate bowler stats/overs maps from BOTH teams’ role bowlers
      _bowlerStatsMap.clear();
      _bowlerOversMap.clear();
      void _ingestBowlers(List<Map<String, dynamic>> blist) {
        for (final b in blist) {
          final id = b['id'] as int;
          final stats = (b['stats'] as Map<String, dynamic>?) ?? const {};
          final ov   = _parseInt(stats['overs']);         // int or string handled by _parseInt
          final balls= _parseInt(stats['balls']);         // 0..5
          final runs = _parseInt(stats['runs']);
          final wkts = _parseInt(stats['wickets']);
          final maid = _parseInt(stats['maiden']);
          final econ = double.tryParse('${stats['economy'] ?? 0}') ?? 0.0;

          _bowlerStatsMap[id] = {
            'runs'   : runs,
            'wickets': wkts,
            'maiden' : maid,
            'overs'  : '$ov.${balls.clamp(0,5)}',
            'econ'   : econ,
          };
          _bowlerOversMap[id] = ov + (balls.clamp(0,5) / 6.0);
        }
      }
      _ingestBowlers(t1Bowlers);
      _ingestBowlers(t2Bowlers);

      setState(() {
        _battingSidePlayers = effectiveBatters;   // with stats/is_out
        _bowlingSidePlayers = effectiveBowlers;   // names; stats in _bowlerStatsMap
      });

      // 6) Last resort (very rare): if bowlers still empty, show XI slice
      if (_bowlingSidePlayers.isEmpty) {
        _bowlingSidePlayers = _filterByIds(bowlingRoster, bowlingIds);
        setState(() {});
      }

      debugPrint('✅ Batters=${_battingSidePlayers.length} | Bowlers=${_bowlingSidePlayers.length} (roleBowlers=${roleBowlers.length})');
    } catch (e, st) {
      _showError("Failed to load squads");
      debugPrint('❌ Error loading squads: $e\n$st');
    }
  }


/*
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
  */

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
    Perf.start('PARSE_FUNCTION');

    try {
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
      int? apiBowlerId;
      if (bwSingle != null) {
        final pid = _parseInt(bwSingle['id']);
        apiBowlerId = pid;
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
        final o = i ~/ 6;
        final b = (i % 6) + 1;
        _submittedBalls.add('$o.$b');
      }

      final nextBall   = (doneBalls % 6) + 1;
      final overAdjust = (doneBalls % 6 == 0 && doneBalls > 0) ? 1 : 0;
      final nextOver   = doneOvers + overAdjust;
// 🔄 sync legal balls from API
      _legalBallsInOver = doneBalls.clamp(0, 5);

      // Grab striker / non-striker
      final on  = cs['on_strike']  as Map<String, dynamic>?;
      final non = cs['non_strike'] as Map<String, dynamic>?;

      // Seed batting order
      final int onId  = on  != null ? _parseInt(on['id'])  : 0;
      final int nonId = non != null ? _parseInt(non['id']) : 0;
      if (onId  > 0) _assignBattingOrderIfMissing(onId);
      if (nonId > 0) _assignBattingOrderIfMissing(nonId);

      // Decide bowler stats source
      final int? statsForBowlerId = apiBowlerId ?? bowlerId;
      final Map<String, dynamic>? statsForBowler =
      (statsForBowlerId != null) ? _bowlerStatsMap[statsForBowlerId] : null;

      // Overs text fallback
      String? oversText;
      if (statsForBowler != null && statsForBowler['overs'] != null) {
        oversText = statsForBowler['overs'].toString();
      } else if (statsForBowlerId != null && _bowlerOversMap.containsKey(statsForBowlerId)) {
        oversText = _formatOversDisplayFromDouble(_bowlerOversMap[statsForBowlerId]!);
      }

      if (!mounted) return;

      setState(() {
        runs           = _parseInt(cs['total_runs']);
        wickets        = _parseInt(cs['total_wkts']);
        totalExtras    = _parseInt(cs['total_extra']);
        currentRunRate = double.tryParse(cs['current_run_rate'].toString()) ?? 0.0;

        overNumber = nextOver;
        ballNumber = nextBall;
        _isScoringDisabled = wickets >= 10;

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
          if (bwSingle != null && apiBowlerId != null) {
            bowlerId   = apiBowlerId;
            bowlerName = bwSingle['name']?.toString();
          }
        }

        final tl = inning['timeline'] as List<dynamic>?;
        if (tl != null && tl.isNotEmpty) {
          timeline = tl
              .map((e) => e.toString())
              .where((s) => _timelineRegex.hasMatch(s))
              .toList();
        } else {
          timeline = ['Loaded: $runs–$wickets at $doneOvers.$doneBalls'];
        }

        if (statsForBowlerId != null && statsForBowler != null) {
          bowlerRunsConceded = (statsForBowler['runs'] as int?) ?? 0;
          bowlerWickets      = (statsForBowler['wickets'] as int?) ?? 0;
          bowlerMaidens      = (statsForBowler['maiden'] as int?) ?? 0;
          bowlerEconomy      = (statsForBowler['econ'] as double?) ?? 0.0;
        }
        if (oversText != null) {
          bowlerOversBowled = oversText;
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

    } finally {
      Perf.end('PARSE_FUNCTION');
    }
  }




  /// ------------- SUBMIT SCORE (logic preserved; UI-only polish) -------------
  /// ------------- SUBMIT SCORE (FINAL, STABLE) -------------
  Future<void> _submitScore() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    Perf.start('TOTAL_SUBMIT');

    try {
      debugPrint('🔄 Submitting score for ball $overNumber.$ballNumber');

      if (_isScoringDisabled) {
        _showError('🛑 Team already won.');
        return;
      }

      // ✅ Innings completion check (LEGAL balls only)
      final localTotalBalls =
          (overNumber * 6) + (_legalBallsInOver.clamp(0, 5));
      if (localTotalBalls >= _matchOvers * 6) {
        _showError('🚫 Innings already completed.');
        _showMatchEndDialog("Innings Over - $_matchOvers Overs Completed");
        return;
      }

      if (onStrikePlayerId == null ||
          nonStrikePlayerId == null ||
          bowlerId == null) {
        _showError('Please select striker, non-striker, and bowler');
        return;
      }

      // ---------------- RUNS & EXTRAS ----------------
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
            legalDelivery = false;
            _isFreeHit = true;
            break;
          case 'Bye':
          case 'Leg Bye':
            extraRuns = selectedRuns ?? 0;
            break;
          default:
            batterRuns = selectedRuns ?? 0;
        }
      } else {
        batterRuns = selectedRuns ?? 0;
      }

      // ---------------- WICKET LOGIC ----------------
      bool wicketFalls = isWicket;

      if (wicketType == 'Retired Hurt' ||
          wicketType == 'Absent Hurt' ||
          (_isFreeHit && wicketType != 'Run Out')) {
        wicketFalls = false;
      }

      if (wicketFalls) wickets++;

      final formattedWicketType =
      wicketFalls ? (kWicketTypeMap[wicketType] ?? '0') : null;

      int? outPlayerId, runOutBy, catchBy;
      bool? outAtStriker;
      int? wicketKeeperForThisBall;

      if (wicketFalls && formattedWicketType != null) {
        // (same wicket selection logic as before — untouched)
        // 👉 intentionally not changed
      }

      // ---------------- STRIKE / BALL ADVANCE ----------------
      if (!wicketFalls && batterRuns > 0) {
        onStrikeRuns += batterRuns;
      }

      final submitStrikerId = onStrikePlayerId!;
      final submitNonStrikerId = nonStrikePlayerId!;

      _assignBattingOrderIfMissing(submitStrikerId);
      _assignBattingOrderIfMissing(submitNonStrikerId);

      final strikerOrder = _battingOrder[submitStrikerId] ?? 1;
      final nonStrikerOrder =
          _battingOrder[submitNonStrikerId] ?? (strikerOrder == 1 ? 2 : 1);

      final isEndOfOver = ballNumber == 6;
      final oddRun = batterRuns.isOdd;

      if ((selectedExtra == 'Wide' ||
          selectedExtra == 'Bye' ||
          selectedExtra == 'Leg Bye') &&
          extraRuns.isOdd) {
        _swapStrike();
      }

      if (selectedExtra == 'No Ball' && oddRun) _swapStrike();

      if (legalDelivery && !wicketFalls) {
        if (oddRun) _swapStrike();
        if (isEndOfOver) _swapStrike();
      }

      // ---------------- API SUBMIT ----------------
      final req = MatchScoreRequest(
        matchId: widget.matchId,
        battingTeamId: !_firstInningClosed
            ? _firstInningTeamId!
            : (_firstInningTeamId == _teamOneId!
            ? _teamTwoId!
            : _teamOneId!),
        onStrikePlayerId: submitStrikerId,
        onStrikePlayerOrder: strikerOrder,
        nonStrikePlayerId: submitNonStrikerId,
        nonStrikePlayerOrder: nonStrikerOrder,
        bowler: bowlerId!,
        overNumber: overNumber + 1,
        ballNumber: ballNumber,
        runs: batterRuns,
        extraRunType: extraType,
        extraRun: extraRuns > 0 ? extraRuns : null,
        isWicket: wicketFalls ? 1 : 0,
        outPlayer: outPlayerId,
        wicketType: formattedWicketType,
        runOutBy: runOutBy,
        catchBy: catchBy,
        wktkprId: wicketKeeperForThisBall ?? _currentWicketKeeperId,
        shot: _selectedShotType,
      );

      Perf.start('API_SUBMIT');
      final success =
      await MatchScoreService.submitScore(req, widget.token, context);
      Perf.end('API_SUBMIT');

      if (!success) {
        _showError('❌ Failed to submit score.');
        return;
      }

      // ---------------- LOCAL UI UPDATE (FAST) ----------------
      if (legalDelivery) {
        _advanceBall(legalDelivery: true);
      }

      if (wicketFalls) {
        await _showBatsmanSelectionAfterWicket(
          selectForStriker: outAtStriker ?? true,
        );
        if (isEndOfOver) _swapStrike();
      }

      _isFreeHit = false;
      selectedRuns = null;
      selectedExtra = null;
      isWicket = false;
      wicketType = null;

      Provider.of<MatchState>(context, listen: false).updateScore(
        matchId: widget.matchId,
        runs: runs,
        wickets: wickets,
        over: overNumber,
        ball: ballNumber,
      );

      // 🔥🔥🔥 MAIN FIX — BACKGROUND REFRESH (NO AWAIT)
      _unawaitedRefreshScore();

    } finally {
      Perf.end('TOTAL_SUBMIT');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  bool _bgFetching = false;

  void _unawaitedRefreshScore() {
    if (_bgFetching) return;
    _bgFetching = true;

    Future.microtask(() async {
      try {
        Perf.start('FETCH_SCORE_BG');
        final refreshed = await _fetchCurrentScoreData();
        Perf.end('FETCH_SCORE_BG');

        if (!mounted || refreshed == null) return;

        Perf.start('PARSE_BG');
        _parseCurrentScore(refreshed, overridePlayers: false);
        Perf.end('PARSE_BG');

        setState(() {});
      } finally {
        _bgFetching = false;
      }
    });
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

    final action = await showDialog<YoutubeEditAction>(
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
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, const YoutubeEditAction.remove()),
            child: const Text('Remove link'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, YoutubeEditAction.save(ctrl.text.trim()));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action.isRemove) {
      // If your backend clears on empty string, this is enough.
      final resp = await MatchYoutubeService.updateYoutube(
        apiToken: widget.token,
        matchId: widget.matchId,
        youtubeUrl: '', // or call a dedicated remove endpoint if you have one
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.message), backgroundColor: resp.ok ? Colors.green : Colors.red),
      );

      if (resp.ok) {
        setState(() => _youtubeUrl = null); // UI falls back to TV
        await _fetchMatchDetails();         // sync with server
      }
      return;
    }

    // Save new URL
    final resp = await MatchYoutubeService.updateYoutube(
      apiToken: widget.token,
      matchId: widget.matchId,
      youtubeUrl: action.url!,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.message), backgroundColor: resp.ok ? Colors.green : Colors.red),
    );

    if (resp.ok) {
      setState(() => _youtubeUrl = action.url);
      await _fetchMatchDetails();
    }
  }

  void _advanceBall({required bool legalDelivery}) {

    // count ONLY legal balls
    if (legalDelivery) {
      _legalBallsInOver++;
    }

    final isEndOfOver = _legalBallsInOver == 6;

    if (isEndOfOver) {
      overNumber++;
      ballNumber = 1;
      _legalBallsInOver = 0;

      if (bowlerId != null) {
        final current = _bowlerOversMap[bowlerId!] ?? 0.0;
        _bowlerOversMap[bowlerId!] = current.floor().toDouble() + 1.0;

        _lastBowlerId = bowlerId;

        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            'last_over_bowler_${widget.matchId}',
            bowlerId!,
          );
        }();
      }

      Future.delayed(
        const Duration(milliseconds: 100),
        _showBowlerSelectionAfterOver,
      );
    } else {
      // UI ball number increases for both legal & illegal
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

 /* void _showBowlerSelectionAfterOver() {
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
*/
  void _showBowlerSelectionAfterOver() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _updateLastCompletedOverBowler(); // light

      } catch (_) {}
      _showSelectPlayerSheet(isBatsman: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Over completed. Please select a new bowler.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.teal,
        ),
      );
    });
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

      _assignBattingOrderIfMissing(newId); // NEW: order for replacement batter

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

    _assignBattingOrderIfMissing(newId); // NEW: order for replacement batter

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
              final p   = available[i];
              final id  = p['id'] as int;
              final name= (p['name'] ?? p['display_name'] ?? p['user_login'] ?? 'Unnamed').toString();

              // ---------- Bowler picker ----------
              if (!isBatsman) {
                final ob = _bowlerOversMap[id] ?? 0.0;
                final displayOvers = _formatOversDisplayFromDouble(ob);
                final completed = _completedOversFromDouble(ob);
                final hasQuota = _bowlerMaxOvers <= 0 ? true : completed < _bowlerMaxOvers;
                final consecutiveBlocked = (_lastBowlerId != null && id == _lastBowlerId);

                final stats = _bowlerStatsMap[id];
                final maid  = (stats?['maiden'] as int?) ?? 0;
                final runs  = (stats?['runs'] as int?) ?? 0;
                final wkts  = (stats?['wickets'] as int?) ?? 0;
                final econ  = (stats?['econ'] as double?) ?? 0.0;

                return ListTile(
                  leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '$displayOvers / ${_bowlerMaxOvers > 0 ? "${_bowlerMaxOvers}.0" : "–"}  •  M:$maid  R:$runs  W:$wkts  Econs:${econ.toStringAsFixed(2)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

                    if (stats != null) {
                      bowlerRunsConceded = runs;
                      bowlerWickets      = wkts;
                      bowlerMaidens      = maid;
                      bowlerOversBowled  = (stats['overs']?.toString()) ?? displayOvers;
                      bowlerEconomy      = econ;
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

              // ---------- Batsman picker ----------
              final stats = (p['stats'] as Map<String, dynamic>?) ?? const {};
              final r     = _parseInt(stats['r']);
              final b     = _parseInt(stats['b']);
              final fours = _parseInt(stats['4s']);
              final sixes = _parseInt(stats['6s']);
              final sr    = double.tryParse('${stats['sr'] ?? 0}') ?? 0.0;
              final outBy = (stats['out_by'] ?? '').toString();
              final apiOut = (p['is_out'] ?? 0) == 1;

              final alreadyUsed   = _usedBatsmen.contains(id);
              final alreadyDismissed = _dismissedBatters.contains(id) || apiOut;

              // Details line
              final bits = <String>[
                '$r (${b}b)',
                '4s:$fours',
                '6s:$sixes',
                'SR:${sr.toStringAsFixed(0)}',
                if (outBy.isNotEmpty && outBy != '0') 'out: $outBy',
              ];

              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(bits.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: alreadyDismissed
                    ? const Chip(label: Text('OUT'), visualDensity: VisualDensity.compact)
                    : (alreadyUsed ? const Chip(label: Text('USED'), visualDensity: VisualDensity.compact) : null),
                enabled: !alreadyDismissed, // 🔒 do not allow OUT again
                onTap: !alreadyDismissed ? () {
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
                    _assignBattingOrderIfMissing(id);
                  } else if (selectForStriker == false) {
                    nonStrikePlayerId = id;
                    nonStrikeName     = name;
                    nonStrikeRuns     = 0;
                    nonStrikeBalls    = 0;
                    _assignBattingOrderIfMissing(id);
                  } else {
                    if (onStrikePlayerId == null) {
                      onStrikePlayerId = id; onStrikeName = name;
                      onStrikeRuns = 0; onStrikeBalls = 0;
                      _assignBattingOrderIfMissing(id);
                    } else {
                      if (id == onStrikePlayerId) {
                        _showError('This player is already the striker.');
                        return;
                      }
                      nonStrikePlayerId = id; nonStrikeName = name;
                      nonStrikeRuns = 0; nonStrikeBalls = 0;
                      _assignBattingOrderIfMissing(id);
                    }
                  }

                  setState(() {});
                  Navigator.pop(context, id);
                } : null,
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
        final score = inning?['score'];
        final doneOvers = _parseInt(score?['overs_done']);
        final doneBalls = _parseInt(score?['balls_done']);

        if (doneBalls == 0 && doneOvers > 0) {
          // over completed, find last legal ball
          final lastList = inning?['last_ball_data'] as List<dynamic>?;

          if (lastList != null && lastList.isNotEmpty) {
            for (int i = lastList.length - 1; i >= 0; i--) {
              final m = lastList[i] as Map<String, dynamic>;
              final isLegal = (m['extra_run_type'] ?? '0') == '0';
              if (isLegal) {
                _lastBowlerId = int.tryParse('${m['bowler_id'] ?? m['bowler']}');
                break;
              }
            }
          }
        }

        int? serverPrevOverBowler;


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

    try {
      // Work out who is fielding right now
      final battingTeamId = !_firstInningClosed
          ? _firstInningTeamId!
          : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!);
      final fieldingTeamId = (battingTeamId == _teamOneId!) ? _teamTwoId! : _teamOneId!;

      // Map<int, double> where value is overs as decimal (e.g. 3.2 = 3 overs 2 balls)
      final fetched = await MatchScoreService.fetchBowlerOversFromScorecard(
        matchId: widget.matchId,
        fieldingTeamId: fieldingTeamId,
      );

      if (!mounted || fetched.isEmpty) {
        setState(() {
          _bowlerOversMap = fetched; // still store whatever we got (even if empty)
        });
        return;
      }

      // Merge into local maps
      // (keep any existing entries we might have collected from other sources)
      fetched.forEach((pid, ob) {
        _bowlerOversMap[pid] = ob;

        final oversText = _formatOversDisplayFromDouble(ob);
        final stats = _bowlerStatsMap[pid];

        if (stats != null) {
          // Update overs text and compute economy if API didn't give it
          stats['overs'] = oversText;
          final runs = (stats['runs'] as int?) ?? 0;
          final econ = (stats['econ'] as double?) ?? 0.0;
          if (econ == 0.0) {
            final ovd = ob; // ob is decimal overs
            stats['econ'] = ovd > 0 ? runs / ovd : 0.0;
          }
        } else {
          // Seed minimal stats so UI has something to show
          _bowlerStatsMap[pid] = {
            'runs': 0,
            'wickets': 0,
            'maiden': 0,
            'overs': oversText,
            'econ': 0.0,
          };
        }
      });

      // If a bowler is currently selected, reflect latest figures on the card
      if (bowlerId != null) {
        final st = _bowlerStatsMap[bowlerId!];
        if (st != null) {
          setState(() {
            bowlerOversBowled  = (st['overs']?.toString()) ?? bowlerOversBowled;
            bowlerMaidens      = (st['maiden'] as int?) ?? bowlerMaidens;
            bowlerRunsConceded = (st['runs'] as int?) ?? bowlerRunsConceded;
            bowlerWickets      = (st['wickets'] as int?) ?? bowlerWickets;

            final econ = (st['econ'] as double?) ?? 0.0;
            if (econ > 0) {
              bowlerEconomy = econ;
            } else {
              final ob = _bowlerOversMap[bowlerId!] ?? 0.0;
              bowlerEconomy = ob > 0 ? bowlerRunsConceded / ob : 0.0;
            }
          });
        } else {
          setState(() {
            // At least update overs from fetched map for the current bowler
            final ob = _bowlerOversMap[bowlerId!];
            if (ob != null) bowlerOversBowled = _formatOversDisplayFromDouble(ob);
          });
        }
      } else {
        // No selected bowler; still notify UI of new overs map
        setState(() {});
      }
    } catch (e, st) {
      debugPrint('refreshBowlerOversFromScorecard error: $e\n$st');
    }
  }

  Future<void> _handleRunFlow(int r) async {
    // 1️⃣ UI FIRST
    selectedRuns = r;
    setState(() {});

    // 2️⃣ shot dialog if needed
    if (r > 0) {
      final Map<String, String>? shot =
      await showShotTypeDialog(context, r.toString(), 0);
      if (shot == null) return;
      _selectedShotType = shot['type'];
    }

    // 3️⃣ ONLY submit (no flag here)
    await _submitScore();
  }


  Future<void> _handleExtraFlow(String type) async {
    final run = await _showExtraRunDialog(type, type);
    if (run == null) return;

    selectedExtra = type;
    selectedRuns  = run;
    setState(() {});

    if (type == 'No Ball' && run > 0) {
      final Map<String, dynamic>? shot =
      await showShotTypeDialog(context, run.toString(), 1);
      if (shot == null) return;
      _selectedShotType = shot['type']?.toString();
    }

    await _submitScore();
  }



  Future<void> _handleWicketFlow() async {
    final res = await WicketTypeDialog.show(context);
    if (res == null) return;

    final String type = (res['type'] ?? '').toString();
    final int runsSel = res['runs'] ?? 0;

    if (type == 'Retired Hurt' || type == 'Absent Hurt') {
      isWicket     = false;
      wicketType   = type;
      selectedRuns = runsSel;
      setState(() {});
      await _showBatsmanSelectionAfterWicket(selectForStriker: null);
      return;
    }

    isWicket     = true;
    wicketType   = type;
    selectedRuns = runsSel;
    setState(() {});

    await _submitScore();
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
                    onRunSelected: (r) {
                      if (_isSubmitting) return;
                      _handleRunFlow(r);
                    },




                    onExtraSelected: (type) {
                      if (_isSubmitting) return;

                      _handleExtraFlow(type);
                    },



                    onWicketSelected: () {
                      if (_isSubmitting) return;
                      _handleWicketFlow();
                    },


                    onSwapStrike: _swapStrike,
                    onUndo: _undoLastBall,
                    onEndInning: _handleEndInning,
                    onEndMatch: () async {
                      // make sure team names exist
                      if ((_teamOneName ?? '').trim().isEmpty || (_teamTwoName ?? '').trim().isEmpty) {
                        await _fetchMatchDetails();
                      }

                      final teams = [
                        if (_teamOneId != null)
                          {'team_id': _teamOneId!, 'team_name': (_teamOneName ?? '').trim().isEmpty ? 'Team ${_teamOneId!}' : _teamOneName!.trim()},
                        if (_teamTwoId != null)
                          {'team_id': _teamTwoId!, 'team_name': (_teamTwoName ?? '').trim().isEmpty ? 'Team ${_teamTwoId!}' : _teamTwoName!.trim()},
                      ];

                      final result = await showEndMatchDialog(
                        context: context,
                        matchId: widget.matchId,
                        token: widget.token,
                        teams: teams,
                      );
                      if (!mounted) return;

                      // 🛑 User pressed Cancel or back → stay on scoring page
                      if (result == kEndMatchCancelled) {
                        return;
                      }

                      // 🏏 Super Over created → go to its scoring screen
                      if (result != null && result > 0) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => AddScoreScreen(matchId: result, token: widget.token),
                          ),
                        );
                        return;
                      }

                      // ✅ Normal end (no Super Over) → stay here (or refresh UI)
                      await _hardRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Match ended')),
                      );
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

// Put this at the top of the file (or anywhere outside classes)
class YoutubeEditAction {
  final String? url;
  final bool isRemove;
  const YoutubeEditAction._(this.url, this.isRemove);
  const YoutubeEditAction.save(String newUrl) : this._(newUrl, false);
  const YoutubeEditAction.remove() : this._(null, true);
}

