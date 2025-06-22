import 'package:flutter/material.dart';
import '../model/match_scorecard_model.dart';
import '../service/match_detail_service.dart';
import '../screen/player_info.dart';

class ScorecardScreen extends StatefulWidget {
  final int matchId;
  const ScorecardScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  _ScorecardScreenState createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  @override
  void initState() {
    super.initState();
    print('📣 Loading Scorecard for matchId: ${widget.matchId}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<MatchScorecardResponse>(
      future: MatchScorecardService.fetchScorecard(widget.matchId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _buildNoData('Error: ${snap.error}');
        }
        final resp = snap.data!;
        if (resp.data.isEmpty || resp.scorecard.isEmpty) {
          return _buildNoData('Scorecard not available');
        }

        final meta = resp.data[0];
        final firstId = meta['first_inning'] as int;
        final secondId = meta['second_inning'] as int;
        final wrapper = resp.scorecard[0];
        final teams = [wrapper.team1, wrapper.team2];
        final firstTeam = teams.firstWhere((t) => t.teamId == firstId, orElse: () => teams[0]);
        final secondTeam = teams.firstWhere((t) => t.teamId == secondId, orElse: () => teams[1]);

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    indicatorPadding: const EdgeInsets.all(2),
                    indicatorColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: firstTeam.teamName),
                      Tab(text: secondTeam.teamName),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildInningContent(firstTeam, secondTeam),
                    _buildInningContent(secondTeam, firstTeam),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInningContent(TeamScore bat, TeamScore bowl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(child: _buildBattingTable(bat)),
          const SizedBox(height: 12),

          if (bat.details.yetToBat.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(
                    'Yet to Bat',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: bat.details.yetToBat.map((pt) {
                      return GestureDetector(
                        onTap: () {
                          if (pt.playerId > 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerPublicInfoTab(playerId: pt.playerId),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            pt.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                ),
              ],
            ),

          const SizedBox(height: 12),

          _buildCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Extras: ${bat.extras}'),
                Text('Total: ${bat.totalRuns}/${bat.totalWickets}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Overs: ${bat.oversDone.toStringAsFixed(1)}'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildCard(child: _buildBowlingTable(bowl)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBattingTable(TeamScore team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(['Batsman', 'R', 'B', '4s', '6s', 'SR'], flex: [4, 1, 1, 1, 1, 1]),
        const SizedBox(height: 6),
        ...team.details.players.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
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
                        onTap: () {
                          if (p.playerId > 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerPublicInfoTab(playerId: p.playerId),
                              ),
                            );
                          }
                        },
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        p.isOut ? p.outBy : 'Not out',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 1, child: Text('${p.runs}')),
                Expanded(flex: 1, child: Text('${p.balls}')),
                Expanded(flex: 1, child: Text('${p.fours}')),
                Expanded(flex: 1, child: Text('${p.sixes}')),
                Expanded(flex: 1, child: Text(p.strikeRate.toStringAsFixed(1))),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBowlingTable(TeamScore team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(['Bowler', 'O', 'R', 'W', 'M', 'Econ'], flex: [4, 1, 1, 1, 1, 1]),
        const SizedBox(height: 6),
        ...team.details.bowlers.map((b) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    onTap: () {
                      if (b.playerId > 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerPublicInfoTab(playerId: b.playerId),
                          ),
                        );
                      }
                    },
                    child: Text(
                      b.name,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Expanded(flex: 1, child: Text(b.overs.toStringAsFixed(1))),
                Expanded(flex: 1, child: Text('${b.runs}')),
                Expanded(flex: 1, child: Text('${b.wickets}')),
                Expanded(flex: 1, child: Text('${b.maiden}')),
                Expanded(flex: 1, child: Text(b.economy.toStringAsFixed(1))),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHeaderRow(List<String> labels, {required List<int> flex}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(labels[i], style: const TextStyle(fontWeight: FontWeight.w600)),
          );
        }),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? Colors.grey[850] : Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            Icon(Icons.info_outline, size: 80, color: isDark ? Colors.white70 : Colors.grey),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
