import 'package:flutter/material.dart';

class TVStyleScoreScreen extends StatelessWidget {
  final String teamName;
  final int runs;
  final int wickets;
  final double overs;
  final String lastBallType; // 'W', '4', '6', 'Wd', 'Nb', etc.
  final bool isLive;

  const TVStyleScoreScreen({
    super.key,
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.overs,
    this.lastBallType = "•",
    this.isLive = true,
  });

  @override
  Widget build(BuildContext context) {
    final scoreText = "$teamName  $runs-$wickets  ${overs.toStringAsFixed(1)}";

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TV-style Banner
          Container(
            width: 360,
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade900, Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.blueAccent.shade200, width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Half
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                      ),
                      if (isLive)
                        Positioned(
                          top: 10,
                          right: 16,
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 10, color: Colors.redAccent),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Last Ball',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: _getBallColor(lastBallType),
                              child: Text(
                                lastBallType,
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Score Bar
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade400,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    scoreText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TV Stand
          Container(
            width: 80,
            height: 10,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  static Color _getBallColor(String type) {
    final t = type.trim().toUpperCase();

    if (t == 'W') return Colors.red;
    if (t == '4') return Colors.purple;
    if (t == '6') return Colors.green;

    // ✅ Handle extras (Wide, No Ball, Leg Bye, Bye)
    if (t == 'WD' || t.contains('WIDE')) return Colors.orange;
    if (t == 'NB' || t.contains('NO BALL')) return Colors.deepOrange;
    if (t == 'B' || t.contains('BYE')) return Colors.cyan;
    if (t == 'LB' || t.contains('LEG BYE')) return Colors.lightBlue;

    return Colors.blueGrey;
  }

}
