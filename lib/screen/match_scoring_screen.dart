import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../model/match_score_model.dart';
import '../service/player_service.dart';
import '../service/match_score_service.dart';
import '../theme/color.dart';
import '../widget/shot_type_dialog.dart';
import '../provider/match_state.dart';
import 'package:intl/intl.dart';

class AddScoreScreen extends StatefulWidget {
  final int matchId;
  final String token;

  // ✅ Optional preload data
  final Map<String, dynamic>? currentScoreData;
  final List<Map<String, dynamic>>? preloadedBattingSquad;
  final List<Map<String, dynamic>>? preloadedBowlingSquad;

  const AddScoreScreen({
    Key? key,
    required this.matchId,
    required this.token,
    this.currentScoreData,
    this.preloadedBattingSquad,
    this.preloadedBowlingSquad,
  }) : super(key: key);



  @override
  State<AddScoreScreen> createState() => _AddScoreScreenState();
}


class AnimatedScoreCard extends StatelessWidget {
  final String matchType;       // e.g., "Defender Cup Final"
  final String teamName;        // e.g., "Knight Scorchers"
  final bool isSecondInnings;   // true = 2nd Innings
  final int runs;
  final int wickets;
  final int overs;
  final int balls;

  const AnimatedScoreCard({
    Key? key,
    required this.matchType,
    required this.teamName,
    required this.isSecondInnings,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.balls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateFormat('d MMMM').format(DateTime.now());

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.white10 : Colors.white,
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🗓️ Dynamic Date
            Text(
              today,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),

            // 🏆 Match Name
            Text(
              matchType,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.tealAccent : Colors.indigo.shade700,
              ),
            ),
            const SizedBox(height: 4),

            // 🧢 Team Name
            Text(
              teamName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.deepOrange.shade700,
              ),
            ),

