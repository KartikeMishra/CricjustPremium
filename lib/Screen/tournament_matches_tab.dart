import 'package:flutter/material.dart';
import '../theme/color.dart';
import '../screen/tournament_matches_section.dart';

class TournamentMatchesTab extends StatefulWidget {
  final int tournamentId;

  const TournamentMatchesTab({super.key, required this.tournamentId});

  @override
  State<TournamentMatchesTab> createState() => _TournamentMatchesTabState();
}

class _TournamentMatchesTabState extends State<TournamentMatchesTab> {
  String _selectedType = 'recent';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == 'recent' ? AppColors.primary : Colors.grey[300],
                    foregroundColor: _selectedType == 'recent' ? Colors.white : Colors.black,
                  ),
                  onPressed: () => setState(() => _selectedType = 'recent'),
                  child: const Text('Recent'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == 'upcoming' ? AppColors.primary : Colors.grey[300],
                    foregroundColor: _selectedType == 'upcoming' ? Colors.white : Colors.black,
                  ),
                  onPressed: () => setState(() => _selectedType = 'upcoming'),
                  child: const Text('Upcoming'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TournamentMatchesSection(
            tournamentId: widget.tournamentId,
            type: _selectedType,
          ),
        ),
      ],
    );
  }
}
