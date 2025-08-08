import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../model/match_score_model.dart';
import '../service/player_service.dart';
import '../service/match_score_service.dart';
import '../theme/color.dart';
import '../widget/animated_score_card.dart';
import '../widget/last_six_balls_widget.dart';
import '../widget/player_stats_card.dart';
import '../widget/scoring_inputs.dart';
import '../widget/shot_type_dialog.dart';
import '../provider/match_state.dart';
import '../widget/wicket_type_dialog.dart';
import 'full_match_detail.dart';
import 'match_detail_screen.dart';


class AddScoreScreen extends StatefulWidget {
  final int matchId;
  final String token;

  // ✅ Optional preload data
  final Map<String, dynamic>? currentScoreData;
  final List<Map<String, dynamic>>? preloadedBattingSquad;
  final List<Map<String, dynamic>>? preloadedBowlingSquad;
  final VoidCallback? onScoreSubmitted;

  const AddScoreScreen({
    Key? key,
    required this.matchId,
    required this.token,
    this.currentScoreData,
    this.preloadedBattingSquad,
    this.preloadedBowlingSquad,
    this.onScoreSubmitted, // ✅ Initialize here
  }) : super(key: key);





  @override
  State<AddScoreScreen> createState() => _AddScoreScreenState();
}
enum OutBatsman { striker, nonStriker }

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
  bool _inningsOver = false;
  bool _isSubmitting = false;
  bool _isEnding     = false;
  // Batsmen
  int onStrikeRuns    = 0;
  int nonStrikeRuns   = 0;

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
// inside _AddScoreScreenState
  int? _runOutBy;
  int? _catchBy;
  int _firstInningScore = 0;
  double requiredRunRate = 0.0;
  String? matchResultStatus; // 🏆 or ❌ or 🤝
  Color? matchResultColor;   // Green, Red, Orange
  bool isCloseMatch = false; // ⚠️ for UI animation




