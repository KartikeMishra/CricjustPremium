class MatchModel {
  final int matchId;
  final String matchName;
  final String tournamentName;
  final int tournamentId;
  final String venue;
  final String matchDate;
  final String matchTime;
  final String ballType;
  final int matchOvers;
  final String toss;
  final String result;

  final String team1Name;
  final String team1Logo;
  final int team1Runs;
  final int team1Wickets;
  final int team1Overs;
  final int team1Balls;

  final String team2Name;
  final String team2Logo;
  final int team2Runs;
  final int team2Wickets;
  final int team2Overs;
  final int team2Balls;

  MatchModel({
    required this.matchId,
    required this.matchName,
    required this.tournamentName,
    required this.tournamentId,
    required this.venue,
    required this.matchDate,
    required this.matchTime,
    required this.ballType,
    required this.matchOvers,
    required this.toss,
    required this.result,
    required this.team1Name,
    required this.team1Logo,
    required this.team1Runs,
    required this.team1Wickets,
    required this.team1Overs,
    required this.team1Balls,
    required this.team2Name,
    required this.team2Logo,
    required this.team2Runs,
    required this.team2Wickets,
    required this.team2Overs,
    required this.team2Balls,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final team1 = json['team_1'] ?? {};
    final team2 = json['team_2'] ?? {};

    return MatchModel(
      matchId: json['match_id'] ?? 0,
      matchName: json['match_name'] ?? '',
      tournamentName: json['tournament_name'] ?? '',
      tournamentId: json['tournament_id'] ?? 0,
      venue: json['venue'] ?? '',
      matchDate: json['match_date'] ?? '',
      matchTime: json['match_time'] ?? '',
      ballType: json['ball_type'] ?? '',
      matchOvers: json['match_overs'] ?? 0,
      toss: json['match_toss'] ?? '',
      result: json['match_result'] ?? '',
      team1Name: team1['team_name']?.trim() ?? '',
      team1Logo: team1['team_logo'] ?? '',
      team1Runs: team1['total_runs'] ?? 0,
      team1Wickets: team1['total_wickets'] ?? 0,
      team1Overs: team1['overs_done'] ?? 0,
      team1Balls: team1['balls_done'] ?? 0,
      team2Name: team2['team_name']?.trim() ?? '',
      team2Logo: team2['team_logo'] ?? '',
      team2Runs: team2['total_runs'] ?? 0,
      team2Wickets: team2['total_wickets'] ?? 0,
      team2Overs: team2['overs_done'] ?? 0,
      team2Balls: team2['balls_done'] ?? 0,
    );
  }
}
