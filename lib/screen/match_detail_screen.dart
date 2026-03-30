import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/match_model.dart';
import '../service/match_service.dart';
import '../widget/youtube_box.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchModel? match;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchMatchDetails();
  }

  Future<void> _fetchMatchDetails() async {
    try {
      final fetchedMatch = await MatchService
          .fetchMatchById(widget.matchId)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        match = fetchedMatch;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "Failed to load match";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(match?.matchName ?? "Match Details"),
      ),
      body: _buildBody(),
    );
  }



  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: Text(error!));
    }

    if (match == null) {
      return const Center(child: Text("Match not found"));
    }
    debugPrint(
        "📺 FINAL EMBED URL NULL pASS = https://www.youtube.com/embed/${match!.youtubeVideoId}");
    // 🔥 DEBUG PRINT OUTSIDE WIDGET LIST
    if (match!.youtubeVideoId != null &&
        match!.youtubeVideoId!.isNotEmpty) {
      debugPrint(
          "📺 FINAL EMBED URL = https://www.youtube.com/embed/${match!.youtubeVideoId}");
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScoreCard(match!),

        // ================= YOUTUBE VIDEO =================
        if (match!.youtubeVideoId != null &&
            match!.youtubeVideoId!.isNotEmpty) ...[
          const SizedBox(height: 14),

          const Text(
            "Live Stream 🏏",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          /// 🎥 ADD THIS LINE (MAIN FIX)
          YoutubeBox(
            videoId: match!.youtubeVideoId!,
          ),
        ],

        const SizedBox(height: 20),
        _buildInfoRow("Tournament", match!.tournamentName),
      ],
    );


  }

  // ================= SCORE CARD =================

  Widget _buildScoreCard(MatchModel match) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          _buildTeamRow(
            match.team1Logo,
            match.team1Name,
            '${match.team1Runs}/${match.team1Wickets}',
            '${match.team1Overs}.${match.team1Balls} ov',
          ),
          const Divider(color: Colors.white54),
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

  Widget _buildTeamRow(
      String logoUrl,
      String name,
      String score,
      String overs,
      ) {
    return Row(
      children: [
        _networkLogo(logoUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              overs,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _networkLogo(String url) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: 40,
          height: 40,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.sports_cricket, size: 20),
        ),
      ),
    );
  }

  // ================= INFO ROW =================

  Widget _buildInfoRow(
      String label,
      String value, {
        Color valueColor = Colors.black,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
