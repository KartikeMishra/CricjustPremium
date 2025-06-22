import 'package:flutter/material.dart';
import 'package:cricjust_premium/Screen/player_info.dart';
import '../model/match_squad_model.dart';
import '../service/match_detail_service.dart';

class MatchSquadTab extends StatefulWidget {
  final int matchId;

  const MatchSquadTab({super.key, required this.matchId});

  @override
  State<MatchSquadTab> createState() => _MatchSquadTabState();
}

class _MatchSquadTabState extends State<MatchSquadTab> {
  late Future<MatchSquad> _squadFuture;

  @override
  void initState() {
    super.initState();
    _squadFuture = MatchSquadService.fetchSquad(widget.matchId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchSquad>(
      future: _squadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError || !snapshot.hasData) {
          return _buildNoData('Squad not available for this match.');
        }

        final squad = snapshot.data!;
        final team1Players = squad.team1Players;
        final team2Players = squad.team2Players;

        if (team1Players.isEmpty && team2Players.isEmpty) {
          return _buildNoData("Squad not available for both teams.");
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildTeamHeader(squad.team1Name, squad.team1Logo)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTeamHeader(squad.team2Name, squad.team2Logo)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPlayerGrid(team1Players)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPlayerGrid(team2Players)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoData(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamHeader(String teamName, String logoUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(logoUrl),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teamName.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerGrid(List<Player> players) {
    return SingleChildScrollView(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: players.map((player) => _buildPlayerCard(player)).toList(),
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerPublicInfoTab(playerId: player.playerId),
          ),
        );
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(player.playerImage),
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(height: 6),
            Text(
              player.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            _buildRoleChip(player.playerType),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final color = role.toLowerCase().contains('bowler')
        ? Colors.blue
        : role.toLowerCase().contains('batter')
        ? Colors.purple
        : role.toLowerCase().contains('wicket')
        ? Colors.orange
        : Colors.green;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
