import 'package:flutter/material.dart';

Future<int?> showPlayerSelector({
  required BuildContext context,
  required List<Map<String, dynamic>> players,
  required bool isBatsman,
  required Set<int> usedPlayers,
  Set<int> dismissedPlayers = const {},
  required int? lastBowlerId,
  required double maxBowlerOvers,
  required Map<int, dynamic> bowlerStatsMap,
  required Map<int, double> bowlerOversMap,
  required void Function({
  required int id,
  required String name,
  required bool isStriker,
  }) onBatsmanSelected,
  required void Function({
  required int id,
  required String name,
  required double overs,
  required int runs,
  required int wickets,
  required int maidens,
  required double economy,
  }) onBowlerSelected,
  bool? forceStriker,
  String? title,
}) async {
  final available = players.where((p) {
    final id = p['id'] as int;

    if (isBatsman) {
      if (usedPlayers.contains(id)) return false;
      if (dismissedPlayers.contains(id)) return false;
    } else {
      final oversBowled = (bowlerOversMap[id] ?? 0.0).toDouble();
      if (oversBowled >= maxBowlerOvers) return false;
      if (lastBowlerId == id) return false;
    }
    return true;
  }).toList();

  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No ${isBatsman ? "batsmen" : "bowlers"} left to select.')),
    );
    return null;
  }

  return await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: Theme.of(context).canvasColor,
        height: 420,
        child: Column(
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final p = available[i];
                  final id = p['id'] as int;
                  final name = (p['name'] ?? p['display_name'] ?? p['user_login'] ?? 'Unnamed') as String;

                  return ListTile(
                    leading: CircleAvatar(child: Text(name[0])),
                    title: Text(name),
                    subtitle: isBatsman
                        ? null
                        : Text(
                      '${(bowlerOversMap[id] ?? 0.0).toStringAsFixed(1)} / ${maxBowlerOvers.toStringAsFixed(1)} overs',
                    ),
                    onTap: () async {
                      if (isBatsman) {
                        bool? isStriker = forceStriker;

                        if (isStriker == null) {
                          final role = await showDialog<String>(
                            context: context,
                            builder: (ctx) {
                              String? picked;
                              return StatefulBuilder(
                                builder: (ctx, setSt) => AlertDialog(
                                  title: const Text("Select Batsman Role"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RadioListTile<String>(
                                        title: const Text("On Strike"),
                                        value: "on",
                                        groupValue: picked,
                                        onChanged: (v) => setSt(() => picked = v),
                                      ),
                                      RadioListTile<String>(
                                        title: const Text("Non Strike"),
                                        value: "non",
                                        groupValue: picked,
                                        onChanged: (v) => setSt(() => picked = v),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, picked),
                                      child: const Text("Confirm"),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );

                          if (role == null) return;
                          isStriker = role == "on";
                        }

                        onBatsmanSelected(id: id, name: name, isStriker: isStriker);
                        Navigator.pop(context, id);
                      } else {
                        final stats = bowlerStatsMap[id] ?? {};
                        final overs = bowlerOversMap[id] ?? 0.0;

                        onBowlerSelected(
                          id: id,
                          name: name,
                          overs: overs,
                          runs: stats['runs'] ?? 0,
                          wickets: stats['wickets'] ?? 0,
                          maidens: stats['maiden'] ?? 0,
                          economy: stats['econ']?.toDouble() ?? 0.0,
                        );

                        Navigator.pop(context, id);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
