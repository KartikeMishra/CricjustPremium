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

  void _updateMatchType(String type) {
    if (_selectedType != type) {
      setState(() => _selectedType = type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.primary;
    final unselectedBg = isDark ? Colors.grey[850] : Colors.grey[300];
    final unselectedText = isDark ? Colors.white70 : Colors.black87;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTabButton("Recent", 'recent', selectedColor, unselectedBg!, unselectedText!),
              const SizedBox(width: 8),
              _buildTabButton("Upcoming", 'upcoming', selectedColor, unselectedBg, unselectedText),
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

  Widget _buildTabButton(String label, String type, Color selectedColor, Color unselectedBg, Color unselectedText) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _updateMatchType(type),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? selectedColor : unselectedBg,
          foregroundColor: isSelected ? Colors.white : unselectedText,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: isSelected ? 1 : 0,
        ),
        child: Text(label),
      ),
    );
  }
}
