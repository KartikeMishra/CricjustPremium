// lib/widget/dialogs/end_match_dialog.dart  (or wherever you keep it)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../service/match_score_service.dart';

class _SimplePlayer {
  final int id;
  final String name;
  final int teamId;
  final String? image;
  _SimplePlayer({required this.id, required this.name, required this.teamId, this.image});
}

/// Shows the End Match dialog and returns the Super Over matchId if created.
/// Returns `null` when no Super Over is created or on cancel.
/// After a successful non–Super Over end, it will ask for Player of the Match and save it.
Future<int?> showEndMatchDialog({
  required BuildContext context,
  required int matchId,
  required String token,
  required List<Map<String, dynamic>> teams,
  /// Optional: pass combined players to avoid network call.
  /// Each map should have: { "id": int, "name": String, "team_id": int, "image": String? }
  List<Map<String, dynamic>>? allPlayers,
}) async {
  String resultType = 'Win';
  int? winningTeam;
  int? runsOrWickets;
  String? winByType;
  String? drawComment;
  bool superOver = false;

  int toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool isSubmitting = false;

  Future<List<_SimplePlayer>> _fetchSquadsFromApi() async {
    final uri = Uri.parse(
      'https://cricjust.in/wp-json/custom-api-for-cricket/get-match?match_id=$matchId&type=squad',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    if ((map['status'] == 1 || map['status'] == '1') && map['data'] != null) {
      final data = map['data'] as Map<String, dynamic>;

      List<_SimplePlayer> collect(dynamic team, int fallbackTeamId) {
        final tid = toInt(team?['team_id'] ?? fallbackTeamId);
        final List squad =
        (team?['squad'] ??
            team?['players'] ??
            team?['team_1_squad'] ??
            team?['team_2_squad'] ??
            team?['team_players'] ??
            []) as List;

        return squad.map((p) {
          final id = toInt(p['player_id'] ?? p['ID'] ?? p['id']);
          final name = (p['display_name'] ?? p['name'] ?? p['user_login'] ?? 'Player').toString();
          final img = (p['player_image'] ?? p['image'])?.toString();
          return _SimplePlayer(id: id, name: name, teamId: tid, image: img);
        }).where((e) => e.id != 0).toList();
      }

      final t1 = data['team_1'];
      final t2 = data['team_2'];
      final t1id = toInt(t1?['team_id']);
      final t2id = toInt(t2?['team_id']);

      return [
        ...collect(t1, t1id),
        ...collect(t2, t2id),
      ];
    }
    return [];
  }

  Future<List<_SimplePlayer>> _preparePlayers() async {
    if (allPlayers != null && allPlayers!.isNotEmpty) {
      return allPlayers!
          .map((m) => _SimplePlayer(
        id: toInt(m['id']),
        name: (m['name'] ?? 'Player').toString(),
        teamId: toInt(m['team_id']),
        image: m['image']?.toString(),
      ))
          .where((e) => e.id != 0 && e.teamId != 0)
          .toList();
    }
    // No pre-supplied list → fetch from API
    return await _fetchSquadsFromApi();
  }

  Future<int?> _pickPlayerOfTheMatch(List<_SimplePlayer> players) async {
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load players to select PoTM')),
      );
      return null;
    }

    players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final teamNames = {
      for (final t in teams) toInt(t['team_id']): (t['team_name'] ?? 'Team').toString()
    };

    int? selectedId;
    String query = '';

    return await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSB) {
            final filtered = players
                .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42, height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text('Select Player of the Match',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search player...',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                      ),
                      onChanged: (v) => setSB(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          final subtitle = teamNames[p.teamId] ?? 'Team';
                          return RadioListTile<int>(
                            value: p.id,
                            groupValue: selectedId,
                            onChanged: (v) => setSB(() => selectedId = v),
                            title: Text(p.name),
                            subtitle: Text(subtitle),
                            secondary: (p.image != null && p.image!.isNotEmpty)
                                ? CircleAvatar(backgroundImage: NetworkImage(p.image!))
                                : const CircleAvatar(child: Icon(Icons.person)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: selectedId == null
                                ? null
                                : () => Navigator.pop(ctx, selectedId),
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  return await showDialog<int?>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setSB) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("End Match"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: resultType,
                  items: const ['Win', 'Draw', 'WinBToss', 'Tie']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setSB(() {
                    resultType = v!;
                    winningTeam = null;
                    runsOrWickets = null;
                    winByType = null;
                    drawComment = null;
                    superOver = false;
                  }),
                  decoration: const InputDecoration(labelText: "Result Type"),
                ),
                const SizedBox(height: 12),

                if (resultType == 'Win' || resultType == 'WinBToss') ...[
                  DropdownButtonFormField<int>(
                    value: winningTeam,
                    decoration: const InputDecoration(labelText: "Winning Team"),
                    items: teams.map((t) {
                      final id = toInt(t['team_id']);
                      final name = (t['team_name'] ?? 'Team').toString();
                      return DropdownMenuItem<int>(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setSB(() => winningTeam = v),
                  ),
                  const SizedBox(height: 12),
                ],

                if (resultType == 'Win') ...[
                  TextFormField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: "Runs or Wickets"),
                    onChanged: (v) => runsOrWickets = int.tryParse(v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: winByType,
                    items: const ['Runs', 'Wickets']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setSB(() => winByType = v),
                    decoration: const InputDecoration(labelText: "Win By Type"),
                  ),
                  const SizedBox(height: 12),
                ],

                if (resultType == 'Draw') ...[
                  TextField(
                    decoration: const InputDecoration(labelText: "Draw Comment"),
                    onChanged: (v) => drawComment = v,
                  ),
                  const SizedBox(height: 12),
                ],

                if (resultType == 'Tie')
                  CheckboxListTile(
                    value: superOver,
                    onChanged: (v) => setSB(() => superOver = v ?? false),
                    title: const Text("Use Super Over?"),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                if ((resultType == 'Win' || resultType == 'WinBToss') && winningTeam == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select the winning team')),
                  );
                  return;
                }
                if (resultType == 'Win') {
                  if (runsOrWickets == null || runsOrWickets! <= 0 || winByType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a positive margin and choose Runs/Wickets')),
                    );
                    return;
                  }
                }

                setSB(() => isSubmitting = true);
                try {
                  final res = await MatchScoreService.endMatchWithResult(
                    context: context,
                    token: token,
                    matchId: matchId,
                    resultType: resultType,
                    winningTeam: winningTeam,
                    runsOrWicket: runsOrWickets,
                    winByType: winByType,
                    drawComment: drawComment,
                    superOvers: (resultType == 'Tie') ? 'Yes' : (superOver ? 'Yes' : null),
                  );

                  // Use your actual response fields; this matches what you hinted at.
                  final int? newSuperOverId = res.superOverMatchId;

                  // If Super Over is created, skip PoTM for now.
                  if (resultType == 'Tie' && (superOver || newSuperOverId != null)) {
                    Navigator.pop(context, newSuperOverId);
                    return;
                  }

                  // Match truly ended → pick Player of the Match
                  final players = await _preparePlayers();
                  final selectedPlayerId = await _pickPlayerOfTheMatch(players);

                  if (selectedPlayerId != null) {
                    final ok = await MatchScoreService.savePlayerOfTheMatch(
                      context: context,
                      token: token,
                      matchId: matchId,
                      playerId: selectedPlayerId,
                    );
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Player of the Match saved!')),
                      );
                    }
                  }

                  Navigator.pop(context, newSuperOverId);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to end match: $e')),
                  );
                  setSB(() => isSubmitting = false);
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    ),
  );
}
