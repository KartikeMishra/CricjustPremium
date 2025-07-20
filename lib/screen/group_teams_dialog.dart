import 'package:flutter/material.dart';
import '../theme/color.dart';

class AssignTeamsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allTeams;
  final List<Map<String, dynamic>> alreadyAssignedTeams;
  final void Function(List<Map<String, dynamic>> selectedTeams) onAssign;

  const AssignTeamsDialog({
    super.key,
    required this.allTeams,
    required this.alreadyAssignedTeams,
    required this.onAssign,
  });

  @override
  State<AssignTeamsDialog> createState() => _AssignTeamsDialogState();
}

class _AssignTeamsDialogState extends State<AssignTeamsDialog> {
  List<Map<String, dynamic>> _selectedTeams = [];

  @override
  void initState() {
    super.initState();
    _selectedTeams = List.from(widget.alreadyAssignedTeams);
  }

  void _toggleTeam(Map<String, dynamic> team) {
    final exists = _selectedTeams.any((t) => t['team_id'] == team['team_id']);
    setState(() {
      if (exists) {
        _selectedTeams.removeWhere((t) => t['team_id'] == team['team_id']);
      } else {
        _selectedTeams.add(team);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final chipBg = isDark ? Colors.blueGrey.shade800 : Colors.blue.shade50;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Assign Teams",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.allTeams.isEmpty)
              const Text("No teams available.")
            else
              Expanded(
                child: ListView.builder(
                  itemCount: widget.allTeams.length,
                  itemBuilder: (context, index) {
                    final team = widget.allTeams[index];
                    final selected = _selectedTeams.any(
                      (t) => t['team_id'] == team['team_id'],
                    );
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        tileColor: selected
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        leading: CircleAvatar(
                          backgroundImage:
                              team['team_logo'].toString().isNotEmpty
                              ? NetworkImage(team['team_logo'])
                              : null,
                          child: team['team_logo'].toString().isEmpty
                              ? const Icon(Icons.group)
                              : null,
                        ),
                        title: Text(team['team_name']),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: selected ? AppColors.primary : Colors.grey,
                        ),
                        onTap: () => _toggleTeam(team),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _selectedTeams.map((t) {
                return Chip(
                  label: Text(t['team_name']),
                  backgroundColor: chipBg,
                  onDeleted: () => _toggleTeam(t),
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onAssign(_selectedTeams);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Assign"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
