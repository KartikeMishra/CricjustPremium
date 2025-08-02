import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../service/match_detail_service.dart';
import '../service/match_score_service.dart';
import '../theme/color.dart';
import '../model/match_summary_model.dart';

import '../widget/tv_score_banner.dart';
import 'match_summary_tab.dart';
import 'scorecard_screen.dart';
import 'match_squad_tab.dart';
import 'match_stats_tab.dart';
import 'match_info_tab.dart';
import 'match_commentary_tab.dart';

class FullMatchDetail extends StatefulWidget {
  final int matchId;
  const FullMatchDetail({super.key, required this.matchId});

  @override
  _FullMatchDetailState createState() => _FullMatchDetailState();
}

class _FullMatchDetailState extends State<FullMatchDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _autoRefreshTimer;

  MatchSummary? summaryData;
  bool isLoading = true;
  String? error;
  int? _currentUserId;
  Map<String, dynamic>? _liveScore;
  String? _token;

  final List<Tab> _tabs = const [
    Tab(text: 'Summary'),
    Tab(text: 'Scorecard'),
    Tab(text: 'Squad'),
    Tab(text: 'Stats'),
    Tab(text: 'Info'),
    Tab(text: 'Commentary'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadSummaryData();
    _fetchLiveScore();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchLiveScore();
    });
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
      _token = prefs.getString('api_logged_in_token');
    });
  }

  Future<void> _loadSummaryData() async {
    try {
      final result = await MatchService.fetchMatchSummary(widget.matchId);
      setState(() {
        summaryData = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load match detail.';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLiveScore() async {
    final url = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-current-match-score?match_id=${widget.matchId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 &&
            data['current_score']?['current_inning'] != null) {
          final inning = data['current_score']['current_inning'];

          // ✅ Inject last ball if missing or null
          if (inning['score'] != null) {
            if (!inning['score'].containsKey('last_ball') || inning['score']['last_ball'] == null) {
              final teamId = inning['team_id'];
              final lastBalls = await MatchScoreService.fetchLastBalls(widget.matchId, teamId);
              if (lastBalls.isNotEmpty) {
                final latest = lastBalls.first;
                inning['score']['last_ball'] = latest['runs'].toString(); // 👈 Use fallback
              } else {
                inning['score']['last_ball'] = '0'; // 👈 Ensure no dot shown
              }
            }
          }

          setState(() {
            _liveScore = inning;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ _fetchLiveScore error: $e');
    }
  }


  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  double _oversAsDouble(Map<String, dynamic> score) {
    final int oversDone = (score['overs_done'] ?? 0) is int
        ? score['overs_done']
        : int.tryParse(score['overs_done'].toString()) ?? 0;

    final int ballsDone = int.tryParse(score['balls_done'].toString()) ?? 0;
    return double.tryParse('$oversDone.$ballsDone') ?? oversDone.toDouble();
  }

  String _lastBallType(Map<String, dynamic> score) {

    final lastBall = score['last_ball'];
    if (lastBall == null || lastBall.toString().isEmpty) return '0';

    final ballStr = lastBall.toString().toLowerCase();

    if (ballStr.contains('wicket') || ballStr == 'w') return 'W';
    if (["0", "1", "2", "3", "4", "5", "6"].contains(ballStr)) return ballStr;


    return '0'; // fallback
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SafeArea(
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (error != null) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            title: const Text('Match Details', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(child: Text(error!)),
        ),
      );
    }

    final raw = summaryData!.rawMatchData;
    final matchDateTime = DateFormat('yyyy-MM-dd HH:mm:ss')
        .parse('${raw['match_date']} ${raw['match_time']}');
    final now = DateTime.now();
    final isUpcoming = matchDateTime.isAfter(now);
    final isLive = raw['status'] == 'live';
    final ownerId = raw['user_id'] as int?;
    final canEdit = (isUpcoming || isLive) && ownerId != null && ownerId == _currentUserId;
    final team1Id = raw['team_1']['team_id'] as int;
    final team2Id = raw['team_2']['team_id'] as int;
    final team1Name = summaryData!.teamAName;
    final team2Name = summaryData!.teamBName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[100],
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + kTextTabBarHeight),
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
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: const [
                        BackButton(color: Colors.white),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Match Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: kToolbarHeight),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: kTextTabBarHeight,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: _tabs,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            if (_liveScore != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TVStyleScoreScreen(
                    teamName: _liveScore!['team_name'] ?? '',
                    runs: int.tryParse(_liveScore!['score']['total_runs'].toString()) ?? 0,
                    wickets: int.tryParse(_liveScore!['score']['total_wkts'].toString()) ?? 0,
                    overs: _oversAsDouble(_liveScore!['score']),
                    lastBallType: _lastBallType(_liveScore!['score']),
                    isLive: isLive,
                  ),
                ),
              ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              MatchSummaryTab(
                matchId: widget.matchId,
                summary: summaryData!.rawSummary,
                matchData: summaryData!.rawMatchData,
              ),
              ScorecardScreen(matchId: widget.matchId),
              MatchSquadTab(matchId: widget.matchId),
              MatchStatsTab(
                matchId: widget.matchId,
                team1Name: team1Name,
                team2Name: team2Name,
              ),
              MatchInfoTab(matchData: summaryData!.rawMatchData),
              MatchCommentaryTab(
                matchId: widget.matchId,
                team1Id: team1Id,
                team2Id: team2Id,
                team1Name: team1Name,
                team2Name: team2Name,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
