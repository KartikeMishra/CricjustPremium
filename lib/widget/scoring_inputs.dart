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
  final VoidCallback? onViewMatch;
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
    this.onViewMatch,
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

    Widget customRunChip(BuildContext context) {
      return ChoiceChip(
        label: const Text('+'),
        selected: false,
        onSelected: (_) async {
          final controller = TextEditingController();
          final result = await showDialog<int>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Enter Custom Runs"),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Enter runs'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                TextButton(
                  onPressed: () {
                    final val = int.tryParse(controller.text.trim());
                    if (val != null) Navigator.pop(ctx, val);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          if (result != null) onRunSelected(result);
        },
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      );
    }
    Color _extraColor(String type, bool selected, bool isDark) {
      // pick base color by extra type
      final base = () {
        switch (type) {
          case 'Wide':    return Colors.green;
          case 'No Ball': return Colors.orange;
          case 'Leg Bye': return Colors.blueGrey;
          case 'Bye':     return Colors.purple;
          default:        return Colors.grey;
        }
      }();

      // lighten when not selected, or dark theme
      return selected
          ? base
          : (isDark ? base.withOpacity(0.4) : base.withOpacity(0.2));
    }

    Widget extraChip(String value, String shown) {
      final selected = selectedExtra == value;
      final color = _extraColor(value, selected, isDark);

      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(shown.toUpperCase()),
            if (selected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check, size: 14, color: Colors.white),
            ]
          ],
        ),
        selected: selected,
        onSelected: (_) => onExtraSelected(value),
        backgroundColor: color,
        selectedColor: color,
        labelStyle: TextStyle(
          color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...[0, 1, 2, 3, 4, 5, 6].map((r) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: runChip(r),
                )),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: customRunChip(context),
                ),
              ],
            ),
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
              _glassyButton(
                label: 'Wicket',
                icon: Icons.warning_amber,
                color: Colors.redAccent,
                onPressed: isSubmitting ? null : onWicketSelected,
              ),
              _glassyButton(
                label: 'Swap Strike',
                icon: Icons.swap_horiz,
                color: Colors.teal,
                onPressed: isSubmitting ? null : onSwapStrike,
              ),
              _glassyButton(
                label: 'Undo',
                icon: Icons.undo,
                color: Colors.orange,
                onPressed: isSubmitting ? null : onUndo,
              ),
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
              _glassyButton(
                label: 'End Inning',
                icon: Icons.flag,
                color: Colors.blueGrey,
                onPressed: isSubmitting ? null : onEndInning,
              ),
              _glassyButton(
                label: 'End Match',
                icon: Icons.emoji_events,
                color: Colors.deepPurple,
                onPressed: isSubmitting ? null : onEndMatch,
              ),
              if (onViewMatch != null)
                _glassyButton(
                  label: 'View Match',
                  icon: Icons.visibility,
                  color: Colors.indigo,
                  onPressed: isSubmitting ? null : onViewMatch!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassyButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final isEnabled = onPressed != null;

    return ElevatedButton.icon(
      icon: isLoading
          ? SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      )
          : Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? color.withOpacity(0.15) : Colors.grey.shade200,
        foregroundColor: isEnabled ? color : Colors.grey,
        elevation: isEnabled ? 2 : 0,
        shadowColor: isEnabled ? color.withOpacity(0.25) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: BorderSide(
          color: isEnabled ? color.withOpacity(0.3) : Colors.grey.shade300,
          width: 1.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
