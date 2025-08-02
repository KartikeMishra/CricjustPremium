class MatchScoreRequest {
  final int matchId;
  final int battingTeamId;
  final int onStrikePlayerId;
  final int onStrikePlayerOrder;
  final int nonStrikePlayerId;
  final int nonStrikePlayerOrder;
  final int bowler;
  final int overNumber;
  final int ballNumber;
  final int runs;

  // Optional extras
  final String? extraRunType;     // "Wide", "No Ball", etc.—or "0" for none
  final int? extraRun;            // e.g. 2 for no-ball + 2 runs
  final int? wktkprId;            // new keeper if changed mid-match
  final String? ballType;         // e.g. "Bouncer", "Leg Break", ...
  final String? ballLength;       // e.g. "Good length", "Full Toss", ...
  final String? ballerTheWicket;  // "Over the Wicket" / "Around the Wicket"
  final String? shot;             // e.g. "Drive", "Sweep", ...
  final String? shotArea;         // e.g. "Long On", "Mid Wicket", ...
  final int? outPlayer;           // ID of player who got out
  final int? isWicket;            // 1 if wicket fell, else 0
  final String? wicketType;       // numeric string or label: "1", "Run Out", etc.
  final String? wicketTypeText;   // readable: "Caught", "Run Out", etc.
  final int? runOutBy;            // ID of the fielder who ran them out
  final int? catchBy;             // ID of the catcher
  final String? commentry;        // free-text commentary

  MatchScoreRequest({
    required this.matchId,
    required this.battingTeamId,
    required this.onStrikePlayerId,
    required this.onStrikePlayerOrder,
    required this.nonStrikePlayerId,
    required this.nonStrikePlayerOrder,
    required this.bowler,
    required this.overNumber,
    required this.ballNumber,
    required this.runs,
    this.extraRunType,
    this.extraRun,
    this.wktkprId,
    this.ballType,
    this.ballLength,
    this.ballerTheWicket,
    this.shot,
    this.shotArea,
    this.outPlayer,
    this.isWicket,
    this.wicketType,
    this.wicketTypeText,
    this.runOutBy,
    this.catchBy,
    this.commentry,
  });

  Map<String, String> toFormFields() {
    final m = <String, String>{
      'match_id': matchId.toString(),
      'batting_team_id': battingTeamId.toString(),
      'on_strike_player_id': onStrikePlayerId.toString(),
      'on_strike_player_order': onStrikePlayerOrder.toString(),
      'non_strike_player_id': nonStrikePlayerId.toString(),
      'non_strike_player_order': nonStrikePlayerOrder.toString(),
      'bowler': bowler.toString(),
      'over_number': overNumber.toString(),
      'ball_number': ballNumber.toString(),
      'runs': runs.toString(),
    };

    // Optional fields
    if (extraRunType?.trim().isNotEmpty ?? false) m['extra_run_type'] = extraRunType!.trim();
    if (extraRun != null) m['extra_run'] = extraRun.toString();
    if (wktkprId != null) m['wktkpr_id'] = wktkprId.toString();
    if (ballType?.trim().isNotEmpty ?? false) m['ball_type'] = ballType!.trim();
    if (ballLength?.trim().isNotEmpty ?? false) m['ball_length'] = ballLength!.trim();
    if (ballerTheWicket?.trim().isNotEmpty ?? false) m['baller_the_wicket'] = ballerTheWicket!.trim();
    if (shot?.trim().isNotEmpty ?? false) m['shot'] = shot!.trim();
    if (shotArea?.trim().isNotEmpty ?? false) m['shot_area'] = shotArea!.trim();
    if (outPlayer != null) m['out_player'] = outPlayer.toString();
    if (isWicket != null) m['is_wicket'] = isWicket.toString();
    if (wicketType?.trim().isNotEmpty ?? false) m['wicket_type'] = wicketType!.trim();
    if (wicketTypeText?.trim().isNotEmpty ?? false) m['wicket_type_text'] = wicketTypeText!.trim();
    if (runOutBy != null) m['run_out_by'] = runOutBy.toString();
    if (catchBy != null) m['catch_by'] = catchBy.toString();
    if (commentry?.trim().isNotEmpty ?? false) m['commentry'] = commentry!.trim();

    return m;
  }
}
