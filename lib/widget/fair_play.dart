// lib/widget/fair_play.dart

import 'package:flutter/material.dart';
import '../model/fair_play_model.dart';
import '../theme/color.dart';

class FairPlayTableWidget extends StatelessWidget {
  final List<FairPlayStanding> fairPlayTeams;
  const FairPlayTableWidget({Key? key, required this.fairPlayTeams}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // blue header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Text(
                'Fair-Play Standings',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // table header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: const [
                  Expanded(flex: 4, child: Text('Team', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('FP', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('M', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const Divider(height: 1),

            // rows
            ...fairPlayTeams.map((f) {
              final idx = fairPlayTeams.indexOf(f);
              return Container(
                color: idx.isEven ? Colors.white : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          ClipOval(
                            child: f.teamLogo.isNotEmpty
                                ? Image.network(f.teamLogo, width: 32, height: 32, fit: BoxFit.cover,
                                errorBuilder: (_,__,___) => const Icon(Icons.shield, size: 32))
                                : const Icon(Icons.shield, size: 32),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f.teamName, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Expanded(child: Text(f.fairPlayPoints.toStringAsFixed(1), textAlign: TextAlign.center)),
                    Expanded(child: Text('${f.totalMatches}', textAlign: TextAlign.center)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
