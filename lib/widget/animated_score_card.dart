import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedScoreCard extends StatelessWidget {
  final String matchType;
  final String teamName;
  final bool isSecondInnings;
  final int runs;
  final int wickets;
  final int overs;
  final int balls;

  // New for target logic
  final int? targetScore;
  final int totalOvers;

  const AnimatedScoreCard({
    super.key,
    required this.matchType,
    required this.teamName,
    required this.isSecondInnings,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.balls,
    required this.totalOvers,
    this.targetScore, // Only required in 2nd innings
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateFormat('d MMM').format(DateTime.now());
    final totalBalls = totalOvers * 6;
    final ballsDone = overs * 6 + balls;
    final ballsLeft = totalBalls - ballsDone;

    final runsNeeded = ((targetScore ?? 0) + 1) - runs;
    final requiredRR = ballsLeft > 0 ? (runsNeeded * 6) / ballsLeft : 0;

    String? matchStatus;
    Color? statusColor;
    final hasCompletedInnings = wickets >= 10 || ballsLeft <= 0 || runsNeeded <= 0;

    if (targetScore != null && isSecondInnings && hasCompletedInnings) {
      if (runs >= (targetScore! + 1)) {
        matchStatus = "🎉 Match Won!";
        statusColor = Colors.green;
      } else if (runs == targetScore) {
        matchStatus = "🤝 Match Tied";
        statusColor = Colors.orange;
      } else {
        matchStatus = "🏁 Match Lost";
        statusColor = Colors.red;
      }
    }

    final isCloseMatch = isSecondInnings && runsNeeded <= 10 && ballsLeft <= 6;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isCloseMatch
            ? Colors.orange.shade100.withValues(alpha: 0.9)
            : (isDark ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // LEFT: match info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      matchType,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      teamName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSecondInnings
                            ? (isDark ? Colors.deepPurple.withValues(alpha: .15) : Colors.deepPurple.shade50)
                            : (isDark ? Colors.green.withValues(alpha: .15) : Colors.green.shade50),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSecondInnings
                              ? (isDark ? Colors.deepPurple : Colors.deepPurple.shade100)
                              : (isDark ? Colors.green : Colors.green.shade100),
                        ),
                      ),
                      child: Text(
                        isSecondInnings ? '2nd Innings' : '1st Innings',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSecondInnings
                              ? (isDark ? Colors.deepPurple[200] : Colors.deepPurple)
                              : (isDark ? Colors.green[200] : Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT: score + overs
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: runs),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) => Text(
                      '$value - $wickets',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timelapse, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Overs: $overs.$balls',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // 🔥 Show target and required RR
          if (targetScore != null && isSecondInnings)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎯 Target: ${targetScore! + 1} runs'),
                  Text('💥 Runs Needed: $runsNeeded in $ballsLeft balls'),
                  if (runsNeeded > 0 && ballsLeft > 0)
                    Text('📈 Required RR: ${requiredRR.toStringAsFixed(2)}'),
                  if (matchStatus != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor ?? Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        matchStatus,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
