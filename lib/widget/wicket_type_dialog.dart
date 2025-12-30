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
      {'label': 'Mankaded', 'icon': Icons.directions_walk, 'allowRuns': true},
      {'label': 'Retired Hurt', 'icon': Icons.healing, 'allowRuns': true},
      {'label': 'Caught & Bowled', 'icon': Icons.swap_horiz, 'allowRuns': false},
      {'label': 'Absent Hurt', 'icon': Icons.airline_seat_flat, 'allowRuns': true},
      {'label': 'Time out', 'icon': Icons.timer_off, 'allowRuns': false},
      {'label': 'Hit the ball twice', 'icon': Icons.replay_circle_filled_outlined, 'allowRuns': false},
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
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Select Wicket Type',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                            color: isSelected ? Colors.red.shade100 : Colors.grey.shade100,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: Colors.redAccent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                            border: Border.all(
                              color: isSelected ? Colors.redAccent : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 28,
                                color: isSelected ? Colors.redAccent : Colors.black54,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                type['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.redAccent : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  if (allowRunInput) ...[
                    Text(
                      "Runs before dismissal",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: runController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter runs",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text("Submit"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ✅ Skip Button at Bottom-Right of Scroll View
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context, null),
                      icon: const Icon(Icons.skip_next),
                      label: const Text("Skssssip"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
