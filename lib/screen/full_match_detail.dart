import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../service/match_detail_service.dart';
import '../theme/color.dart';
import '../model/match_summary_model.dart';

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
  MatchSummary? summaryData;
  bool isLoading = true;
  String? error;
  int? _currentUserId;

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
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            title: const Text(
              'Match Details',
              style: TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(child: Text(error!)),
        ),
      );
    }

    final raw = summaryData!.rawMatchData;
    final matchDateTime = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).parse('${raw['match_date']} ${raw['match_time']}');
    final now = DateTime.now();
    final isUpcoming = matchDateTime.isAfter(now);
    final isLive = raw['status'] == 'live';
    final ownerId = raw['user_id'] as int?;
    final canEdit =
        (isUpcoming || isLive) && ownerId != null && ownerId == _currentUserId;
    final team1Id = raw['team_1']['team_id'] as int;
    final team2Id = raw['team_2']['team_id'] as int;
    final team1Name = summaryData!.teamAName;
    final team2Name = summaryData!.teamBName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[100],
        // ←— UPDATED APPBAR STARTS HERE —————————————
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(
            kToolbarHeight + kTextTabBarHeight,
          ),
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
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title Row ──
                  SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        BackButton(color: Colors.white),
                        const Expanded(
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
                        // if you want a placeholder to keep title centered:
                        const SizedBox(width: kToolbarHeight),
                      ],
                    ),
                  ),
                  // ── TabBar Row ──
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

        // ←— UPDATED APPBAR ENDS HERE —————————————
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
    );
  }
}