            // 🔁 Innings Info
            Text(
              isSecondInnings ? '2nd Innings' : '1st Innings',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // 🧮 Glowing Score
            TweenAnimationBuilder(
              tween: IntTween(begin: 0, end: runs),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                final isMilestone = value >= 50;
                final isCentury = value >= 100;
                final glowColor = isCentury
                    ? Colors.deepOrangeAccent
                    : Colors.blueAccent;


                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isMilestone
                        ? [
                      BoxShadow(
                        color: glowColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                        : [],
                  ),
                  child: Text(
                    '$value - $wickets${isCentury ? " 🔥" : ""}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: isMilestone
                          ? glowColor
                          : (isDark ? Colors.white : Colors.black87),

                      shadows: isMilestone
                          ? [
                        Shadow(
                          color: glowColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                          : [],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 6),

            // ⏱️ Overs
            Text(
              'Overs: $overs.$balls',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



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


  final Set<int> _usedBatsmen = {};
  final Set<int> _usedBowlers = {};


  Map<int, int> _bowlerOversMap = {};
  int? _lastBowlerId;
  int _matchOvers = 0;
  int _bowlerMaxOvers = 0;




  List<String> timeline = [];
  final Set<String> _submittedBalls = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Step 1: Run both in parallel
      final matchDetailsFuture = _fetchMatchDetails();
      final scoreDataFuture = widget.currentScoreData != null
          ? Future.value(widget.currentScoreData!)
          : _fetchCurrentScoreData(); // ← this gets latest score on open


      // Step 2: Wait for both
      await matchDetailsFuture;
      final scoreData = await scoreDataFuture;

      // Step 3: Parse score
      if (scoreData != null) {
        _parseCurrentScore(scoreData);
      }

      // Step 4: Use preloaded squads if available
      if (widget.preloadedBattingSquad != null &&
          widget.preloadedBowlingSquad != null) {
        _battingSidePlayers = widget.preloadedBattingSquad!;
        _bowlingSidePlayers = widget.preloadedBowlingSquad!;
      } else {
        _loadSquads(); // defer actual fetch after frame
      }

      setState(() {}); // Final UI refresh

    } catch (e) {
      _showError('❌ Failed to load match or score data');
    }
  }




  Future<void> _undoLastBall() async {
    // 1. Call the service
    final ok = await MatchScoreService.undoLastBall(widget.matchId, widget.token,context);
    if (!ok) {
      _showError('❌ Could not undo last ball.');
      return;
    }

    // 2. Remove the most recent entry from timeline & submitted set
    if (timeline.isNotEmpty) timeline.removeAt(0);
    // We know submittedBalls stores strings like "over.ball"
    // so you could keep track of the last key you pushed
    // For simplicity, clear and re-fetch from server:
    _submittedBalls.clear();

    // 3. Re-fetch the latest score & re-parse
    final fresh = await _fetchCurrentScoreData();
    if (fresh != null) _parseCurrentScore(fresh);

    // 4. Update provider / UI
    Provider.of<MatchState>(context, listen: false).updateScore(
      matchId: widget.matchId,
      runs: runs,
      wickets: wickets,
      over: overNumber,
      ball: ballNumber,
    );

    setState(() {});
  }

  Future<String?> _showChangeReasonDialog(String type) async {
    String? selectedReason;
    String customReason = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text("Why are you changing the $type?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text("Injured"),
                value: "Injured",
                groupValue: selectedReason,
                onChanged: (val) => setSt(() => selectedReason = val),
              ),
              RadioListTile<String>(
                title: const Text("Retired Hurt"),
                value: "Retired Hurt",
                groupValue: selectedReason,
                onChanged: (val) => setSt(() => selectedReason = val),
              ),
              RadioListTile<String>(
                title: const Text("Tactical Change"),
                value: "Tactical Change",
                groupValue: selectedReason,
                onChanged: (val) => setSt(() => selectedReason = val),
              ),
              RadioListTile<String>(
                title: const Text("Other"),
                value: "Other",
                groupValue: selectedReason,
                onChanged: (val) => setSt(() => selectedReason = val),
              ),
              if (selectedReason == "Other")
                TextField(
                  autofocus: true,
                  onChanged: (val) => customReason = val,
                  decoration: const InputDecoration(hintText: "Enter reason"),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final result = selectedReason == "Other"
                    ? customReason.trim()
                    : selectedReason;
                if (result == null || result.isEmpty) {
                  _showError("Please select or enter a reason.");
                } else {
                  Navigator.pop(context, result);
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
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
  Future<Map<String, dynamic>?> _showWicketTypeDialog() async {
    final types = [
      {'label': 'Bowled', 'icon': Icons.sports_cricket, 'allowRuns': false},
      {'label': 'Caught', 'icon': Icons.sports_handball, 'allowRuns': false},
      {'label': 'Caught Behind', 'icon': Icons.record_voice_over, 'allowRuns': false},
      {'label': 'LBW', 'icon': Icons.remove_circle, 'allowRuns': false},
      {'label': 'Stumped', 'icon': Icons.cancel, 'allowRuns': false},
      {'label': 'Run Out', 'icon': Icons.directions_run, 'allowRuns': true},
      {'label': 'Run Out (Mankaded)', 'icon': Icons.block, 'allowRuns': true},
      {'label': 'Retired Hurt', 'icon': Icons.healing, 'allowRuns': true},
      {'label': 'Caught & Bowled', 'icon': Icons.reply_all, 'allowRuns': false},
      {'label': 'Absent Hurt', 'icon': Icons.accessibility_new, 'allowRuns': true},
      {'label': 'Time out', 'icon': Icons.timer_off, 'allowRuns': false},
      {'label': 'Hit Ball Twice', 'icon': Icons.replay_circle_filled_outlined, 'allowRuns': false},
    ];

    String? selectedType;
    bool allowRunInput = false;
    final runController = TextEditingController();

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                const Text('Select Wicket Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: types.map((t) {
                    final isSelected = selectedType == t['label'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedType = t['label'] as String;
                          allowRunInput = t['allowRuns'] as bool;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red.shade100 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.red : Colors.redAccent.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t['icon'] as IconData, size: 32, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(
                              t['label'] as String,
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (allowRunInput) ...[
                  const Text("Runs taken before dismissal"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: runController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: "Enter runs (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please select a wicket type")),
                          );
                          return;
                        }

                        final runVal = int.tryParse(runController.text);
                        Navigator.pop(context, {
                          'type': selectedType,
                          'runs': allowRunInput ? (runVal ?? 0) : null,
                        });
                      },
                      child: const Text("Confirm"),
                    )
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
  void _parseCurrentScore(Map<String, dynamic> body) {
    final currentScore = body['current_score'];
    if (currentScore == null) return;

    final inning = currentScore['current_inning'];
    if (inning == null || inning['score'] == null) return;

    final cs = inning['score'] as Map<String, dynamic>;

    final doneOvers = _parseInt(cs['overs_done']);
    final doneBalls = _parseInt(cs['balls_done']);
    final totalBalls = (doneOvers * 6) + doneBalls;

    // ✅ Clear and reconstruct submitted balls set
    _submittedBalls.clear();
    for (int i = 0; i < totalBalls; i++) {
      final over = i ~/ 6;
      final ball = (i % 6) + 1;
      _submittedBalls.add('$over.$ball');
    }

    // ✅ Compute next ball
    final nextBall = (doneBalls % 6) + 1;
    final overAdjustment = (doneBalls % 6 == 0 && doneBalls > 0) ? 1 : 0;
    final nextOver = doneOvers + overAdjustment;

    if (!mounted) return;

    setState(() {
      runs = _parseInt(cs['total_runs']);
      wickets = _parseInt(cs['total_wkts']); // ✅ Correct field to show in UI
      overNumber = nextOver;
      ballNumber = nextBall;

      totalExtras    = _parseInt(cs['total_extra']);
      currentRunRate = double.tryParse(cs['current_run_rate'].toString()) ?? 0;

      // ✅ On-strike batsman
      final on = cs['on_strike'] as Map<String, dynamic>?;
      if (on != null) {
        onStrikePlayerId = _parseInt(on['id']);
        onStrikeName = on['name']?.toString();
        onStrikeRuns = _parseInt(on['runs']);
      }

      // ✅ Non-strike batsman
      final non = cs['non_strike'] as Map<String, dynamic>?;
      if (non != null) {
        nonStrikePlayerId = _parseInt(non['id']);
        nonStrikeName = non['name']?.toString();
        nonStrikeRuns = _parseInt(non['runs']);
      }

      // ✅ Bowler data
      final bw = cs['bowler'] as Map<String, dynamic>?;
      if (bw != null) {
        bowlerId = _parseInt(bw['id']);
        bowlerName = bw['name']?.toString();

        final data = bw['data'] as Map<String, dynamic>?;
        if (data != null) {
          bowlerRunsConceded = _parseInt(data['runs']);
          bowlerWickets      = _parseInt(data['wickets']);
          bowlerMaidens      = _parseInt(data['maiden']);
          bowlerOversBowled  = data['overs']?.toString() ?? '';
          bowlerEconomy      = double.tryParse(data['economy'].toString()) ?? 0;
        }
      }

      // ✅ Timeline
      final timelineRaw = inning['timeline'] as List<dynamic>?;
      if (timelineRaw != null && timelineRaw.isNotEmpty) {
        timeline = timelineRaw
            .map((e) => e.toString())
            .where((line) => RegExp(r'^\d+\.\d+:').hasMatch(line))
            .toList();
      } else {
        timeline = [
          'Previous score loaded: $runs - $wickets at Over $overNumber.$ballNumber'
        ];
      }

      // ✅ Debug
      print('🏏 Runs: $runs | Wickets: $wickets');
      print('🎯 API Strike: ${on?['name']} | Non-Strike: ${non?['name']}');
      print('🔁 Ball: $overNumber.$ballNumber');
    });
  }




  Future<void> _fetchMatchDetails() async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-single-cricket-match'
          '?api_logged_in_token=${widget.token}&match_id=${widget.matchId}',
    );
    final res = await http.get(uri);
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) return;

    final data = (body['data'] as List).first as Map<String, dynamic>;
    if (!mounted) return;

    setState(() {
      matchName = data['match_name']?.toString(); // ✅ moved here
      _teamOneId = data['team_one'] as int;
      _teamTwoId = data['team_two'] as int;
      _teamOne11 = (data['team_one_11'] as String).split(',').map(int.parse).toList();
      _teamTwo11 = (data['team_two_11'] as String).split(',').map(int.parse).toList();
      _firstInningTeamId = data['first_inning'] as int;
      _firstInningClosed = (data['is_first_inning_closed'] as int) == 1;
      teamName = data['team_one_name'] as String? ?? '';

      _matchOvers = _parseInt(data['match_overs']);
      _bowlerMaxOvers = _parseInt(data['ballers_max_overs']);
    });
  }


  Future<void> _loadSquads() async {
    if (_teamOneId == null || _teamTwoId == null || _firstInningTeamId == null) return;

    final battingTeamId = !_firstInningClosed
        ? _firstInningTeamId!
        : (_firstInningTeamId == _teamOneId ? _teamTwoId! : _teamOneId!);
    final bowlingTeamId = battingTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!;
    final battingIds = battingTeamId == _teamOneId! ? _teamOne11 : _teamTwo11;
    final bowlingIds = bowlingTeamId == _teamOneId! ? _teamOne11 : _teamTwo11;

    final squadA = await PlayerService.fetchTeamPlayers(
        teamId: battingTeamId, apiToken: widget.token);
    final squadB = await PlayerService.fetchTeamPlayers(
        teamId: bowlingTeamId, apiToken: widget.token);

    if (!mounted) return;

    setState(() {
      _battingSidePlayers = squadA.map((p) {
        final rawId = p['ID'];
        final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
        return {'id': id, 'name': p['display_name'] as String};
      }).where((p) =>
      battingIds.contains(p['id']) &&
          p['id'] != onStrikePlayerId &&
          p['id'] != nonStrikePlayerId
      ).toList();

      _bowlingSidePlayers = squadB.map((p) {
        final rawId = p['ID'];
        final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
        return {'id': id, 'name': p['display_name'] as String};
      }).where((p) => bowlingIds.contains(p['id'])).toList();
    });
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


  //// part3
  Future<void> _submitScore() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    print('🆔 Submitting run for Match ID: ${widget.matchId}');

    try {
      // 1. Check if innings is already complete
      final current = await _fetchCurrentScoreData();
      if (current != null) {
        final cs = current['current_score']?['current_inning']?['score'];
        final oversDone = _parseInt(cs?['overs_done']);
        final ballsDone = _parseInt(cs?['balls_done']);
        final totalBalls = (oversDone * 6) + ballsDone;
        final maxBalls = _matchOvers * 6;
        if (totalBalls >= maxBalls) {
          _showError('🚫 Innings already completed.');
          _showMatchEndDialog("Innings Over - $_matchOvers Overs Completed");
          return;
        }
      }

      // 2. Validate inputs
      if (onStrikePlayerId == null || nonStrikePlayerId == null || bowlerId == null) {
        _showError('Please select striker, non-striker, and bowler');
        return;
      }

      final ballKey = '$overNumber.$ballNumber';
      if (_submittedBalls.contains(ballKey)) {
        _showError('⚠️ Ball $ballKey already submitted. Please proceed to next ball.');
        return;
      }

      _usedBatsmen.add(onStrikePlayerId!);
      _usedBatsmen.add(nonStrikePlayerId!);
      _usedBowlers.add(bowlerId!);

      final battingTeamId = !_firstInningClosed
          ? _firstInningTeamId!
          : (_firstInningTeamId == _teamOneId! ? _teamTwoId! : _teamOneId!);

      // 3. Calculate runs and legal delivery
      int totalRuns = 0;
      bool legalDelivery = true;

      if (selectedExtra != null) {
        switch (selectedExtra) {
          case 'Wide':
          case 'No Ball':
            legalDelivery = false;
            totalRuns += selectedRuns ?? 0;
            if (selectedExtra == 'No Ball') _isFreeHit = true;
            break;
          case 'Bye':
          case 'Leg Bye':
            totalRuns += selectedRuns ?? 0;
            break;
        }
      } else {
        totalRuns = selectedRuns ?? 0;
      }

      // 4. Handle wicket and Free Hit logic
      bool wicketFalls = isWicket;
      if (_isFreeHit && wicketType != 'Run Out') {
        wicketFalls = false;
      }
      if (wicketFalls) wickets++;

      // 5. Prepare request
      final req = MatchScoreRequest(
        matchId: widget.matchId,
        battingTeamId: battingTeamId,
        onStrikePlayerId: onStrikePlayerId!,
        onStrikePlayerOrder: 1,
        nonStrikePlayerId: nonStrikePlayerId!,
        nonStrikePlayerOrder: 2,
        bowler: bowlerId!,
        overNumber: overNumber + 1,
        ballNumber: ballNumber,
        runs: totalRuns,
        extraRunType: selectedExtra,
        extraRun: (selectedExtra != null && selectedExtra != 'Wide' && selectedExtra != 'No Ball')
            ? selectedRuns
            : null,
        isWicket: wicketFalls ? 1 : 0,
        wicketType: wicketFalls ? wicketType : null,
      );

      print('🧮 Sending Over.Ball → $overNumber.$ballNumber');

      final success = await MatchScoreService.submitScore(req, widget.token, context);
      if (!success) {
        _showError('❌ Failed to submit score. Try again.');
        return;
      }

      // 6. Optional Shot Type
      final skipShotTypes = ['Bowled', 'LBW'];
      if (!wicketFalls || (wicketFalls && !skipShotTypes.contains(wicketType))) {
        final shot = await showShotTypeDialog(context, onStrikeName ?? 'Batsman', selectedRuns ?? 0);
        if (shot != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Shot: $shot')),
          );
        }
      }

      // 7. Timeline entry
      final entry = '$overNumber.$ballNumber: '
          '${selectedExtra != null ? '$selectedExtra +${selectedRuns ?? 0}' : '$selectedRuns'}'
          '${wicketFalls ? ' 🧨 Wicket($wicketType)' : ''}';
      timeline.insert(0, entry);
      _submittedBalls.add(ballKey);

      // 8. Swap strike if needed
      bool didLocalSwap = false;
      if (legalDelivery && !wicketFalls && (totalRuns % 2) == 1) {
        _swapStrike();
        didLocalSwap = true;
      }

      // 9. Advance ball
      if (legalDelivery) _advanceBall();

      // 10. New batsman if wicket
      if (wicketFalls) _showBatsmanSelectionAfterWicket();

      // 11. Update local + provider
      _isFreeHit = false;
      _resetInputs();

      Provider.of<MatchState>(context, listen: false).updateScore(
        matchId: widget.matchId,
        runs: runs,
        wickets: wickets,
        over: overNumber,
        ball: ballNumber,
      );

      // 12. Re-fetch latest data
      await Future.delayed(const Duration(milliseconds: 800));
      final refreshed = await _fetchCurrentScoreData();
      if (refreshed != null) {
        _parseCurrentScore(refreshed);
        if (didLocalSwap) _swapStrike();
        setState(() {});
      }

    } finally {
      _isSubmitting = false;
    }
  }




  void _advanceBall() {
    if (ballNumber >= 6) {
      overNumber++;
      ballNumber = 1;

      if (overNumber > _matchOvers) {
        _inningsOver = true; // ✅ Stop further submissions
        _showMatchEndDialog("Innings Over - $_matchOvers Overs Completed");
        return;
      }


      // ✅ Track overs bowled by last bowler
      if (_lastBowlerId != null) {
        _bowlerOversMap[_lastBowlerId!] = (_bowlerOversMap[_lastBowlerId!] ?? 0) + 1;
      }

      _lastBowlerId = bowlerId;
      _swapStrike();
      _showBowlerSelectionAfterOver();
    } else {
      ballNumber++;
    }
  }


  void _swapStrike() {
    final tmpId = onStrikePlayerId;
    final tmpName = onStrikeName;
    final tmpRuns = onStrikeRuns;

    onStrikePlayerId = nonStrikePlayerId;
    onStrikeName = nonStrikeName;
    onStrikeRuns = nonStrikeRuns;

    nonStrikePlayerId = tmpId;
    nonStrikeName = tmpName;
    nonStrikeRuns = tmpRuns;

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

  void _showBatsmanSelectionAfterWicket() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wt = wicketType;
      final forceStrike = [
        'Bowled',
        'Caught',
        'Caught Behind',
        'LBW',
        'Stumped',
        'Caught & Bowled',
        'Hit Ball Twice'
      ].contains(wt);
      final chooseRole = [
        'Run Out',
        'Run Out (Mankaded)'
      ].contains(wt);

      // true  → always on-strike
      // null  → show the role-choice dialog
      // false → always non-strike
      final bool? selectForStriker = forceStrike
          ? true
          : (chooseRole ? null : false);

      _showSelectPlayerSheet(
        isBatsman: true,
        selectForStriker: selectForStriker,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batsman out. Please select a new batsman.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }



  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showMatchEndDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Match Ended"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void _showSelectPlayerSheet({
    required bool isBatsman,
    bool? selectForStriker,
  }) {
    final source = isBatsman
        ? _battingSidePlayers.where((p) => !_usedBatsmen.contains(p['id'])).toList()
        : _bowlingSidePlayers.where((p) => !_usedBowlers.contains(p['id'])).toList();

    if (source.isEmpty) {
      _showError("No more ${isBatsman ? "batsmen" : "bowlers"} available to select.");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          color: Theme.of(context).canvasColor,
          height: 400,
          child: ListView.builder(
            itemCount: source.length,
            itemBuilder: (_, i) {
              final p = source[i];
              return ListTile(
                leading: CircleAvatar(child: Text(p['name'][0])),
                title: Text(p['name'] as String),
                onTap: () {
                  if (isBatsman) {
                    final selectedId   = p['id']   as int;
                    final selectedName = p['name'] as String;

                    if (selectForStriker != null) {
                      // Inline assignment mode
                      if (selectForStriker) {
                        // force on-strike
                        if (selectedId == nonStrikePlayerId) {
                          _showError("Already selected as non-striker.");
                          return;
                        }
                        onStrikePlayerId = selectedId;
                        onStrikeName     = selectedName;
                        onStrikeRuns     = 0;      // reset their runs
                      } else {
                        // force non-strike
                        if (selectedId == onStrikePlayerId) {
                          _showError("Already selected as striker.");
                          return;
                        }
                        nonStrikePlayerId = selectedId;
                        nonStrikeName     = selectedName;
                        nonStrikeRuns     = 0;      // reset their runs
                      }
                      Navigator.pop(context);
                      setState(() {});
                    } else {
                      // let the user choose on-strike vs non-strike
                      _showBatsmanRoleDialog(p);
                    }

                  } else {
                    // bowling selection
                    bowlerId   = p['id'] as int;
                    bowlerName = p['name'] as String;
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }



  void _showBatsmanRoleDialog(Map<String, dynamic> player) {
    String? role;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text("Select Batsman Role"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text("On Strike"),
                value: "on",
                groupValue: role,
                onChanged: (v) => setSt(() => role = v),
              ),
              RadioListTile<String>(
                title: const Text("Non Strike"),
                value: "non",
                groupValue: role,
                onChanged: (v) => setSt(() => role = v),
              ),
            ],
          ),


          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                final newId = player['id'] as int;
                if (role == "on") {
                  if (newId == nonStrikePlayerId) {
                    _showError("Player already selected as non-striker.");
                    return;
                  }
                  onStrikePlayerId = newId;
                  onStrikeName = player['name'] as String;
                } else {
                  if (newId == onStrikePlayerId) {
                    _showError("Player already selected as striker.");
                    return;
                  }
                  nonStrikePlayerId = newId;
                  nonStrikeName = player['name'] as String;
                }
                Navigator.pop(ctx);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      }),
    );
  }
/////Part5

  Widget _buildStatsHeader() {
    final isLoading = matchName == null || (runs == 0 && wickets == 0 && overNumber == 0);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            SizedBox(height: 12),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading score & match details...', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.white12 : Colors.white.withOpacity(0.1);
    final borderColor = isDark ? Colors.white10 : Colors.white54;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            matchName ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(teamName, style: const TextStyle(fontSize: 16)),
          Text(
            _firstInningClosed ? '2nd Innings' : '1st Innings',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Text(
            '$runs - $wickets',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text('Overs: $overNumber.$ballNumber',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800])),
        ],
      ),
    );
  }
  Widget _buildPlayerTables() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏏 Batsmen Row
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _batsmanColumn(
                            label: "On Strike",
                            name: onStrikeName,
                            runs: onStrikeRuns,
                            //    balls: onStrikeBalls,
                            isStriker: true,
                          ),
                          _batsmanColumn(
                            label: "Non Strike",
                            name: nonStrikeName,
                            runs: nonStrikeRuns,
                            //   balls: nonStrikeBalls,
                            isStriker: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),


              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🎯 Bowler Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sports_baseball, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        //  const Text('Bowlers', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bowlerName ?? '-',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            if (ballNumber != 1) {
                              final reason = await _showChangeReasonDialog("bowler");
                              if (reason == null || reason.trim().isEmpty) {
                                _showError("Bowler change canceled.");
                                return;
                              }
                            }
                            _showSelectPlayerSheet(isBatsman: false);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.edit, size: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Text(bowlerName ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _statTile("Overs", bowlerOversBowled),
                        _statTile("Maidens", "$bowlerMaidens"),
                        _statTile("Runs", "$bowlerRunsConceded"),
                        _statTile("Wickets", "$bowlerWickets"),
                        _statTile("Economy", bowlerEconomy.toStringAsFixed(2)),
                        _statTile("Extras", "$totalExtras"),
                        _statTile("Run Rate", currentRunRate.toStringAsFixed(2)),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }


  Widget _batsmanColumn({
    required String label,
    String? name,
    required int runs,
    int balls = 0,
    bool isStriker = false,
  }) {
    final strikeRate = (balls > 0) ? ((runs / balls) * 100).toStringAsFixed(1) : '-';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: isStriker
          ? BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200, width: 1),
      )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),

          // 🏏 Name + ✏️ Edit icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isStriker) const Text('🏏', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                name ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () async {
                  if (ballNumber != 1) {
                    final reason = await _showChangeReasonDialog("batsman");
                    if (reason == null || reason.trim().isEmpty) {
                      _showError("Batsman change canceled.");
                      return;
                    }
                  }
                  _showSelectPlayerSheet(isBatsman: true, selectForStriker: isStriker);
                },
                child: const Icon(Icons.edit, size: 16, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text('$runs Runs', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }


  Widget _buildScoringInputs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Runs', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [0, 1, 2, 3, 4, 6].map((r) {
              return ChoiceChip(
                label: Text('$r'),
                selected: selectedRuns == r,
                selectedColor: isDark ? Colors.tealAccent.shade400 : Colors.teal,
                onSelected: _isSubmitting
                    ? null
                    : (_) {
                  setState(() => selectedRuns = r);
                  _submitScore();
                },
                labelStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              );

            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Wide', 'No Ball', 'Bye', 'Leg Bye'].map((e) {
              return ChoiceChip(
                label: Text(e),
                selected: selectedExtra == e,
                selectedColor: Colors.orange.shade700,
                onSelected: (_) async {
                  switch (e) {
                    case 'Wide':
                      final run = await _showExtraRunDialog('Wide Ball', 'WD');
                      if (run != null) {
                        setState(() {
                          selectedExtra = 'Wide';
                          selectedRuns = run;
                        });
                        _submitScore();
                      }
                      break;

                    case 'Bye':
                      final run = await _showExtraRunDialog('Bye Runs', 'BYE');
                      if (run != null) {
                        setState(() {
                          selectedExtra = 'Bye';
                          selectedRuns = run;
                        });
                        _submitScore();
                      }
                      break;

                    case 'No Ball':
                      final run = await _showExtraRunDialog('No Ball', 'NB');
                      if (run != null) {
                        setState(() {
                          selectedExtra = 'No Ball';
                          selectedRuns = run;
                        });
                        _submitScore();
                      }
                      break;

                    case 'Leg Bye':
                      final run = await _showExtraRunDialog('Leg Bye', 'LB');
                      if (run != null) {
                        setState(() {
                          selectedExtra = 'Leg Bye';
                          selectedRuns = run;
                        });
                        _submitScore();
                      }
                      break;
                  }
                },
                labelStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              );
            }).toList(),
          ),


          const SizedBox(height: 20),

          // 📦 Wicket + Swap + Undo Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: isWicket,
                onChanged: (v) async {
                  print('🔔 [DEBUG] Checkbox onChanged → $v');
                  if (v == true) {
                    // 1. launch wicket dialog
                    final result = await _showWicketTypeDialog();
                    print('🔔 [DEBUG] _showWicketTypeDialog returned → $result');
                    if (result != null) {
                      setState(() {
                        isWicket    = true;
                        wicketType  = result['type'] as String?;
                        selectedRuns = result['runs'] ?? 0;
                      });
                      print('🔔 [DEBUG] About to call _submitScore (type=$wicketType runs=$selectedRuns)');
                      await _submitScore();
                    } else {
                      print('🔔 [DEBUG] User cancelled wicket dialog');
                      setState(() {
                        isWicket   = false;
                        wicketType = null;
                      });
                    }
                  } else {
                    print('🔔 [DEBUG] Checkbox unchecked');
                    setState(() {
                      isWicket   = false;
                      wicketType = null;
                    });
                  }
                },
                activeColor: Colors.redAccent,
              ),



              const Text('Wicket', style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _swapStrike();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Striker and non-striker swapped!')),
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Swap'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _undoLastBall,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Undo'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

/////part7

  Widget _buildGlassyButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.white12 : AppColors.primary;
    final borderColor = isDark ? Colors.white24 : AppColors.primary;
    final shadowColor =
    isDark ? Colors.white12 : AppColors.primary.withOpacity(0.4);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: isDark
              ? const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(20)),
          )
              : const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Match Score',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),

          ),
        ),
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              AnimatedScoreCard(
                matchType: matchName ?? 'Match',
                teamName: teamName,
                isSecondInnings: _firstInningClosed,
                runs: runs,
                wickets: wickets,
                overs: overNumber,
                balls: ballNumber,
              ),

              const SizedBox(height: 20),
              _buildPlayerTables(),
              _buildScoringInputs(),
            ],
          )
      ),
    );
  }
}
