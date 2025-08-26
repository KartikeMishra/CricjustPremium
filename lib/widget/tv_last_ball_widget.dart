import 'package:flutter/material.dart';

class TVLastBallWidget extends StatelessWidget {
  final List<Map<String, dynamic>> lastSixBalls;

  const TVLastBallWidget({super.key, required this.lastSixBalls});

  String _getBallOutcome(Map<String, dynamic> ball) {
    if (ball['is_wicket'] == 1) return 'W';

    final isExtra  = ball['is_extra'] == 1;
    final runs     = int.tryParse('${ball['runs']}')       ?? 0;
    final extraRun = int.tryParse('${ball['extra_run'] ?? 0}') ?? 0;
    final typeRaw  = (ball['extra_run_type'] ?? '').toString().toUpperCase().trim();

    if (isExtra) {
      // normalize extras to short codes
      String code;
      switch (typeRaw) {
        case 'WD': case 'WIDE':     code = 'WD'; break;
        case 'NB': case 'NO BALL':  code = 'NB'; break;
        case 'B':  case 'BYE':      code = 'B';  break;
        case 'LB': case 'LEG BYE':  code = 'LB'; break;
        default:                     code = typeRaw;
      }
      return '${extraRun > 0 ? extraRun : ''}$code';
    }

    // normal runs
    if (runs == 0) return '•';
    return runs.toString();
  }

  Color _getBallColor(String outcome) {
    final code = outcome.replaceAll(RegExp(r'\d'), ''); // strip digits
    switch (code) {
      case 'W':  return Colors.redAccent;
      case '4':  return Colors.green;
      case '6':  return Colors.blue;
      case 'WD': return Colors.orange;
      case 'NB': return Colors.deepOrange;
      case 'B':  return Colors.cyan;
      case 'LB': return Colors.lightBlue;
      default:   return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry   = lastSixBalls.isNotEmpty ? lastSixBalls.first : null;
    final outcome = entry != null ? _getBallOutcome(entry) : '•';
    final color   = _getBallColor(outcome);

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
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
