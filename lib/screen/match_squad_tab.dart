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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        final maxLength = team1Players.length > team2Players.length
            ? team1Players.length
            : team2Players.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTeamNamesRow(
                squad.team1Name,
                squad.team1Logo,
                squad.team2Name,
                squad.team2Logo,
                isDark,
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: maxLength,
                itemBuilder: (context, index) {
                  final left = index < team1Players.length
                      ? team1Players[index]
                      : null;
                  final right = index < team2Players.length
                      ? team2Players[index]
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: left != null
                              ? _buildPlayerTile(left)
                              : const SizedBox(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: right != null
                              ? _buildPlayerTile(right)
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoData(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamNamesRow(
    String? team1Name,
    String? team1Logo,
    String? team2Name,
    String? team2Logo,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTeamInfo(team1Name ?? "Team 1", team1Logo)),
          const SizedBox(width: 8),
          Expanded(child: _buildTeamInfo(team2Name ?? "Team 2", team2Logo)),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(String teamName, String? logoUrl) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
              ? NetworkImage(logoUrl)
              : const AssetImage('lib/asset/images/cricjust_logo.png')
                    as ImageProvider,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            teamName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerTile(Player player) {
    final image = player.playerImage.isNotEmpty
        ? NetworkImage(player.playerImage)
        : null;

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            image != null
                ? CircleAvatar(radius: 20, backgroundImage: image)
                : CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade300,
                    child: Text(
                      player.name.isNotEmpty ? player.name[0] : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildRoleChip(player.playerType),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final roleText = role.isNotEmpty ? role : 'Player';
    final lower = roleText.toLowerCase();

    final color = lower.contains('bowler')
        ? Colors.blue
        : lower.contains('batter')
        ? Colors.purple
        : lower.contains('wicket')
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        roleText,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
