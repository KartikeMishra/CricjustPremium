// lib/widget/team_matches_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/tournament_overview_model.dart';
import '../theme/color.dart';

class TeamMatchesScreen extends StatelessWidget {
  final TeamStanding team;
  const TeamMatchesScreen({Key? key, required this.team}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            ClipOval(
              child: team.teamLogo.isNotEmpty
                  ? Image.network(
                team.teamLogo,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.person, size: 40, color: Colors.white),
              )
                  : const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${team.teamName} Matches',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 2,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: team.matches.length,
        itemBuilder: (context, i) {
          final m = team.matches[i];
          final won = m.matchResult.toLowerCase().contains('won');
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              title: Text(
                m.opponent,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                DateFormat('dd MMM yyyy').format(
                    DateTime.tryParse(m.matchDate) ?? DateTime.now()),
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: won
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  m.matchResult,
                  style: TextStyle(
                    color: won ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
