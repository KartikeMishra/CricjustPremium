import 'package:flutter/material.dart';

class BatsmanColumn extends StatelessWidget {
  final String label;
  final String? name;
  final int runs;
  final bool isStriker;

  const BatsmanColumn({
    super.key,
    required this.label,
    required this.name,
    required this.runs,
    required this.isStriker,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: isStriker
          ? BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
      )
          : null,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isStriker)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.sports_cricket, color: Colors.teal, size: 16),
                ),
              Flexible(
                child: Text(
                  name ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$runs Runs',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