// Batsmen
  int onStrikeBalls = 0;
  int nonStrikeBalls = 0;
  int? _currentWicketKeeperId;
  String? _currentWicketKeeperName;
  List<int> _dismissedBatters = [];

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
      await _fetchMatchDetails(); // ✅ Step 1: Get match details
      await _loadSquads();        // ✅ Step 2: Load players based on inning

      final scoreData = await _fetchCurrentScoreData(); // ✅ Step 3: Get current score
      if (scoreData != null) {
        _parseCurrentScore(scoreData);
      }

      // ✅ Step 4: Manual player selection if API returns nothing
      if (onStrikePlayerId == null || nonStrikePlayerId == null || bowlerId == null) {
        Future.delayed(Duration(milliseconds: 300), () async {
          await _showSelectPlayerSheet(isBatsman: true, selectForStriker: true);   // striker
          await _showSelectPlayerSheet(isBatsman: true, selectForStriker: false);  // non-striker
          await _showSelectPlayerSheet(isBatsman: false);                           // bowler
        });
      }

      setState(() {}); // ✅ Final UI refresh
    } catch (e) {
      _showError('❌ Failed to load match or score data');
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
      int _firstInningScore = 0; // Will be set only after first inning is complete


      // clear players & tracking
      _resetInningPlayers();
      _usedBatsmen.clear();
      _usedBowlers.clear();
      _bowlerOversMap.clear();
      _lastBowlerId = null;

      // clear timeline / submitted keys
      timeline.clear();
      _submittedBalls.clear();

      // swap squads (we already reloaded them in _loadSquads())
      // but keep these two lines to be explicit if you rely on cached _team1Squad/_team2Squad
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


  void _showEndMatchDialog({
    required BuildContext context,
    required int matchId,
    required String token,
  }) {
    String resultType = 'Win';
    int? winningTeam;
    int? runsOrWickets;
    String? winByType;
    String? drawComment;
    bool superOver = false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("End Match"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: resultType,
                items: ['Win', 'Draw', 'WinBToss', 'Tie']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) => resultType = val!,
                decoration: const InputDecoration(labelText: "Result Type"),
              ),
              if (resultType == 'Win' || resultType == 'WinBToss')
                TextField(
                  decoration: const InputDecoration(labelText: "Winning Team ID"),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => winningTeam = int.tryParse(val),
                ),
              if (resultType == 'Win')
                Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: "Runs or Wickets"),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => runsOrWickets = int.tryParse(val),
                    ),
                    DropdownButtonFormField<String>(
                      value: winByType,
                      items: ['Runs', 'Wickets']
                          .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                          .toList(),
                      onChanged: (val) => winByType = val,
                      decoration: const InputDecoration(labelText: "Win By Type"),
                    ),
                  ],
                ),
              if (resultType == 'Draw')
                TextField(
                  decoration: const InputDecoration(labelText: "Draw Comment"),
                  onChanged: (val) => drawComment = val,
                ),
              if (resultType == 'Tie')
                CheckboxListTile(
                  value: superOver,
                  title: const Text("Use Super Over?"),
                  onChanged: (val) => superOver = val ?? false,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              await MatchScoreService.endMatch(
                context: context,
                token: token,
                matchId: matchId,
                resultType: resultType,
                winningTeam: winningTeam,
                runsOrWicket: runsOrWickets,
                winByType: winByType,
                drawComment: drawComment,
                superOvers: superOver ? 'yes' : null,
              );
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Future<int?> _pickBowlingSidePlayer({
    required String title,
  }) async {
    int? selectedId;

    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
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
    // striker
    await _showSelectPlayerSheet(isBatsman: true, selectForStriker: true);
    // non-striker
    await _showSelectPlayerSheet(isBatsman: true, selectForStriker: false);
    // bowler
    await _showSelectPlayerSheet(isBatsman: false);
  }

  Future<void> _undoLastBall() async {
    // 1. Call undo service
    final ok = await MatchScoreService.undoLastBall(widget.matchId, widget.token, context);
    if (!ok) {
      _showError('❌ Could not undo last ball.');
      return;
    }

    print('⏪ Undo successful');

    // 2. Remove last entry from timeline
    if (timeline.isNotEmpty) timeline.removeAt(0);
    _submittedBalls.clear(); // so ball can be submitted again

    // 3. Re-fetch live score from backend
    final fresh = await _fetchCurrentScoreData();
    if (fresh != null) {
      _parseCurrentScore(fresh);
    }

    // 4. Reset used player lists
    _usedBatsmen.clear();
    _usedBowlers.clear();
    _dismissedBatters.clear(); // 💡 Also clear dismissed batters
    _isScoringDisabled = false; // ✅ Re-enable scoring after undo

    final inningScore = fresh?['current_score']?['current_inning'];
    final batsmen = inningScore?['batting_score'] ?? [];
    final bowlers = inningScore?['bowling_score'] ?? [];
    final outPlayers = fresh?['current_score']?['current_inning']?['score']?['out_players'] ?? [];

    // Re-populate used batsmen and dismissed players
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

    // 5. Update match state provider
    Provider.of<MatchState>(context, listen: false).updateScore(
      matchId: widget.matchId,
      runs: runs,
      wickets: wickets,
      over: overNumber,
      ball: ballNumber,
    );

    // 6. Refresh last six balls widget (TV/score strip)
    _lastSixBallsRefresher.notifyListeners();

    // 7. Clear input UI
    _resetInputs();

    // 8. Refresh UI
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

      // ✅ Step 1: Refresh match meta (who bats next)
      final ok = await _fetchMatchDetails();
      if (!ok) {
        _showError('Failed to refresh match details after ending innings.');
        return;
      }

      // ✅ Step 2: Reload squads
      await _loadSquads();

      // ✅ Step 3: Reset everything for 2nd innings
      _startSecondInning();

      // ✅ DO NOT fetch old score API immediately here
      // Instead, reset score state manually
      setState(() {
        overNumber = 0;
        ballNumber = 1;
        runs = 0;
        wickets = 0;
        timeline = ['2nd innings started'];
      });

      // ✅ Step 4: Select striker/non-striker/bowler
      Future.delayed(const Duration(milliseconds: 300), _selectInitialSecondInningPlayers);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2nd Innings started ✅')),
      );
    } catch (e) {
      _showError('Error ending innings: $e');
    } finally {
      setState(() => _isEnding = false);
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

      // API sometimes returns list, sometimes empty
      final dataList = body['data'];
      if (dataList is! List || dataList.isEmpty) {
        debugPrint('get-single-cricket-match data empty');
        return false;
      }
      final data = dataList.first as Map<String, dynamic>;

      // --- helpers ---
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
        teamName         = teamNameLocal;
      });

      // sanity logs
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
      // Fetch BOTH full squads once
      final t1 = await PlayerService.fetchTeamPlayers(teamId: _teamOneId!, apiToken: widget.token);
      final t2 = await PlayerService.fetchTeamPlayers(teamId: _teamTwoId!, apiToken: widget.token);

      // Cache team squads for later swaps
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

      // Pick the CURRENT inning batting/bowling squads filtered by XI
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

    // ✅ Case 1: Team B has chased successfully
    if (teamBScore >= target) {
      final remainingWickets = 10 - teamBWickets;
      _showMatchEndDialog("🎉 $teamBName won by $remainingWickets wicket(s)");
      _isScoringDisabled = true;
      return;
    }

    // ✅ Case 2: All out and not chased
    if (teamBWickets >= 10 && teamBScore < target) {
      final margin = target - 1 - teamBScore;
      _showMatchEndDialog("🏆 $teamAName won by $margin run(s)");
      _isScoringDisabled = true;
      return;
    }

    // ✅ Case 3: All out but exactly equal
    if (teamBWickets >= 10 && teamBScore == target - 1) {
      _showMatchEndDialog("🤝 Match Tied");
      _isScoringDisabled = true;
      return;
    }
  }

  // Add at the top of your State class:
  final Map<int, Map<String, dynamic>> _bowlerStatsMap = {};

