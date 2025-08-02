import 'package:flutter/material.dart';

class ScoringInputs extends StatelessWidget {
  final int? selectedRuns;
  final String? selectedExtra;
  final bool isWicket;
  final bool isSubmitting;
  final ValueChanged<int> onRunSelected;
  final ValueChanged<String> onExtraSelected;
  final VoidCallback onWicketSelected;
  final VoidCallback onSwapStrike;
  final VoidCallback onUndo;
  final VoidCallback onEndInning;
  final VoidCallback onEndMatch;
  final VoidCallback? onViewMatch; // ✅ New
  final Future<Map<String, dynamic>?> Function()? onChangeWicketKeeper;

  const ScoringInputs({
    super.key,
    required this.selectedRuns,
    required this.selectedExtra,
    required this.isWicket,
    required this.isSubmitting,
    required this.onRunSelected,
    required this.onExtraSelected,
    required this.onWicketSelected,
    required this.onSwapStrike,
    required this.onUndo,
    required this.onEndInning,
    required this.onEndMatch,
    this.onChangeWicketKeeper,
    this.onViewMatch, // ✅ New
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget runChip(int r) {
      final selected = selectedRuns == r;
      return ChoiceChip(
        label: Text('$r'),
        selected: selected,
        onSelected: (_) => onRunSelected(r),
        selectedColor: Colors.orange,
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
    }

    Widget extraChip(String label, String shown) {
      final selected = selectedExtra == label;
      return ChoiceChip(
        label: Text(shown),
        selected: selected,
        onSelected: (_) => onExtraSelected(label),
        selectedColor: Colors.blue,
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text('Select Runs', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0, 1, 2, 3, 4, 5, 6].map(runChip).toList(),
          ),

          const SizedBox(height: 14),
          const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              extraChip('Wide', 'Wd'),
              extraChip('No Ball', 'Nb'),
              extraChip('Leg Bye', 'Leg Bye'),
              extraChip('Bye', 'Bye'),
            ],
          ),

          const SizedBox(height: 16),
          const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _action('Wicket', Icons.warning_amber, Colors.redAccent, onWicketSelected),
              _action('Swap Strike', Icons.swap_horiz, Colors.teal, onSwapStrike),
              _action('Undo', Icons.undo, Colors.orange, onUndo),
            ],
          ),

          const SizedBox(height: 12),

          if (onChangeWicketKeeper != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.switch_account),
              label: const Text("Change Wicketkeeper"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                final selected = await onChangeWicketKeeper!();
                if (selected != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🧤 Wicketkeeper set to ${selected['name']}')),
                  );
                }
              },
            ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('End Inning', Icons.flag, Colors.blueGrey, onEndInning),
              _pill('End Match', Icons.emoji_events, Colors.deepPurple, onEndMatch),
              if (onViewMatch != null)
                _pill('View Match', Icons.visibility, Colors.indigo, onViewMatch!), // ✅ NEW
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(String text, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: isSubmitting ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _pill(String text, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: isSubmitting ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
