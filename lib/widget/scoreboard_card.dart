// lib/widget/scoreboard_card.dart
import 'package:flutter/material.dart';
import 'package:cricjust_premium/screen/ui_graphics.dart';

class ScoreboardCard extends StatelessWidget {
  final String leftName, rightName;
  final String leftScore, rightScore;
  final String leftOvers, rightOvers;
  final String leftLogo, rightLogo;
  final String? result;
  final String? toss;

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
    this.result,
    this.toss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

// drop-in replacement for your chip() helper
    Widget chip(String label, {IconData? icon}) {
      return LayoutBuilder(
        builder: (context, c) {
          return ConstrainedBox(
            // never exceed the space Wrap gives this child
            constraints: BoxConstraints(maxWidth: c.maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(
                    Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,          // take full allowed width
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Flexible(                              // let text shrink/ellipsis
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }


    Widget team(String logo, String name, String score, String ov) {
      final text = isDark ? Colors.white : Colors.black87;
      final sub = isDark ? Colors.white70 : Colors.black54;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withOpacity(0.15),
            backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
            child: logo.isEmpty
                ? Icon(Icons.sports_cricket, color: Colors.white.withOpacity(0.85))
                : null,
          ),
          const SizedBox(height: 8),
          // Fill available width in its table cell
          SizedBox(
            width: double.infinity,
            child: Text(
              name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text('$ov ov', style: TextStyle(color: sub, fontSize: 12, height: 1.0)),
        ],
      );
    }

    Widget vsBadge() => Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDark ? 0.10 : 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: const Text(
        'VS',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      lightGradient: const LinearGradient(
        colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkColor: const Color(0xFF1E1E1E),
      child: Stack(
        children: [
          const Positioned.fill(child: CardAuroraOverlay()),
          const Positioned(
            right: -4,
            bottom: -2,
            child: WatermarkIcon(icon: Icons.sports_cricket, size: 110, opacity: 0.08),
          ),
          Column(
            children: [
              // ✅ Overflow-proof: Table with fixed center and flexible sides
              Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FixedColumnWidth(40), // 36 badge + small breathing space
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: team(leftLogo, leftName, leftScore, leftOvers),
                      ),
                      Center(child: vsBadge()),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: team(rightLogo, rightName, rightScore, rightOvers),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if ((result ?? '').isNotEmpty)
                    chip(result!, icon: Icons.emoji_events_rounded),
                  if ((toss ?? '').isNotEmpty)
                    chip(toss!, icon: Icons.casino_rounded),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