// …

  void _parseCurrentScore(Map<String, dynamic> body, {bool overridePlayers = true}) {
    debugPrint('🔄 _parseCurrentScore called');

    // 1) Validate JSON
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

    // 2) Build a map of all bowlers’ stats from bowling_score
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
      debugPrint('   statsMap[$pid] = ${_bowlerStatsMap[pid]}');
    }

    // 3) Also add the current bowler from cs['bowler']
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
      debugPrint('   statsMap[$pid] (current) = ${_bowlerStatsMap[pid]}');
    }

    // 4) Parse completed overs & balls, normalizing 6+ balls
    int doneOvers = _parseInt(cs['overs_done']);
    int doneBalls = _parseInt(cs['balls_done']);
    if (doneBalls >= 6) {
      final extra = doneBalls ~/ 6;
      doneOvers += extra;
      doneBalls = doneBalls % 6;
    }
    final totalBalls = doneOvers * 6 + doneBalls;
    debugPrint('   doneOvers=$doneOvers, doneBalls=$doneBalls, totalBalls=$totalBalls');

    // Rebuild submittedBalls set
    _submittedBalls.clear();
    for (int i = 0; i < totalBalls; i++) {
      final o = i ~/ 6, b = (i % 6) + 1;
      _submittedBalls.add('$o.$b');
    }

    // 5) Compute nextOver/nextBall for submission logic
    final nextBall   = (doneBalls % 6) + 1;
    final overAdjust = (doneBalls % 6 == 0 && doneBalls > 0) ? 1 : 0;
    final nextOver   = doneOvers + overAdjust;
    debugPrint('   nextOver=$nextOver, nextBall=$nextBall');

    // 6) Grab striker/non-striker
    final on  = cs['on_strike']  as Map<String, dynamic>?;
    final non = cs['non_strike'] as Map<String, dynamic>?;

    if (!mounted) return;
    setState(() {
      // 7) Core score state
      runs           = _parseInt(cs['total_runs']);
      wickets        = _parseInt(cs['total_wkts']);
      totalExtras    = _parseInt(cs['total_extra']);
      currentRunRate = double.tryParse(cs['current_run_rate'].toString()) ?? 0.0;

      // <<< DISPLAY the completed delivery, not next >>>
      // ✅ Compute next over and ball for scoring
      final nextBall   = (doneBalls % 6) + 1;
      final overAdjust = (doneBalls % 6 == 0 && doneBalls > 0) ? 1 : 0;
      final nextOver   = doneOvers + overAdjust;

// ✅ Use next delivery values to avoid duplicate submission error
      overNumber = nextOver;
      ballNumber = nextBall;

      _isScoringDisabled = wickets >= 10;

      // First-innings total
      final firstScore = csRoot['first_inning']?['score'] as Map<String, dynamic>?;
      if (_firstInningClosed && firstScore != null) {
        _firstInningScore = _parseInt(firstScore['total_runs']);
      }

      // 8) Override batsmen/bowler if needed
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

      // 9) Rebuild timeline
      final tl = inning['timeline'] as List<dynamic>?;
      if (tl != null && tl.isNotEmpty) {
        timeline = tl
            .map((e) => e.toString())
            .where((s) => RegExp(r'^\d+\.\d+:').hasMatch(s))
            .toList();
      } else {
        timeline = ['Loaded: $runs–$wickets at $doneOvers.$doneBalls'];
      }

      // 10) 2nd-innings result logic (unchanged)…
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
  /// ------------- 1) SUBMIT SCORE (with updated wicket/end‐of‐over logic) -------------
  Future<void> _submitScore() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    try {
      debugPrint('🔄 Submitting score for ball $overNumber.$ballNumber');

      // 1️⃣ Prevent scoring if match already won
      if (_isScoringDisabled) {
        _showError('🛑 Team already won.');
        return;
      }

      // 2️⃣ Check innings completion via API
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

      // 3️⃣ Ensure striker, non-striker & bowler are selected
      if (onStrikePlayerId == null || nonStrikePlayerId == null || bowlerId == null) {
        _showError('Please select striker, non-striker, and bowler');
        return;
      }

      // 4️⃣ Compute runs & extras...
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

      // 5️⃣ Handle wicket
      bool wicketFalls = isWicket;
      if (_isFreeHit && wicketType != 'Run Out') wicketFalls = false;
      if (wicketFalls) wickets++;

      final formattedWicketType = wicketFalls
          ? {
        'Bowled': 'Bowled', 'Caught': 'Caught', 'LBW': 'LBW',
        'Run Out': 'Run Out', 'Run Out (Mankaded)': 'Run Out (Mankaded)',
      }[wicketType] ?? '0'
          : null;

      int? runOutBy, catchBy;
      if (wicketFalls && formattedWicketType != null) {
        if (formattedWicketType.contains('Run Out')) {
          runOutBy = await _pickBowlingSidePlayer(title: 'Who did the Run Out?');
          if (runOutBy == null) { _showError('Please select fielder for Run Out'); return; }
        } else if (['Caught','LBW','Bowled'].contains(formattedWicketType)) {
          catchBy = formattedWicketType == 'Caught'
              ? await _pickBowlingSidePlayer(title: 'Who took the catch?')
              : null;
          if (formattedWicketType == 'Caught' && catchBy == null) {
            _showError('Please select catcher'); return;
          }
        }
      }
// 6️⃣ Strike-swap logic
      final isEndOfOver = ballNumber == 6;
      final oddRun      = batterRuns % 2 == 1;



      if (selectedExtra == 'Wide' || selectedExtra == 'Bye' || selectedExtra == 'Leg Bye') {
        // extraRuns is already set (e.g. extraRuns = selectedRuns ?? 1)
        if (extraRuns % 2 == 1) {
          debugPrint('🔄 Swap on odd runs off $selectedExtra');
          _swapStrike();
        }
      }

// ── ① No-ball odd runs swap ──
      if (selectedExtra == 'No Ball' && oddRun) {
        debugPrint('🔄 Swap on no-ball odd run');
        _swapStrike();
      }

// ── ② Legal deliveries (runs & byes) ──
      if (legalDelivery && !wicketFalls) {
        // odd runs (1/3/5) → swap
        if (oddRun) {
          debugPrint('🔄 Swap on odd runs');
          _swapStrike();
        }
        // end of over → swap back
        if (isEndOfOver) {
          debugPrint('🔄 Swap on end of over');
          _swapStrike();
        }
      }




// ── ③ Wides: nothing happens ──
//   legalDelivery is false and we don’t swap for wide/extra runs here



      // 7️⃣ Build & send API request
      final req = MatchScoreRequest(
        matchId: widget.matchId,
        battingTeamId: !_firstInningClosed
            ? _firstInningTeamId!
            : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!),
        onStrikePlayerId: onStrikePlayerId!,
        onStrikePlayerOrder: 1,
        nonStrikePlayerId: nonStrikePlayerId!,
        nonStrikePlayerOrder: 2,
        bowler: bowlerId!,
        overNumber: overNumber + 1,
        ballNumber: ballNumber,
        runs: batterRuns,
        extraRunType: extraType,
        extraRun: extraRuns > 0 ? extraRuns : null,
        isWicket: wicketFalls ? 1 : 0,
        wicketType: formattedWicketType,
        runOutBy: runOutBy,
        catchBy: catchBy,
      );
      final success = await MatchScoreService.submitScore(req, widget.token, context);
      if (!success) { _showError('❌ Failed to submit score.'); return; }

      // 8️⃣ Local updates
      _submittedBalls.add('$overNumber.$ballNumber');
      timeline.insert(0,
          '$overNumber.$ballNumber: '
              '${selectedExtra != null ? '$selectedExtra +${selectedRuns ?? 0}' : '$selectedRuns'}'
              '${wicketFalls ? ' 🧨 Wicket($wicketType)' : ''}'
      );
      if (!wicketFalls && batterRuns > 0) onStrikeRuns += batterRuns;

      // 9️⃣ Advance ball & mark bowler used
      if (legalDelivery) {
        _usedBowlers.add(bowlerId!);
        _advanceBall();
      }

// 🔟 Replacement
      if (wicketFalls) {
        // ─── pick the end for replacement ───
        bool? replacementAtStriker;
        if (formattedWicketType == 'Run Out' ||
            formattedWicketType == 'Run Out (Mankaded)') {
          // let your existing run-out dialog set replacementAtStriker = true/false
        } else {
          // for Bowled/Caught/LBW, always replace at striker’s end
          replacementAtStriker = true;
        }

        // show the batsman picker
        await _showBatsmanSelectionAfterWicket(selectForStriker: replacementAtStriker);

        // ─── if it was the last ball of the over, swap ends ───
        if (isEndOfOver) {
          _swapStrike();
        }
      }



    // 1️⃣1️⃣ Reset inputs
      _isFreeHit = false;
      selectedRuns = null;
      selectedExtra = null;
      isWicket = false;
      wicketType = null;

      // 1️⃣2️⃣ Refresh UI + provider
      Provider.of<MatchState>(context, listen: false).updateScore(
        matchId: widget.matchId,
        runs: runs, wickets: wickets,
        over: overNumber, ball: ballNumber,
      );
      final refreshed = await _fetchCurrentScoreData();
      if (refreshed != null) {
        _parseCurrentScore(refreshed, overridePlayers: false);
        _checkMatchResult(refreshed);
        setState(() {});
      }

    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }



  void _showMatchEndDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🏁 Match Result'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
  void _advanceBall() {
    // Only treat the 6th delivery as end‐of‐over
    final isEndOfOver = ballNumber == 6;

    if (isEndOfOver) {
      // 1) Increment over count and reset ball
      overNumber++;
      ballNumber = 1;

      // 2) Track bowler’s completed over
      if (_lastBowlerId != null) {
        _bowlerOversMap[_lastBowlerId!] =
            (_bowlerOversMap[_lastBowlerId!] ?? 0) + 1;
      }
      _lastBowlerId = bowlerId;

      // 3) Delay showing the bowler picker so the UI can repaint
      Future.delayed(const Duration(milliseconds: 100), () {
        _showBowlerSelectionAfterOver();
      });
    } else {
      // Simply move to the next ball within the same over
      ballNumber++;
    }

    // Rebuild the header so overNumber/ballNumber update immediately
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
                Navigator.of(context).pop(value); // Return selected
              },
            );
          }).toList(),
        ),
      ),
    );
  }
  void _swapStrike() {
    // store striker’s data
    final tmpId    = onStrikePlayerId;
    final tmpName  = onStrikeName;
    final tmpRuns  = onStrikeRuns;
    final tmpBalls = onStrikeBalls;   // <-- add this

    // move non-striker → striker
    onStrikePlayerId = nonStrikePlayerId;
    onStrikeName     = nonStrikeName;
    onStrikeRuns     = nonStrikeRuns;
    onStrikeBalls    = nonStrikeBalls; // <-- and this

    // move old striker → non-striker
    nonStrikePlayerId = tmpId;
    nonStrikeName     = tmpName;
    nonStrikeRuns     = tmpRuns;
    nonStrikeBalls    = tmpBalls;     // <-- and this

    setState(() {});
  }


  void _resetInputs()
  {
    selectedRuns = null; // ✅ Fix: do not auto-select 0
    selectedExtra = null;
    isWicket = false;
    wicketType = null;
  }

