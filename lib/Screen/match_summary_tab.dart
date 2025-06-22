import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import '../screen/player_info.dart';

class MatchSummaryTab extends StatefulWidget {
  final Map<String, dynamic> summary;
  final Map<String, dynamic> matchData;

  const MatchSummaryTab({
    super.key,
    required this.summary,
    required this.matchData,
  });

  @override
  State<MatchSummaryTab> createState() => _MatchSummaryTabState();
}

class _MatchSummaryTabState extends State<MatchSummaryTab> with TickerProviderStateMixin {
  final Map<String, GlobalKey<FlipCardState>> _cardKeys = {
    'motm': GlobalKey<FlipCardState>(),
    'sotm': GlobalKey<FlipCardState>(),
    'gmotm': GlobalKey<FlipCardState>(),
    'fmotm': GlobalKey<FlipCardState>(),
  };
  String _flippedKey = '';
  Timer? _flipBackTimer;
  late AnimationController _fadeSlideController;

  @override
  void initState() {
    super.initState();
    _fadeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _fadeSlideController.dispose();
    super.dispose();
  }

  Widget buildTeamColumn(String flagUrl, String name, String score, String overs) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: flagUrl.isNotEmpty ? NetworkImage(flagUrl) : null,
          child: flagUrl.isEmpty
              ? const Icon(Icons.sports_cricket, size: 20, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 6),
        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(score, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        Text('$overs overs', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget buildMatchHeader(String toss) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    final team1 = widget.matchData['team_1'] ?? {};
    final team2 = widget.matchData['team_2'] ?? {};
    final matchResult = widget.matchData['match_result'] ?? '';

    final team1Name = team1['team_name'] ?? 'Team A';
    final team2Name = team2['team_name'] ?? 'Team B';
    final team1Flag = team1['team_logo'] ?? '';
    final team2Flag = team2['team_logo'] ?? '';
    final team1Score = '${team1['total_runs'] ?? 0}/${team1['total_wickets'] ?? 0}';
    final team2Score = '${team2['total_runs'] ?? 0}/${team2['total_wickets'] ?? 0}';
    final team1Overs = '${team1['overs_done'] ?? 0}';
    final team2Overs = '${team2['overs_done'] ?? 0}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: buildTeamColumn(team1Flag, team1Name, team1Score, team1Overs)),
              Column(
                children: const [
                  Icon(Icons.flash_on, size: 20, color: Colors.orange),
                  Text("VS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Expanded(child: buildTeamColumn(team2Flag, team2Name, team2Score, team2Overs)),
            ],
          ),
          const SizedBox(height: 12),
          if (matchResult.isNotEmpty)
            Text("🏆 $matchResult", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green)),
          if (toss.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("🪙 $toss", style: TextStyle(fontSize: 13, color: subTextColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildNoData(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 80),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget buildAwardCard(String title, String? playerName, IconData icon, String key, int index) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final awardData = widget.summary[key];
    String? awardStat;
    String? extraStat;
    Color? statColor;

    final awardUserId = awardData is Map && awardData['user_id'] != null
        ? awardData['user_id'].toString()
        : null;

    int playerId = int.tryParse(awardUserId ?? '') ?? 0;

    final batters = widget.summary['tp_batters'] as List<dynamic>? ?? [];
    final bowlers = widget.summary['tp_bowlers'] as List<dynamic>? ?? [];

    for (var player in batters) {
      if (player['user_id'].toString() == awardUserId) {
        awardStat = "${player['total_runs']} runs in ${player['total_balls']} balls";
        if (player['sr'] != null) extraStat = "SR ${player['sr']}";
        statColor = Colors.green;
        break;
      }
    }

    for (var player in bowlers) {
      if (player['user_id'].toString() == awardUserId && awardStat == null) {
        awardStat = "${player['wickets']} wickets for ${player['runs']} runs";
        statColor = Colors.red;
        break;
      }
    }

    return GestureDetector(
      onTap: () => _toggleFlip(key),
      child: FlipCard(
        key: _cardKeys[key],
        direction: FlipDirection.HORIZONTAL,
        flipOnTouch: false,
        front: Card(
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            height: 100,
            width: MediaQuery.of(context).size.width / 2 - 24,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 32, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                ),
              ],
            ),
          ),
        ),
        back: GestureDetector(
          onTap: playerId > 0
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerPublicInfoTab(playerId: playerId),
              ),
            );
          }
              : null,
          child: Card(
            color: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              height: 100,
              width: MediaQuery.of(context).size.width / 2 - 24,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(playerName ?? 'N/A',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      textAlign: TextAlign.center),
                  if (awardStat != null) ...[
                    const SizedBox(height: 4),
                    Text(awardStat!, style: TextStyle(color: statColor, fontWeight: FontWeight.bold)),
                  ],
                  if (extraStat != null)
                    Text(extraStat!, style: TextStyle(fontSize: 13, color: statColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPlayerCard(Map player, int index) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;

    final name = player['name'] ?? player['Display_Name'] ?? 'N/A';
    final team = player['team_name'] ?? '';
    final imageUrl = player['player_image'] ?? player['image_url'] ?? '';
    final points = player['points']?.toString();
    final playerId = int.tryParse(player['player_id']?.toString() ?? player['user_id']?.toString() ?? '') ?? 0;

    String extra = '';
    if (player.containsKey('sr')) {
      extra = "${player['total_runs']} runs • ${player['total_balls']} balls • SR ${player['sr']}";
    } else if (player.containsKey('ec')) {
      extra = "${player['overs']} ov • ${player['wickets']} wkts • ${player['runs']} runs • Econ ${player['ec']}";
    }

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        onTap: playerId > 0
            ? () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerPublicInfoTab(playerId: playerId)),
        )
            : null,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image.network(
            imageUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              'lib/asset/images/Random_Image.png',
              width: 50,
              height: 50,
            ),
          ),
        ),
        title: Text(name, style: TextStyle(color: textColor)),
        subtitle: Text("$team\n$extra", style: const TextStyle(fontSize: 13)),
        isThreeLine: true,
        trailing: points != null
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text("$points pts",
              style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
        )
            : null,
      ),
    );
  }

  void _toggleFlip(String key) {
    final currentState = _cardKeys[key]?.currentState;
    final isAlreadyFlipped = _flippedKey == key && currentState?.isFront == false;

    if (isAlreadyFlipped) {
      currentState?.toggleCard();
      _flippedKey = '';
      _flipBackTimer?.cancel();
    } else {
      if (_flippedKey.isNotEmpty && _cardKeys[_flippedKey]?.currentState?.isFront == false) {
        _cardKeys[_flippedKey]?.currentState?.toggleCard();
      }
      currentState?.toggleCard();
      _flippedKey = key;
      _flipBackTimer?.cancel();
      _flipBackTimer = Timer(const Duration(seconds: 3), () {
        if (_flippedKey.isNotEmpty) {
          _cardKeys[_flippedKey]?.currentState?.toggleCard();
          _flippedKey = '';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final toss = widget.matchData['match_toss'] ?? '';
    final motm = widget.summary['motm']?['name'];
    final sotm = widget.summary['sotm']?['name'];
    final gmotm = widget.summary['gmotm']?['name'];
    final fmotm = widget.summary['fmotm']?['name'];
    final tpBatters = widget.summary['tp_batters'] as List<dynamic>? ?? [];
    final tpBowlers = widget.summary['tp_bowlers'] as List<dynamic>? ?? [];
    final mvps = (widget.summary['mvp'] ?? {}) as Map<String, dynamic>;

    final List<Widget> awardCards = [];
    int index = 0;
    if (motm != null) awardCards.add(buildAwardCard("Man of the Match", motm, Icons.emoji_events, 'motm', index++));
    if (sotm != null) awardCards.add(buildAwardCard("Striker of the Match", sotm, Icons.flash_on, 'sotm', index++));
    if (gmotm != null) awardCards.add(buildAwardCard("Golden Arm of the Match", gmotm, Icons.track_changes, 'gmotm', index++));
    if (fmotm != null) awardCards.add(buildAwardCard("Fighter of the Match", fmotm, Icons.sports_baseball, 'fmotm', index++));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildMatchHeader(toss),
          const SizedBox(height: 10),
          Text("Match Awards", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          awardCards.isNotEmpty
              ? GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: awardCards,
          )
              : _buildNoData("No awards available."),
          const SizedBox(height: 16),
          Text("Top Batters", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          tpBatters.isNotEmpty
              ? Column(children: tpBatters.asMap().entries.map((e) => buildPlayerCard(e.value, e.key)).toList())
              : _buildNoData("No batter stats available."),
          const SizedBox(height: 16),
          Text("Top Bowlers", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          tpBowlers.isNotEmpty
              ? Column(children: tpBowlers.asMap().entries.map((e) => buildPlayerCard(e.value, e.key)).toList())
              : _buildNoData("No bowler stats available."),
          const SizedBox(height: 16),
          Text("MVP Points", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          mvps.isNotEmpty
              ? Column(
            children: mvps.entries.toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final data = entry.value.value as Map<String, dynamic>;
              return buildPlayerCard(data, idx);
            }).toList(),
          )
              : _buildNoData("No MVP data available."),
        ],
      ),
    );
  }
}
