// lib/screen/scorecard_screen.dart
import 'dart:ui'; // for FontFeature.tabularFigures()
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF6F9FC),
      body: SafeArea(
        child: FutureBuilder<MatchScorecardResponse>(
          future: _scorecardFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
            final firstId  = (meta['first_inning']  as int?) ?? resp.scorecard.first.team1.teamId;
            final secondId = (meta['second_inning'] as int?) ?? resp.scorecard.first.team2.teamId;

            final wrapper = resp.scorecard.first;
            final teams = [wrapper.team1, wrapper.team2];

            final firstTeam  = teams.firstWhere((t) => t.teamId == firstId,  orElse: () => teams[0]);
            final secondTeam = teams.firstWhere((t) => t.teamId == secondId, orElse: () => teams[1]);

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildTabSelector(firstTeam.teamName, secondTeam.teamName, isDark),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Expanded(
                      child: TabBarView(
                        physics: const BouncingScrollPhysics(), // optional
                        children: [
                          RefreshIndicator(
                            onRefresh: _refreshScorecard,
                            child: _buildInningContent(firstTeam, secondTeam, isDark),
                          ),
                          RefreshIndicator(
                            onRefresh: _refreshScorecard,
                            child: _buildInningContent(secondTeam, firstTeam, isDark),
                          ),
                        ],
                      ),
                    ),

                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- Tabs (simplified card) ----------

  Widget _buildTabSelector(String teamA, String teamB, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: TabBar(
            indicator: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(30),
              boxShadow: isDark
                  ? null
                  : const [
                BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? Colors.grey[300] : const Color(0xFF1976D2),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: [
              Tab(child: _tabLabel(Icons.sports_cricket, teamA)),
              Tab(child: _tabLabel(Icons.sports_cricket_outlined, teamB)),
            ],
          ),
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

  // ---------- Inning ----------

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
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Total', '${bat.totalRuns}/${bat.totalWickets}'),
                _chip('Overs', bat.oversDone.toStringAsFixed(1)),
                _chip('Extras', bat.extras),
                _chip('RR', rr.toStringAsFixed(2)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(child: _buildBattingTable(bat), isDark: isDark),
          const SizedBox(height: 12),
          if (bat.details.yetToBat.isNotEmpty)
            _buildCard(
              isDark: isDark,
              child: _yetToBatInner(bat, isDark),
            ),
          const SizedBox(height: 12),
          _buildCard(child: _buildBowlingTable(bowl), isDark: isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(value),
      ]),
    );
  }

  Widget _yetToBatInner(TeamScore bat, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Yet to Bat',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bat.details.yetToBat.map((pt) {
            return GestureDetector(
              onTap: () => _navigateToPlayer(pt.playerId),
              child: Container(
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
                    color: isDark ? Colors.white : Colors.blue[800],
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

  // ---------- Tables ----------

  Widget _buildBattingTable(TeamScore team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(['Batsman', 'R', 'B', '4s', '6s', 'SR'], flex: const [5, 1, 1, 1, 1, 1]),
        const SizedBox(height: 6),
        if (team.details.players.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No batting data', style: TextStyle(color: Theme.of(context).hintColor)),
          )
        else
          ...team.details.players.map(
                (p) => _playerRow(
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
            ),
          ),
      ],
    );
  }

  Widget _buildBowlingTable(TeamScore team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(['Bowler', 'O', 'R', 'W', 'M', 'Econ'], flex: const [5, 1, 1, 1, 1, 1]),
        const SizedBox(height: 6),
        if (team.details.bowlers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No bowling data', style: TextStyle(color: Theme.of(context).hintColor)),
          )
        else
          ...team.details.bowlers.map(
                (b) => _playerRow(
              name: b.name,
              onTap: () => _navigateToPlayer(b.playerId),
              values: [
                b.overs.toStringAsFixed(1),
                '${b.runs}',
                '${b.wickets}',
                '${b.maiden}',
                b.economy.toStringAsFixed(1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _playerRow({
    required String name,
    String? info,
    required List<String> values,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x151ffffff) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow:
        isDark ? [] : const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          // name + dismissal
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
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
                if (info != null && info.trim().isNotEmpty)
                  Text(
                    info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey),
                  ),
              ],
            ),
          ),
          // metrics (right-aligned)
          for (final v in values)
            Expanded(
              flex: 1,
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()], // aligned digits
                ),
              ),
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

  // ---------- Simple card wrapper (replaces GlassPanel) ----------

  Widget _buildCard({
    required Widget child,
    required bool isDark,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  Widget _buildNoData(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 80, color: isDark ? Colors.grey[600] : Colors.grey),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlayer(int playerId) {
    if (playerId > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerPublicInfoTab(playerId: playerId)),
      );
    }
  }
}