/////Part4////
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

  /// Replaces the outgoing batsman.
  /// If [selectForStriker] is non-null, uses that end; otherwise (on run‐out) asks.
  Future<void> _showBatsmanSelectionAfterWicket({ bool? selectForStriker }) async {
    if (!mounted) return;
    final wt = wicketType;

    // No‐replacement
    if (wt == 'Retired Hurt' || wt == 'Absent Hurt') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No replacement needed for $wt'),
            backgroundColor: Colors.orange,
          ),
        );
      return;
    }

    // Run‐out: ask if we still don't know where
    final isRunOut = wt == 'Run Out' || wt == 'Run Out (Mankaded)';
    if (isRunOut && selectForStriker == null) {
      final outChoice = await showDialog<OutBatsman>(
        context: context,
        builder: (ctx) => AlertDialog(
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

    // Default (non‐run‐out) if still null → striker end
    if (selectForStriker == null) selectForStriker = true;

    // Prompt & pick
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

    // Replace at correct end
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


  Future<int?> _showSelectPlayerSheet({
    required bool isBatsman,
    bool? selectForStriker, // true = force striker, false = non-striker, null = ask
  }) async {
    final all = isBatsman ? _battingSidePlayers : _bowlingSidePlayers;

    // Batsmen: exclude used & dismissed
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

    // Bowlers: only exclude the one who just bowled the last over
    final available = all.where((p) {
      final id = p['id'] as int;
      return id != _lastBowlerId;
    }).toList();
    if (available.isEmpty) {
      _showError("No more bowlers available to select.");
      return null;
    }
    return await _buildPlayerSheet(available, isBatsman, selectForStriker);
  }

// Helper: builds the bottom‐sheet for either batsmen or bowlers
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
          height: 420,
          child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (_, i) {
              final p = available[i];
              final id = p['id'] as int;
              final name = (p['name'] ?? p['display_name'] ?? p['user_login'] ?? 'Unnamed') as String;

              return ListTile(
                leading: CircleAvatar(child: Text(name[0])),
                title: Text(name),
                subtitle: isBatsman
                    ? null
                    : Text('${(_bowlerOversMap[id] ?? 0.0).toStringAsFixed(1)} / ${_bowlerMaxOvers.toDouble().toStringAsFixed(1)} overs'),
                onTap: () {
                  if (isBatsman) {
                    // your existing batsman selection logic…
                    _usedBatsmen.add(id);
                    onStrikePlayerId = selectForStriker == true ? id : onStrikePlayerId;
                    nonStrikePlayerId = selectForStriker == false ? id : nonStrikePlayerId;
                  } else {
                    // bowler pick: just set them—do NOT mark used here
                    bowlerId = id;
                    bowlerName = name;
                    final stats = _bowlerStatsMap[id];
                    if (stats != null) {
                      bowlerRunsConceded = stats['runs'] as int;
                      bowlerWickets      = stats['wickets'] as int;
                      bowlerMaidens      = stats['maiden'] as int;
                      bowlerOversBowled  = stats['overs'] as String;
                      bowlerEconomy      = stats['econ'] as double;
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

  @override
  Widget build(BuildContext context) {
    if (_teamOneId == null ||
        _teamTwoId == null ||
        _firstInningTeamId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int battingTeamId = !_firstInningClosed
        ? _firstInningTeamId!
        : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!);
    debugPrint('🏏 battingTeamId = $battingTeamId');
    return Scaffold(
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
            title: const Text(
              'Match Score',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScoreCard(
                matchType: matchName ?? 'Match',
                teamName: teamName,
                isSecondInnings: _firstInningClosed,
                runs: runs,
                wickets: wickets,
                overs: overNumber,
                balls: ballNumber,
                totalOvers: _matchOvers,
                targetScore: _firstInningClosed ? _firstInningScore : null,
              ),

              PlayerStatsCard(
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

              const SizedBox(height: 4),

              (_teamOneId == null || _teamTwoId == null)
                  ? const Center(child: CircularProgressIndicator())
                  : LastSixBallsWidget(
                matchId: widget.matchId,
                teamId: battingTeamId,
                refresher: _lastSixBallsRefresher,
                autoRefreshEvery: const Duration(seconds: 20),
              ),


              const SizedBox(height: 4),

              // Make this area scrollable & avoid overflows
              Expanded(
                child: ScoringInputs(
                  selectedRuns: selectedRuns,
                  selectedExtra: selectedExtra,
                  isWicket: isWicket,
                  isSubmitting: _isSubmitting,
                  onRunSelected: (r) async {
                    setState(() => selectedRuns = r);
                    await _submitScore();
                  },
                  onExtraSelected: (type) async {
                    final run = await _showExtraRunDialog(type, type);
                    if (run != null) {
                      setState(() {
                        selectedExtra = type;
                        selectedRuns = run;
                      });
                      await _submitScore();
                    }
                  },
                  onWicketSelected: () async {
                    final res = await WicketTypeDialog.show(context);
                    if (res != null) {
                      setState(() {
                        isWicket = true;
                        wicketType = res['type'];
                        selectedRuns = res['runs'] ?? 0;
                      });
                      await _submitScore();
                    }
                  },

                  onSwapStrike: _swapStrike,
                  onUndo: _undoLastBall,
                  onEndInning: _handleEndInning,
                  onEndMatch: () => _showEndMatchDialog(
                    context: context,
                    matchId: widget.matchId,
                    token: widget.token,
                  ),


                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
