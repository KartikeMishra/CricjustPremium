import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../service/match_score_service.dart';

/// Shows the End Match dialog and returns the Super Over matchId if created.
/// Returns `null` when no Super Over is created or on cancel.
Future<int?> showEndMatchDialog({
  required BuildContext context,
  required int matchId,
  required String token,
  required List<Map<String, dynamic>> teams,
}) async {
  String resultType = 'Win';
  int? winningTeam;
  int? runsOrWickets;
  String? winByType;
  String? drawComment;
  bool superOver = false;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // Guard against double submit inside StatefulBuilder
  bool isSubmitting = false;

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
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
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
                      final id = _toInt(t['team_id']);
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
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
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
                    // IMPORTANT: API expects "Yes"
                    superOvers: (resultType == 'Tie') ? 'Yes' : (superOver ? 'Yes' : null),
                  );

                  // If your service exposes `superOverMatchId`, use it.
                  // Otherwise, adapt to your response shape.
                  final int? newId = res?.superOverMatchId;
                  Navigator.pop(context, newId);
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
