class MatchScoreRequest {
  // ---- Required core ----
  final int matchId;                  // match_id  (often required by endpoint)
  final int battingTeamId;            // batting_team_id
  final int onStrikePlayerId;         // on_strike_player_id
  final int onStrikePlayerOrder;      // on_strike_player_order
  final int nonStrikePlayerId;        // non_strike_player_id
  final int nonStrikePlayerOrder;     // non_strike_player_order
  final int bowler;                   // bowler
  final int overNumber;               // over_number
  final int ballNumber;               // ball_number
  final int runs;                     // runs

  // ---- Optional extras / meta (all snake_case in payload) ----
  final String? extraRunType;         // extra_run_type   (e.g. "Wide", "No Ball", "Leg Bye", "Bye" or codes if API needs)
  final int?    extraRun;             // extra_run
  final int?    wktkprId;             // wktkpr_id
  final String? ballType;             // ball_type
  final String? ballLength;           // ball_length
  final String? ballerTheWicket;      // baller_the_wicket (spelling per your API list)
  final String? shot;                 // shot
  final String? shotArea;             // shot_area

  // ---- Wicket block ----
  final int?    outPlayer;            // out_player (batter id)
  final int?    isWicket;             // is_wicket (1/0)

  // Not in your API list (kept in model for UI but NOT sent)
  final String? wicketType;           // NOT SENT
  final String? wicketTypeText;       // NOT SENT

  // ---- Fielder credits ----
  final int?    runOutBy;             // run_out_by (fielder id who effected run out)
  final int?    catchBy;              // catch_by

  // ---- Commentary ----
  final String? commentry;            // commentry (per your API spelling)

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
    this.wicketType,      // kept but not posted
    this.wicketTypeText,  // kept but not posted
    this.runOutBy,
    this.catchBy,
    this.commentry,
  });

  /// Exactly the keys your API expects (form-encoded).
  /// Do NOT jsonEncode this map when posting as x-www-form-urlencoded.
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

      // 👇 always present
      'extra_run_type': (extraRunType?.trim().isNotEmpty ?? false) ? extraRunType!.trim() : '0',
    };

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
    if (wicketTypeText?.trim().isNotEmpty ?? false) m['wicket_type_text'] = wicketTypeText!.trim(); // optional
    if (runOutBy != null) m['run_out_by'] = runOutBy.toString();
    if (catchBy != null) m['catch_by'] = catchBy.toString();
    if (commentry?.trim().isNotEmpty ?? false) m['commentry'] = commentry!.trim();

    return m;
  }

  /// Optional: JSON payload with the same snake_case keys, if you ever switch endpoints.
  Map<String, dynamic> toJsonSnakeCase() {
    final m = <String, dynamic>{
      'match_id'               : matchId,
      'batting_team_id'        : battingTeamId,
      'on_strike_player_id'    : onStrikePlayerId,
      'on_strike_player_order' : onStrikePlayerOrder,
      'non_strike_player_id'   : nonStrikePlayerId,
      'non_strike_player_order': nonStrikePlayerOrder,
      'bowler'                 : bowler,
      'over_number'            : overNumber,
      'ball_number'            : ballNumber,
      'runs'                   : runs,
      'extra_run_type'         : extraRunType,
      'extra_run'              : extraRun,
      'wktkpr_id'              : wktkprId,
      'ball_type'              : ballType,
      'ball_length'            : ballLength,
      'baller_the_wicket'      : ballerTheWicket,
      'shot'                   : shot,
      'shot_area'              : shotArea,
      'out_player'             : outPlayer,
      'is_wicket'              : isWicket,
      'run_out_by'             : runOutBy,
      'catch_by'               : catchBy,
      'commentry'              : commentry,
      // 'wicket_type'          : wicketType,      // not in API list
      // 'wicket_type_text'     : wicketTypeText,  // not in API list
    };
    m.removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    return m;
  }

  /// Quick sanity checks before submit. Returns list of missing/invalid keys.
  /// Use this to debug “run_out_by not saving” (e.g., missing out_player / is_wicket).
  List<String> validate() {
    final problems = <String>[];

    // Required always
    if (battingTeamId <= 0) problems.add('batting_team_id');
    if (onStrikePlayerId <= 0) problems.add('on_strike_player_id');
    if (onStrikePlayerOrder <= 0) problems.add('on_strike_player_order');
    if (nonStrikePlayerId <= 0) problems.add('non_strike_player_id');
    if (nonStrikePlayerOrder <= 0) problems.add('non_strike_player_order');
    if (bowler <= 0) problems.add('bowler');
    if (overNumber < 0) problems.add('over_number');
    if (ballNumber <= 0) problems.add('ball_number');
    if (runs < 0) problems.add('runs');

    // Wicket consistency
    if ((isWicket ?? 0) == 1) {
      if (outPlayer == null || outPlayer! <= 0) problems.add('out_player');
      // If this is a run-out, you must also provide run_out_by (server won’t infer it).
      // We can’t detect run-out type here since API doesn’t accept wicket_type,
      // so enforce rule if runOutBy is set OR you enforce from UI flow.
      if (runOutBy == null || runOutBy! <= 0) {
        // optional: uncomment the next line if you want to force a fielder on *every* wicket
        // problems.add('run_out_by');
      }
    }

    return problems;
  }

  factory MatchScoreRequest.fromMap(Map<String, dynamic> json) {
    int? _toInt(dynamic v) => v == null ? null : int.tryParse(v.toString());

    return MatchScoreRequest(
      matchId                : int.parse(json['match_id']),
      battingTeamId          : int.parse(json['batting_team_id']),
      onStrikePlayerId       : int.parse(json['on_strike_player_id']),
      onStrikePlayerOrder    : int.parse(json['on_strike_player_order']),
      nonStrikePlayerId      : int.parse(json['non_strike_player_id']),
      nonStrikePlayerOrder   : int.parse(json['non_strike_player_order']),
      bowler                 : int.parse(json['bowler']),
      overNumber             : int.parse(json['over_number']),
      ballNumber             : int.parse(json['ball_number']),
      runs                   : int.parse(json['runs']),
      extraRunType           : json['extra_run_type'],
      extraRun               : _toInt(json['extra_run']),
      wktkprId               : _toInt(json['wktkpr_id']),
      ballType               : json['ball_type'],
      ballLength             : json['ball_length'],
      ballerTheWicket        : json['baller_the_wicket'],
      shot                   : json['shot'],
      shotArea               : json['shot_area'],
      outPlayer              : _toInt(json['out_player']),
      isWicket               : _toInt(json['is_wicket']),
      // kept but not part of API list:
      wicketType             : json['wicket_type'],
      wicketTypeText         : json['wicket_type_text'],
      runOutBy               : _toInt(json['run_out_by']),
      catchBy                : _toInt(json['catch_by']),
      commentry              : json['commentry'],
    );
  }
}
