import 'package:flutter/material.dart';

class TVStyleScoreScreen extends StatelessWidget {
  final String teamName;
  final int runs;
  final int wickets;
  final double overs;
  final int extras;
  final String lastBallType; // e.g. 'W', '4', '1WD+2', etc.
  final bool isLive;

  const TVStyleScoreScreen({
    super.key,
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.extras,
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
            height: 260, // Slightly taller to fit extra text
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
                                style: TextStyle(
                                  fontSize: lastBallType.length > 3 ? 16 : 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isExtraBall(lastBallType)) ...[
                              const SizedBox(height: 6),
                              Text(
                                "Extra: $lastBallType",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Score Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child: Column(
                    children: [
                      Text(
                        scoreText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (extras > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Extras: $extras",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
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

  static bool _isExtraBall(String type) {
    final t = type.toUpperCase();
    return t.contains('WD') || t.contains('NB') || t.contains('LB') || t.contains('B');
  }

  static Color _getBallColor(String type) {
    final t = type.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    if (t == 'W') return Colors.red;
    if (t == '4') return Colors.purple;
    if (t == '6') return Colors.green;
    if (t == 'WD' || t.contains('WIDE')) return Colors.orange;
    if (t == 'NB' || t.contains('NO BALL')) return Colors.deepOrange;
    if (t == 'B') return Colors.cyan;
    if (t == 'LB') return Colors.lightBlue;

    return Colors.blueGrey;
  }
}
