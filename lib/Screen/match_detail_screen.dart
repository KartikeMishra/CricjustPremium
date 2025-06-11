import 'package:flutter/material.dart';
import '../model/match_model.dart';
import '../service/match_service.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchModel? match;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatchDetails();
  }

  Future<void> _fetchMatchDetails() async {
    try {
      final fetchedMatch = await MatchService.fetchMatchById(widget.matchId);
      setState(() {
        match = fetchedMatch;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching match: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (match == null) return const Scaffold(body: Center(child: Text('Match not found')));

    return Scaffold(
      appBar: AppBar(title: Text(match!.matchName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreCard(match!),
            const SizedBox(height: 20),
            _buildInfoRow("Tournament", match!.tournamentName),
            _buildInfoRow("Venue", match!.venue),
            _buildInfoRow("Toss", match!.toss),
            _buildInfoRow("Ball Type", match!.ballType),
            _buildInfoRow("Overs", "${match!.matchOvers}"),
            _buildInfoRow("Date", match!.matchDate),
            _buildInfoRow("Time", match!.matchTime),
            _buildInfoRow("Result", match!.result.isEmpty ? "Pending" : match!.result,
              valueColor: match!.result.isNotEmpty ? Colors.green : Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(MatchModel match) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: Column(
        children: [
          _buildTeamRow(
            match.team1Logo,
            match.team1Name,
            '${match.team1Runs}/${match.team1Wickets}',
            '${match.team1Overs}.${match.team1Balls} ov',
          ),
          const Divider(),
          _buildTeamRow(
            match.team2Logo,
            match.team2Name,
            '${match.team2Runs}/${match.team2Wickets}',
            '${match.team2Overs}.${match.team2Balls} ov',
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(String logoUrl, String name, String score, String overs) {
    return Row(
      children: [
        CircleAvatar(radius: 20, backgroundImage: NetworkImage(logoUrl)),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(score, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(overs, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color valueColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(color: valueColor))),
        ],
      ),
    );
  }
}
