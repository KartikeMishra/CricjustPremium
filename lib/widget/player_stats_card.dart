import 'package:flutter/material.dart';

class PlayerStatsCard extends StatelessWidget {
  final String? onStrikeName;
  final int onStrikeRuns;

  final String? nonStrikeName;
  final int nonStrikeRuns;

  final String? bowlerName;
  final String? bowlerOvers;
  final int maidens;
  final int runsConceded;
  final int wickets;
  final double economy;

  final int extras;
  final double runRate;

  final VoidCallback? onEditBatsman;
  final VoidCallback? onEditNonBatsman;
  final VoidCallback? onEditBowler;

  final bool compact;

  const PlayerStatsCard({
    super.key,
    required this.onStrikeName,
    required this.onStrikeRuns,
    required this.nonStrikeName,
    required this.nonStrikeRuns,
    required this.bowlerName,
    required this.bowlerOvers,
    required this.maidens,
    required this.runsConceded,
    required this.wickets,
    required this.economy,
    required this.extras,
    required this.runRate,
    this.onEditBatsman,
    this.onEditNonBatsman,
    this.onEditBowler,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hPad = compact ? 12.0 : 16.0;
    final vPad = compact ? 10.0 : 12.0;
    final labelSize = compact ? 11.0 : 12.0;
    final nameSize = compact ? 13.0 : 14.0;
    final runSize = compact ? 12.0 : 13.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _batsmanBox(
                context,
                label: 'Striker',
                name: onStrikeName ?? '—',
                runs: onStrikeRuns,
                icon: Icons.sports_cricket,
                onTap: onEditBatsman,
                labelSize: labelSize,
                nameSize: nameSize,
                runSize: runSize,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _batsmanBox(
                context,
                label: 'Non-Striker',
                name: nonStrikeName ?? '—',
                runs: nonStrikeRuns,
                icon: Icons.sports_cricket_outlined,
                onTap: onEditNonBatsman,
                labelSize: labelSize,
                nameSize: nameSize,
                runSize: runSize,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bowlerBox(
            context,
            name: bowlerName ?? '—',
            overs: bowlerOvers ?? '0.0',
            maidens: maidens,
            runs: runsConceded,
            wickets: wickets,
            econ: economy,
            onTap: onEditBowler,
            isDark: isDark,
            labelSize: labelSize,
            nameSize: nameSize,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoStat('Extras', extras.toString(), Icons.add, isDark)),
              Expanded(child: _infoStat('Run Rate', runRate.toStringAsFixed(2), Icons.speed, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _batsmanBox(
      BuildContext context, {
        required String label,
        required String name,
        required int runs,
        required IconData icon,
        required VoidCallback? onTap,
        required double labelSize,
        required double nameSize,
        required double runSize,
        required bool isDark,
      }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: labelSize,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  )),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.teal),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('$runs Runs',
                  style: TextStyle(
                    fontSize: runSize,
                    color: isDark ? Colors.greenAccent : Colors.green[800],
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bowlerBox(
      BuildContext context, {
        required String name,
        required String overs,
        required int maidens,
        required int runs,
        required int wickets,
        required double econ,
        required VoidCallback? onTap,
        required bool isDark,
        required double labelSize,
        required double nameSize,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.sports_baseball, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '$overs ov, $maidens M, $runs R, $wickets W, Econs: ${econ.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: labelSize,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoStat(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.teal),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
