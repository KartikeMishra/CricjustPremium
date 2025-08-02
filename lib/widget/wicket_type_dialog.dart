// wicket_type_dialog.dart

import 'package:flutter/material.dart';

class WicketTypeDialog {
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    final types = [
      {'label': 'Bowled', 'icon': Icons.sports_cricket, 'allowRuns': false},
      {'label': 'Caught', 'icon': Icons.sports_handball, 'allowRuns': false},
      {'label': 'Caught Behind', 'icon': Icons.record_voice_over, 'allowRuns': false},
      {'label': 'LBW', 'icon': Icons.highlight_off, 'allowRuns': false},
      {'label': 'Stumped', 'icon': Icons.block, 'allowRuns': false},
      {'label': 'Run Out', 'icon': Icons.directions_run, 'allowRuns': true},
      {'label': 'Run Out (Mankaded)', 'icon': Icons.directions_walk, 'allowRuns': true},
      {'label': 'Retired Hurt', 'icon': Icons.healing, 'allowRuns': true},
      {'label': 'Caught & Bowled', 'icon': Icons.swap_horiz, 'allowRuns': false},
      {'label': 'Absent Hurt', 'icon': Icons.airline_seat_flat, 'allowRuns': true},
      {'label': 'Time out', 'icon': Icons.timer_off, 'allowRuns': false},
      {'label': 'Hit Ball Twice', 'icon': Icons.replay_circle_filled_outlined, 'allowRuns': false},
    ];

    String? selectedType;
    bool allowRunInput = false;
    final runController = TextEditingController();

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Wicket Type',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: types.map((type) {
                    final isSelected = selectedType == type['label'];
                    return GestureDetector(
                      onTap: () {
                        final label = type['label'] as String;
                        final allow = type['allowRuns'] as bool;

                        setState(() {
                          selectedType = label;
                          allowRunInput = allow;
                        });

                        if (!allow) {
                          Navigator.pop(context, {
                            'type': label,
                            'runs': null,
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected ? Colors.red.shade100 : Colors.red.shade50,
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                          ],
                          border: Border.all(
                            color: isSelected ? Colors.red : Colors.redAccent.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(type['icon'] as IconData,
                                size: 30, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(type['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.redAccent : Colors.black87,
                                )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (allowRunInput) ...[
                  const Text("Runs before dismissal",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: runController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Enter runs (optional)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Submit"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (selectedType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please select a wicket type")),
                        );
                        return;
                      }
                      final runVal = int.tryParse(runController.text);
                      Navigator.pop(context, {
                        'type': selectedType,
                        'runs': runVal ?? 0,
                      });
                    },
                  )
                ]
              ],
            );
          },
        ),
      ),
    );
  }
}
