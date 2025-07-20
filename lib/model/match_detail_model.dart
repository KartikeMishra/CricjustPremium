class MatchDetail {
  final int matchId;
  final String matchName;
  final String tournamentName;
  final String matchDate;
  final String matchTime;
  final String ballType;
  final int matchOvers;
  final String venue;
  final Team team1;
  final Team team2;
  final String matchToss;
  final String matchResult;

  MatchDetail({
    required this.matchId,
    required this.matchName,
    required this.tournamentName,
    required this.matchDate,
    required this.matchTime,
    required this.ballType,
    required this.matchOvers,
    required this.venue,
    required this.team1,
    required this.team2,
    required this.matchToss,
    required this.matchResult,
  });

  factory MatchDetail.fromJson(Map<String, dynamic> json) {
    return MatchDetail(
      matchId: json['match_id'] ?? 0,
      matchName: json['match_name'] ?? '',
      tournamentName: json['tournament_name'] ?? '',
      matchDate: json['match_date'] ?? '',
      matchTime: json['match_time'] ?? '',
      ballType: json['ball_type'] ?? '',
      matchOvers: json['match_overs'] ?? 0,
      venue: json['venue'] ?? '',
      team1: Team.fromJson(json['team_1'] ?? {}),
      team2: Team.fromJson(json['team_2'] ?? {}),
      matchToss: json['match_toss'] ?? '',
      matchResult: json['match_result'] ?? '',
    );
  }
}

class Team {
  final int teamId;
  final String teamName;
  final String teamLogo;
  final int totalRuns;
  final int totalWickets;
  final dynamic oversDone;
  final int ballsDone;

  Team({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.totalRuns,
    required this.totalWickets,
    required this.oversDone,
    required this.ballsDone,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId: json['team_id'] ?? 0,
      teamName: json['team_name'] ?? '',
      teamLogo: json['team_logo'] ?? '',
      totalRuns: json['total_runs'] ?? 0,
      totalWickets: json['total_wickets'] ?? 0,
      oversDone: json['overs_done'],
      ballsDone: json['balls_done'] ?? 0,
    );
  }
}
