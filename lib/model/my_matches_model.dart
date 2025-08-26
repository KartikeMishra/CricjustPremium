// lib/model/my_matches_model.dart
class MyMatch {
  final int matchId;
  final String matchName;

  // Teams
  final int? teamOneId;          // 👈 NEW
  final int? teamTwoId;          // 👈 NEW
  final String teamOneName;
  final String teamTwoName;
  final String? teamOneLogo;     // 👈 NEW
  final String? teamTwoLogo;     // 👈 NEW

  // Meta
  final String? result;
  final String? resultType;
  final int? winningTeam;
  final int? losingTeam;
  final String matchDate;
  final String matchTime;
  final int? overs;
  final int? firstInningsId;
  final int? secondInningsId;
  final int status;
  final String? displayName;
  final String ballType;
  final String? venue;           // 👈 optional, handy for later

  MyMatch({
    required this.matchId,
    required this.matchName,
    required this.teamOneName,
    required this.teamTwoName,
    required this.matchDate,
    required this.matchTime,
    required this.status,
    required this.ballType,
    this.teamOneId,
    this.teamTwoId,
    this.teamOneLogo,
    this.teamTwoLogo,
    this.result,
    this.resultType,
    this.winningTeam,
    this.losingTeam,
    this.overs,
    this.firstInningsId,
    this.secondInningsId,
    this.displayName,
    this.venue,
  });

  // ---------- helpers ----------
  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _toStr(dynamic v) => v?.toString();

  static Map<String, dynamic>? _toMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Return the first present key, cast with a function that may return null.
  static T? _first<T>(
      Map<String, dynamic> j,
      List<String> keys,
      T? Function(dynamic) cast,
      ) {
    for (final k in keys) {
      if (j.containsKey(k) && j[k] != null) {
        return cast(j[k]);
      }
    }
    return null;
  }

  factory MyMatch.fromJson(Map<String, dynamic> j) {
    // Nested team blobs (per your API sample)
    final t1 = _first<Map<String, dynamic>>(j, ['team_1', 'team1', 'team_one'], _toMap);
    final t2 = _first<Map<String, dynamic>>(j, ['team_2', 'team2', 'team_two'], _toMap);

    final t1Id    = _toInt(t1?['team_id']);
    final t2Id    = _toInt(t2?['team_id']);
    final t1NameN = _toStr(t1?['team_name']);
    final t2NameN = _toStr(t2?['team_name']);
    final t1LogoN = _toStr(t1?['team_logo']);
    final t2LogoN = _toStr(t2?['team_logo']);

    final matchId   = _first<int>(j, ['match_id', 'id', 'matchId'], _toInt) ?? 0;
    final matchName = _first<String>(j, ['match_name', 'name', 'title'], _toStr) ?? '';

    // Names: prefer nested, fall back to old flat variants
    final teamOneName = t1NameN ??
        _first<String>(j, ['team_one_name', 'team_one', 'team1_name', 'team1', 'team_one_title'], _toStr) ??
        '';
    final teamTwoName = t2NameN ??
        _first<String>(j, ['team_two_name', 'team_two', 'team2_name', 'team2', 'team_two_title'], _toStr) ??
        '';

    // Logos: prefer nested, fall back to legacy flat keys if any
    final teamOneLogo = t1LogoN ??
        _first<String>(j, ['team_one_logo','team1_logo','team_one_image','team1_image','team_one_logo_url'], _toStr);
    final teamTwoLogo = t2LogoN ??
        _first<String>(j, ['team_two_logo','team2_logo','team_two_image','team2_image','team_two_logo_url'], _toStr);

    final result     = _first<String>(j, ['match_result', 'result_text', 'result'], _toStr);
    final resultType = _first<String>(j, ['result_type', 'type', 'status_text'], _toStr);
    final winningTeam = _first<int>(j, ['winning_team', 'match_winner', 'winner_team_id', 'winner'], _toInt);
    final losingTeam  = _first<int>(j, ['losing_team', 'loser_team_id'], _toInt);

    final matchDate = _first<String>(j, ['match_date', 'date'], _toStr) ?? '';
    final matchTime = _first<String>(j, ['match_time', 'time'], _toStr) ?? '';

    final overs = _first<int>(j, ['match_overs', 'overs'], _toInt);
    final firstInningsId  = _first<int>(j, ['first_inning', 'first_innings_id'], _toInt);
    final secondInningsId = _first<int>(j, ['second_inning', 'second_innings_id'], _toInt);

    final status = _first<int>(j, ['status', 'match_status'], _toInt) ?? 0;
    final displayName = _first<String>(j, ['display_name', 'owner_name', 'created_by_name'], _toStr);
    final ballType = _first<String>(j, ['ball_type', 'ball'], _toStr) ?? '';
    final venue   = _first<String>(j, ['venue', 'ground'], _toStr);

    return MyMatch(
      matchId: matchId,
      matchName: matchName,
      teamOneId: t1Id,
      teamTwoId: t2Id,
      teamOneName: teamOneName,
      teamTwoName: teamTwoName,
      teamOneLogo: teamOneLogo,
      teamTwoLogo: teamTwoLogo,
      result: result,
      resultType: resultType,
      winningTeam: winningTeam,
      losingTeam: losingTeam,
      matchDate: matchDate,
      matchTime: matchTime,
      overs: overs,
      firstInningsId: firstInningsId,
      secondInningsId: secondInningsId,
      status: status,
      displayName: displayName,
      ballType: ballType,
      venue: venue,
    );
  }
}
