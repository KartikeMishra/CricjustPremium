import 'package:flutter/material.dart';

class MatchInfoTab extends StatelessWidget {
  final Map<String, dynamic> matchData;

  const MatchInfoTab({super.key, required this.matchData});

  @override
  Widget build(BuildContext context) {
    final team1 = matchData['team_1'];
    final team2 = matchData['team_2'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionTitle("Match Info"),
          _infoCard(Icons.sports_cricket, "Match Name", matchData['match_name']),
          _infoCard(Icons.emoji_events, "Tournament", matchData['tournament_name']),
          _infoCard(Icons.calendar_month, "Date", matchData['match_date']),
          _infoCard(Icons.access_time, "Time", matchData['match_time']),
          _infoCard(Icons.location_on, "Venue", matchData['venue']),
          _infoCard(Icons.sports_baseball, "Ball Type", matchData['ball_type']),
          _infoCard(Icons.timelapse, "Overs", "${matchData['match_overs']}"),

          const SizedBox(height: 24),
          _sectionTitle("Teams"),
          _teamCard(team1, team2),

          const SizedBox(height: 24),
          _sectionTitle("Result"),
          _infoCard(Icons.casino, "Toss Result", matchData['match_toss']),
          _infoCard(Icons.check_circle_outline, "Match Result", matchData['match_result']),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String? value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          value?.isNotEmpty == true ? value! : "-",
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _teamCard(Map<String, dynamic> team1, Map<String, dynamic> team2) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTeamInfo(team1),
            const Text("VS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            _buildTeamInfo(team2),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInfo(Map<String, dynamic> team) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Image.network(
            team['team_logo'] ?? '',
            width: 50,
            height: 50,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            team['team_name'] ?? '',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
