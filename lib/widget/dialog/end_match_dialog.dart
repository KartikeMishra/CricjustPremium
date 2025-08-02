import 'package:flutter/material.dart';
import '../../service/match_score_service.dart';

Future<void> showEndMatchDialog({
  required BuildContext context,
  required int matchId,
  required String token,
  required List<Map<String, dynamic>> teams, // 👈 Pass team list here
}) async {
  String resultType = 'Win';
  int? winningTeam;
  int? runsOrWickets;
  String? winByType;
  String? drawComment;
  bool superOver = false;

  await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("End Match"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: resultType,
                    items: ['Win', 'Draw', 'WinBToss', 'Tie']
                        .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                        .toList(),
                    onChanged: (val) => setState(() => resultType = val!),
                    decoration: const InputDecoration(labelText: "Result Type"),
                  ),
                  if (resultType == 'Win' || resultType == 'WinBToss')
                    DropdownButtonFormField<int>(
                      value: winningTeam,
                      decoration: const InputDecoration(labelText: "Winning Team"),
                      items: teams.map((team) {
                        return DropdownMenuItem<int>(
                          value: team['team_id'],
                          child: Text(team['team_name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => winningTeam = val),
                    ),
                  if (resultType == 'Win')
                    Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(labelText: "Runs or Wickets"),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => runsOrWickets = int.tryParse(val),
                        ),
                        DropdownButtonFormField<String>(
                          value: winByType,
                          items: ['Runs', 'Wickets']
                              .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                              .toList(),
                          onChanged: (val) => setState(() => winByType = val),
                          decoration: const InputDecoration(labelText: "Win By Type"),
                        ),
                      ],
                    ),
                  if (resultType == 'Draw')
                    TextField(
                      decoration: const InputDecoration(labelText: "Draw Comment"),
                      onChanged: (val) => drawComment = val,
                    ),
                  if (resultType == 'Tie')
                    CheckboxListTile(
                      value: superOver,
                      title: const Text("Use Super Over?"),
                      onChanged: (val) => setState(() => superOver = val ?? false),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await MatchScoreService.endMatch(
                    context: context,
                    token: token,
                    matchId: matchId,
                    resultType: resultType,
                    winningTeam: winningTeam,
                    runsOrWicket: runsOrWickets,
                    winByType: winByType,
                    drawComment: drawComment,
                    superOvers: superOver ? 'yes' : null,
                  );
                },
                child: const Text("Submit"),
              ),
            ],
          );
        },
      );
    },
  );
}
