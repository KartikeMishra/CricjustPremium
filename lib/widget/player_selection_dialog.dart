import 'package:flutter/material.dart';

class PlayerSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final Function(Map<String, dynamic>) onSelect;
  final String title;

  const PlayerSelectionDialog({
    super.key,
    required this.players,
    required this.onSelect,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(player['Display_Name'] ?? 'Player'),
              subtitle: Text('ID: ${player['ID']}'),
              onTap: () {
                Navigator.pop(context);
                onSelect(player);
              },
            );
          },
        ),
      ),
    );
  }
}
