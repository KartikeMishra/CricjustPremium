// lib/widget/fair_play.dart

import 'package:flutter/material.dart';
import '../model/fair_play_model.dart';
import '../theme/color.dart';

class FairPlayTableWidget extends StatelessWidget {
  final List<FairPlayStanding> fairPlayTeams;
  const FairPlayTableWidget({super.key, required this.fairPlayTeams});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: isDark ? Colors.grey[900] : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // blue header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Text(
                'Fair-Play Standings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // table header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Team',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'FP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'M',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.grey[700] : null),

            // rows
            ...fairPlayTeams.map((f) {
              final idx = fairPlayTeams.indexOf(f);
              return Container(
                color: idx.isEven
                    ? (isDark ? Colors.grey[900] : Colors.white)
                    : (isDark ? Colors.grey[850] : Colors.grey.shade50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          ClipOval(
                            child: f.teamLogo.isNotEmpty
                                ? Image.network(
                                    f.teamLogo,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.shield, size: 32),
                                  )
                                : const Icon(Icons.shield, size: 32),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.teamName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        f.fairPlayPoints.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${f.totalMatches}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
