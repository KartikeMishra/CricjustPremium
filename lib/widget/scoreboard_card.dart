import 'package:flutter/material.dart';
import '../utils/image_utils.dart';

class ScoreboardCard extends StatelessWidget {
  final String leftName;
  final String rightName;
  final String leftScore;  // e.g. "120/4"
  final String rightScore; // e.g. "118/6"
  final String leftOvers;  // e.g. "16.2"
  final String rightOvers; // e.g. "16.0"
  final String leftLogo;
  final String rightLogo;
  final String result;
  final String toss;

  const ScoreboardCard({
    super.key,
    required this.leftName,
    required this.rightName,
    required this.leftScore,
    required this.rightScore,
    required this.leftOvers,
    required this.rightOvers,
    required this.leftLogo,
    required this.rightLogo,
    required this.result,
    required this.toss,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textMain = dark ? Colors.white : Colors.black87;
    final textSub  = dark ? Colors.white70 : Colors.black54;
    final cardBg   = dark ? const Color(0xFF121212) : Colors.white;

    Widget teamTile(String name, String score, String overs, String logo) {
      return Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            child: ClipOval(
              child: safeNetworkImage(
                logo,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                assetFallback: 'lib/asset/images/Random_Image.png',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score,
                  style: TextStyle(
                      color: textMain,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              Text('($overs ov)',
                  style: TextStyle(color: textSub, fontSize: 12)),
            ],
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
        border: Border.all(
          color: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          teamTile(leftName, leftScore, leftOvers, leftLogo),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          teamTile(rightName, rightScore, rightOvers, rightLogo),
          if (toss.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: textSub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(toss, style: TextStyle(color: textSub)),
                ),
              ],
            ),
          ],
          if (result.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                result,
                style: TextStyle(
                  color: textMain,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
