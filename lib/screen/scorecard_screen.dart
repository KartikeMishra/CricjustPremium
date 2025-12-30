// lib/screen/scorecard_screen.dart
import 'dart:ui'; // FontFeature.tabularFigures
import 'package:flutter/material.dart';

import '../model/match_scorecard_model.dart';
import '../service/match_detail_service.dart';
import '../screen/player_info.dart';

class ScorecardScreen extends StatefulWidget {
  final int matchId;
  const ScorecardScreen({super.key, required this.matchId});

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  late Future<MatchScorecardResponse> _scorecardFuture;

  @override
  void initState() {
    super.initState();
    _loadScorecard();
  }

  void _loadScorecard() {
    _scorecardFuture = MatchScorecardService.fetchScorecard(widget.matchId);
  }

  Future<void> _refreshScorecard() async {
    setState(_loadScorecard);
  }

  // ---------- API order helpers (sort strictly by orderIndex) ----------
  List<PlayerScore> _apiOrderPlayers(TeamScore team) {
    final list = List<PlayerScore>.from(team.details.players);
    list.sort((a, b) => (a.orderIndex ?? 1 << 20).compareTo(b.orderIndex ?? 1 << 20));
    return list;
  }

  List<YetToBat> _apiOrderYetToBat(TeamScore team) {
    final list = List<YetToBat>.from(team.details.yetToBat);
    list.sort((a, b) => (a.orderIndex ?? 1 << 20).compareTo(b.orderIndex ?? 1 << 20));
    return list;
  }

