import 'package:cricjust_premium/widget/tv_score_banner.dart';
import 'package:flutter/material.dart';
import '../screen/match_scoring_screen.dart';
import '../service/match_score_service.dart';

class MatchWithTVBanner extends StatefulWidget {
  final int matchId;
  final String token;

  const MatchWithTVBanner({
    Key? key,
    required this.matchId,
    required this.token,
  }) : super(key: key);

  @override
  State<MatchWithTVBanner> createState() => _MatchWithTVBannerState();
}

class _MatchWithTVBannerState extends State<MatchWithTVBanner> {
  int runs = 0;
  int wickets = 0;
  double overs = 0.0;
  String lastBall = "•";
  int extras = 0;
  void _refreshTVBanner() async {
    final scoreData = await MatchScoreService.getCurrentScore(
      widget.matchId,
      widget.token,
    );
    if (scoreData == null) return;

    print("📥 [TV] full current_score: $scoreData");
    print("🗝 current_score keys: ${scoreData.keys.toList()}");

    final currentInning = scoreData['current_inning'] as Map<String, dynamic>?;
    print("🔑 current_inning keys: ${currentInning?.keys.toList()}");

    final lastList = currentInning?['last_ball_data'] as List<dynamic>?;
    print("🟡 last_ball_data: $lastList");

    final lastBallInfo = (lastList?.isNotEmpty == true) ? lastList![0] : null;
    print("🟢 using lastBallInfo: $lastBallInfo");

    String lbType = '•';
    if (lastBallInfo != null) {
      // … your existing logic to pick W, extras, runs …
    }

    setState(() {
      runs    = scoreData['runs'] ?? runs;
      wickets = scoreData['wickets'] ?? wickets;
      overs   = double.tryParse(scoreData['overs']?.toString() ?? '') ?? overs;
      extras  = scoreData['extras'] ?? extras;
      lastBall = lbType;
    });

    print("✅ TV Banner → lastBall=$lastBall");
  }


  @override
  void initState() {
    super.initState();
    _refreshTVBanner();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            TVStyleScoreScreen(
              teamName: "Live Match",
              runs: runs,
              wickets: wickets,
              overs: overs,
              extras: extras,
              lastBallType: lastBall,
              isLive: true,
            ),
            Expanded(
              child: AddScoreScreen(
                matchId: widget.matchId,
                token: widget.token,
                onScoreSubmitted: _refreshTVBanner,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
