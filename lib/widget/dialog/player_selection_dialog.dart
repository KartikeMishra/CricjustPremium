import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showPlayerPickerDialog({
  required BuildContext context,
  required String title,
  required List<Map<String, dynamic>> players,
}) async {
  int? selectedId;

  return await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return RadioListTile<int>(
                title: Text(player['display_name'] ?? player['user_login'] ?? 'Unknown'),
                value: player['id'],
                groupValue: selectedId,
                onChanged: (val) {
                  selectedId = val;
                  (ctx as Element).markNeedsBuild();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (selectedId != null) {
                final selected = players.firstWhere((p) => p['id'] == selectedId);
                Navigator.pop(ctx, selected);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      );
    },
  );
}