  List<BowlerStats> _apiOrderBowlers(TeamScore team) {
    final list = List<BowlerStats>.from(team.details.bowlers);
    list.sort((a, b) => (a.orderIndex ?? 1 << 20).compareTo(b.orderIndex ?? 1 << 20));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0F1115), Color(0xFF1A1F26)]
                : [const Color(0xFFE9F3FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<MatchScorecardResponse>(
            future: _scorecardFuture,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _buildLoading(isDark);
              }
              if (snap.hasError) {
                return _buildNoData('Error: ${snap.error}');
              }
              if (!snap.hasData ||
                  snap.data == null ||
                  snap.data!.scorecard.isEmpty ||
                  snap.data!.data.isEmpty) {
                return _buildNoData('No scorecard available');
              }

              final resp = snap.data!;
              final meta = resp.data.first;

              final firstId = (meta['first_inning'] as int?) ??
                  resp.scorecard.first.team1.teamId;
              final secondId = (meta['second_inning'] as int?) ??
                  resp.scorecard.first.team2.teamId;

              final wrapper = resp.scorecard.first;
              final teams = [wrapper.team1, wrapper.team2];

              final firstTeam = teams.firstWhere(
                    (t) => t.teamId == firstId,
                orElse: () => teams[0],
              );
              final secondTeam = teams.firstWhere(
                    (t) => t.teamId == secondId,
                orElse: () => teams[1],
              );

              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildTabSelector(
                        firstTeam.teamName, secondTeam.teamName, isDark),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TabBarView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          RefreshIndicator(
                            onRefresh: _refreshScorecard,
                            child: _buildInningContent(
                                firstTeam, secondTeam, isDark),
                          ),
                          RefreshIndicator(
                            onRefresh: _refreshScorecard,
                            child: _buildInningContent(
                                secondTeam, firstTeam, isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------- Loading ----------------

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.lightBlueAccent : const Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fetching scorecard…',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Tabs (glowing pill) ----------------

  Widget _buildTabSelector(String teamA, String teamB, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
              isDark ? Colors.black.withOpacity(.45) : Colors.black.withOpacity(.08),
              blurRadius: 14,
              offset: const Offset(0, 8),
            )
          ],
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        padding: const EdgeInsets.all(6),
        child: TabBar(
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.blueGrey.shade600, Colors.blueGrey.shade400]
                  : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (isDark
                    ? Colors.lightBlueAccent
                    : const Color(0xFF1976D2))
                    .withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor:
          isDark ? Colors.grey[300] : const Color(0xFF1976D2),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          dividerColor: Colors.transparent,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          tabs: [
            Tab(child: _tabLabel(Icons.sports_cricket, teamA)),
            Tab(child: _tabLabel(Icons.sports_cricket_outlined, teamB)),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel(IconData icon, String text) {
    return FittedBox(
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ---------------- Inning ----------------

  Widget _buildInningContent(TeamScore bat, TeamScore bowl, bool isDark) {
    final rr = bat.oversDone > 0 ? (bat.totalRuns / bat.oversDone) : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            isDark: isDark,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip('Total', '${bat.totalRuns}/${bat.totalWickets}', isDark),
                _chip('Overs', bat.oversDone.toStringAsFixed(1), isDark),
                _chip('Extras', bat.extras, isDark),
                _chip('RR', rr.toStringAsFixed(2), isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Batting strictly by API index
          _buildCard(child: _buildBattingTable(bat), isDark: isDark),

          const SizedBox(height: 12),

          if (bat.details.yetToBat.isNotEmpty)
            _buildCard(
              isDark: isDark,
              child: _yetToBatInner(bat, isDark),
            ),

          const SizedBox(height: 12),

          // Bowling strictly by API index
          _buildCard(child: _buildBowlingTable(bowl), isDark: isDark),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------- Chips ----------------

  Widget _chip(String label, String value, bool isDark) {
    final gradient = isDark
        ? [const Color(0x332196F3), const Color(0x332197D2)]
        : [Colors.blue.shade100, Colors.blue.shade50];
    final txtAccent = isDark ? Colors.lightBlue[200]! : const Color(0xFF1976D2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: txtAccent),
          ),
        ],
      ),
    );
  }

  Widget _numCell(String v, {Color? color}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        v,
        textAlign: TextAlign.right,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _yetToBatInner(TeamScore bat, bool isDark) {
    final nameColor = isDark ? Colors.white : Colors.blue[800];
    final ytb = _apiOrderYetToBat(bat); // enforce API order

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yet to Bat',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ytb.map((pt) {
            return GestureDetector(
              onTap: () => _navigateToPlayer(pt.playerId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.blue.withOpacity(.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Text(
                  pt.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: nameColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------- Tables ----------------

  Widget _buildBattingTable(TeamScore team) {
    const battingFlex = [5, 1, 1, 1, 1, 2]; // SR wider
    final players = _apiOrderPlayers(team); // ⬅️ API order by orderIndex

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(['Batsman', 'R', 'B', '4s', '6s', 'SR'], flex: battingFlex),
        const SizedBox(height: 6),
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No batting data',
                style: TextStyle(color: Theme.of(context).hintColor)),
          )
        else
          ...players.map((p) => _playerRow(
            name: p.name,
            info: p.isOut ? p.outBy : 'Not out',
            onTap: () => _navigateToPlayer(p.playerId),
            values: [
              '${p.runs}',
              '${p.balls}',
              '${p.fours}',
              '${p.sixes}',
              p.strikeRate.toStringAsFixed(1),
            ],
            flex: battingFlex,
            positive: !p.isOut,
          )),
      ],
    );
  }

  Widget _buildBowlingTable(TeamScore team) {
    const bowlingFlex = [5, 1, 1, 1, 1, 2]; // Econ wider
    final bowlers = _apiOrderBowlers(team); // ⬅️ API order by orderIndex

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(['Bowler', 'O', 'R', 'W', 'M', 'Econ'], flex: bowlingFlex),
        const SizedBox(height: 6),
        if (bowlers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No bowling data',
                style: TextStyle(color: Theme.of(context).hintColor)),
          )
        else
          ...bowlers.map((b) => _playerRow(
            name: b.name,
            onTap: () => _navigateToPlayer(b.playerId),
            values: [
              b.overs.toStringAsFixed(1),
              '${b.runs}',
              '${b.wickets}',
              '${b.maiden}',
              b.economy.toStringAsFixed(1),
            ],
            flex: bowlingFlex,
            positive: b.wickets > 0,
          )),
      ],
    );
  }

  Widget _playerRow({
    required String name,
    String? info,
    required List<String> values,
    List<int> flex = const [5, 1, 1, 1, 1, 1],
    VoidCallback? onTap,
    bool positive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0x151FFFFFF) : Colors.white;
    final border = isDark ? Colors.white10 : Colors.black12;

    final positiveColor = positive
        ? (isDark ? Colors.greenAccent : Colors.green[700])
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          // name + dismissal
          Expanded(
            flex: flex.isNotEmpty ? flex[0] : 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.lightBlue[200]
                            : const Color(0xFF1976D2),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.lightBlue[200] : Colors.blue[800],
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (info != null && info.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.5),
                    child: Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: info.contains('Not out')
                            ? Colors.green
                            : (isDark ? Colors.red[300] : Colors.red[700]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // metrics (right-aligned)
          for (int i = 0; i < values.length; i++)
            Expanded(
              flex: (i + 1 < flex.length) ? flex[i + 1] : 1,
              child: _numCell(values[i], color: positiveColor),
            ),
        ],
      ),
    );
  }

  Widget _headerRow(List<String> labels, {required List<int> flex}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(
              labels[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------- Card wrapper ----------------

  Widget _buildCard({
    required Widget child,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  // ---------------- Empty state ----------------

  Widget _buildNoData(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_cricket,
              size: 90,
              color: isDark
                  ? Colors.grey[600]
                  : Colors.blueAccent.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Navigation ----------------

  void _navigateToPlayer(int playerId) {
    if (playerId > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPublicInfoTab(playerId: playerId),
        ),
      );
    }
  }
}
