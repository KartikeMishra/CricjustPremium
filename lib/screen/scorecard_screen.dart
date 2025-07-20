import 'package:flutter/material.dart';
import '../model/match_scorecard_model.dart';
import '../service/match_detail_service.dart';
import '../screen/player_info.dart';

class ScorecardScreen extends StatefulWidget {
  final int matchId;
  const ScorecardScreen({super.key, required this.matchId});

  @override
  _ScorecardScreenState createState() => _ScorecardScreenState();
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
    setState(() {
      _loadScorecard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F9FC),
      body: FutureBuilder<MatchScorecardResponse>(
        future: _scorecardFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _buildNoData('Error: ${snap.error}');
          }

          final resp = snap.data!;
          final meta = resp.data[0];
          final firstId = meta['first_inning'] as int;
          final secondId = meta['second_inning'] as int;

          final wrapper = resp.scorecard[0];
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
                  firstTeam.teamName,
                  secondTeam.teamName,
                  isDark,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      RefreshIndicator(
                        onRefresh: _refreshScorecard,
                        child: _buildInningContent(
                          firstTeam,
                          secondTeam,
                          isDark,
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _refreshScorecard,
                        child: _buildInningContent(
                          secondTeam,
                          firstTeam,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabSelector(String teamA, String teamB, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: isDark ? Colors.white24 : const Color(0xFF1976D2),
          borderRadius: BorderRadius.circular(30),
        ),
        labelColor: isDark ? Colors.white : Colors.white,
        unselectedLabelColor: isDark
            ? Colors.grey[300]
            : const Color(0xFF1976D2),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(child: _buildTabLabel(Icons.sports_cricket, teamA)),
          Tab(child: _buildTabLabel(Icons.sports_cricket_outlined, teamB)),
        ],
      ),
    );
  }

  Widget _buildTabLabel(IconData icon, String text) {
    return FittedBox(
      child: Row(
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
      ),
    );
  }

  Widget _buildInningContent(TeamScore bat, TeamScore bowl, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(child: _buildBattingTable(bat), isDark: isDark),
          const SizedBox(height: 12),
          if (bat.details.yetToBat.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Text(
                'Yet to Bat',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            _buildCard(
              isDark: isDark,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bat.details.yetToBat.map((pt) {
                  return GestureDetector(
                    onTap: () => _navigateToPlayer(pt.playerId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pt.name.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.blue,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildCard(
            isDark: isDark,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('Extras: ${bat.extras}')),
                Chip(label: Text('Overs: ${bat.oversDone.toStringAsFixed(1)}')),
                Chip(
                  backgroundColor: isDark
                      ? Colors.blueGrey
                      : Colors.blue.shade50,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total: ${bat.totalRuns}/${bat.totalWickets}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(child: _buildBowlingTable(bowl), isDark: isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBattingTable(TeamScore team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(
          ['Batsman', 'R', 'B', '4s', '6s', 'SR'],
          flex: [4, 1, 1, 1, 1, 1],
        ),
        const SizedBox(height: 6),
        ...team.details.players.map(
          (p) => _buildPlayerRow(
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
        _buildHeaderRow(
          ['Bowler', 'O', 'R', 'W', 'M', 'Econ'],
          flex: [4, 1, 1, 1, 1, 1],
        ),
        const SizedBox(height: 6),
        ...team.details.bowlers.map(
          (b) => _buildPlayerRow(
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

  Widget _buildPlayerRow({
    required String name,
    String? info,
    required List<String> values,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.lightBlue[200] : Colors.blue,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (info != null)
                  Text(
                    info,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < values.length; i++)
            Expanded(flex: 1, child: Text(values[i])),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<String> labels, {required List<int> flex}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(
              labels[i],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? Colors.white12 : Colors.white,
      elevation: isDark ? 1 : 3,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildNoData(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
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
        MaterialPageRoute(
          builder: (_) => PlayerPublicInfoTab(playerId: playerId),
        ),
      );
    }
  }
}
