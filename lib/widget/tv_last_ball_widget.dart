import 'package:flutter/material.dart';

class TVLastBallWidget extends StatelessWidget {
  final List<Map<String, dynamic>> lastSixBalls;

  const TVLastBallWidget({super.key, required this.lastSixBalls});

  String _getBallOutcome(Map<String, dynamic> ball) {
    if (ball['is_wicket'] == 1) return 'W';
    if (ball['is_extra'] == 1) {
      // You can expand this for Wide / No Ball / Bye etc. if needed
      return ball['runs']?.toString() ?? 'E';
    }
    final runs = ball['runs'];
    if (runs == null) return '•';
    if (runs == 0) return '•';
    return runs.toString();
  }

  Color _getBallColor(String outcome) {
    switch (outcome) {
      case 'W':
        return Colors.red;
      case '4':
        return Colors.green;
      case '6':
        return Colors.blue;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ball = lastSixBalls.isNotEmpty ? lastSixBalls.first : null;
    final outcome = ball != null ? _getBallOutcome(ball) : '•';
    final color = _getBallColor(outcome);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Last Ball',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            backgroundColor: color,
            radius: 18,
            child: Text(
              outcome,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
