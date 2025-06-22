import 'package:flutter/material.dart';
import '../service/match_detail_service.dart';
import '../theme/color.dart';
import '../model/match_summary_model.dart';
import 'match_commentary_tab.dart';
import 'match_info_tab.dart';
import 'match_stats_tab.dart';
import 'match_summary_tab.dart';
import 'scorecard_screen.dart';
import 'match_squad_tab.dart';

class FullMatchDetail extends StatefulWidget {
  final int matchId;

  const FullMatchDetail({Key? key, required this.matchId}) : super(key: key);

  @override
  _FullMatchDetailState createState() => _FullMatchDetailState();
}

class _FullMatchDetailState extends State<FullMatchDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MatchSummary? summaryData;
  bool isLoading = true;
  String? error;

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
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadSummaryData();
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
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            "Match Detail",
            style: TextStyle(color: Colors.white),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _tabs,
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : (error != null
            ? Center(child: Text(error!))
            : Builder(builder: (_) {
          // 1) Cast rawMatchData to Map
          final raw =
          summaryData!.rawMatchData as Map<String, dynamic>;

          // 2) Extract the two innings' team IDs
          final team1Id = raw['team_1']['team_id'] as int;
          final team2Id = raw['team_2']['team_id'] as int;

          // 3) Use the stored display names
          final team1Name = summaryData!.teamAName;
          final team2Name = summaryData!.teamBName;

          return TabBarView(
            controller: _tabController,
            children: [
              // Summary screen
              MatchSummaryTab(
                summary: summaryData!.rawSummary,
                matchData: summaryData!.rawMatchData,
              ),

              // Scorecard
              ScorecardScreen(matchId: widget.matchId),

              // Squad
              MatchSquadTab(matchId: widget.matchId),

              // Stats
              MatchStatsTab(
                matchId: widget.matchId,
                team1Name: team1Name,
                team2Name: team2Name,
              ),

              // Info
              MatchInfoTab(matchData: summaryData!.rawMatchData),

              // **Commentary** ← here we pass in both IDs & names
              MatchCommentaryTab(
                matchId: widget.matchId,
                team1Id: team1Id,
                team2Id: team2Id,
                team1Name: team1Name,
                team2Name: team2Name,
              ),
            ],
          );
        })),
      ),
    );
  }
}
