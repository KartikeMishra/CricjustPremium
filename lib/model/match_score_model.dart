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

  // all the optional extras
  final String? extraRunType; // "Wide", "No Ball", etc—or "0" for none
  final int? extraRun; // e.g. 2 for no‐ball + 2 runs
  final int? wktkprId; // new keeper if changed mid‐match
  final String? ballType; // e.g. "Bouncer", "Leg Break", ...
  final String? ballLength; // e.g. "Good length", "Full Toss", ...
  final String? ballerTheWicket; // "Over the Wicket" / "Around the Wicket"
  final String? shot; // e.g. "Drive", "Sweep", ...
  final String? shotArea; // e.g. "Long On", "Mid Wicket", ...
  final int? outPlayer; // ID of player who got out
  final int? isWicket; // 1 if wicket fell, else 0
  final String? wicketType; // "Bowled", "Caught", "Run Out", ...
  final int? runOutBy; // ID of the fielder who ran them out
  final int? catchBy; // ID of the catcher
  final String? commentry; // free‐text

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
      // only include non-null optionals:
      if (extraRunType != null) 'extra_run_type': extraRunType!,
      if (extraRun != null) 'extra_run': extraRun!.toString(),
      if (wktkprId != null) 'wktkpr_id': wktkprId!.toString(),
      if (ballType != null) 'ball_type': ballType!,
      if (ballLength != null) 'ball_length': ballLength!,
      if (ballerTheWicket != null) 'baller_the_wicket': ballerTheWicket!,
      if (shot != null) 'shot': shot!,
      if (shotArea != null) 'shot_area': shotArea!,
      if (outPlayer != null) 'out_player': outPlayer!.toString(),
      if (isWicket != null) 'is_wicket': isWicket!.toString(),
      if (wicketType != null) 'wicket_type': wicketType!,
      if (runOutBy != null) 'run_out_by': runOutBy!.toString(),
      if (catchBy != null) 'catch_by': catchBy!.toString(),
      if (commentry != null) 'commentry': commentry!,
    };
    return m;
  }
}
