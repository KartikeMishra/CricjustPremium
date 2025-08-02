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

  void _refreshTVBanner() async {
    final scoreData = await MatchScoreService.getCurrentScore(widget.matchId, widget.token);
    if (scoreData != null) {
      final lastBallInfo = scoreData['last_ball_data']?[0];

      String lbType = "•";
      if (lastBallInfo != null) {
        final isWicket = lastBallInfo['is_wicket'] == 1;
        final isExtra = lastBallInfo['is_extra'] == 1;
        final extraType = (lastBallInfo['extra_run_type'] ?? "").toString().toLowerCase();
        final runsScored = int.tryParse(lastBallInfo['runs'].toString()) ?? 0;
        final extraRun = int.tryParse(lastBallInfo['extra_run']?.toString() ?? '0') ?? 0;

        if (isWicket) {
          lbType = "W";
        } else if (isExtra) {
          if (extraType.contains("wide")) lbType = "${extraRun > 0 ? extraRun : ''}Wd";
          else if (extraType.contains("no")) lbType = "${extraRun > 0 ? extraRun : ''}Nb";
          else if (extraType.contains("leg")) lbType = "${extraRun > 0 ? extraRun : ''}Lb";
          else if (extraType.contains("bye")) lbType = "${extraRun > 0 ? extraRun : ''}B";
          else lbType = "•";
        } else {
          lbType = runsScored.toString();
        }
      }

      setState(() {
        runs = scoreData['runs'];
        wickets = scoreData['wickets'];
        overs = scoreData['overs'];
        lastBall = lbType;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshTVBanner(); // Initial load
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
