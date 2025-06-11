class TournamentMatchDetail {
  final String matchId;
  final String? parentMatch;
  final String userId;
  final String tournamentId;
  final String tournamentMatchType;
  final String teamOne;
  final String teamOne11;
  final String teamOneCap;
  final String teamOneWktkpr;
  final String teamTwo;
  final String teamTwoCap;
  final String teamTwoWktkpr;
  final String teamTwo11;
  final String venue;
  final String matchDate;
  final String matchTime;
  final String ballType;
  final String matchOvers;
  final String? ballersMaxOvers;
  final String umpires;
  final String? commentators;
  final String tossWin;
  final String? firstInning;
  final String? secondInning;
  final String winningTeam;
  final String isFirstInningClosed;
  final String losingTeam;
  final String matchResult;
  final String? motm;
  final String resultType;
  final String status;
  final String created;
  final String matchName;
  final String tossWinChooses;
  final String notice;
  final String? youtube;
  final String ssmScorecard;
  final String ssmBatter;
  final String ssmBowler;
  final String ssmStatCom;
  final String ssmColorTheme;

  TournamentMatchDetail({
    required this.matchId,
    this.parentMatch,
    required this.userId,
    required this.tournamentId,
    required this.tournamentMatchType,
    required this.teamOne,
    required this.teamOne11,
    required this.teamOneCap,
    required this.teamOneWktkpr,
    required this.teamTwo,
    required this.teamTwoCap,
    required this.teamTwoWktkpr,
    required this.teamTwo11,
    required this.venue,
    required this.matchDate,
    required this.matchTime,
    required this.ballType,
    required this.matchOvers,
    this.ballersMaxOvers,
    required this.umpires,
    this.commentators,
    required this.tossWin,
    this.firstInning,
    this.secondInning,
    required this.winningTeam,
    required this.isFirstInningClosed,
    required this.losingTeam,
    required this.matchResult,
    this.motm,
    required this.resultType,
    required this.status,
    required this.created,
    required this.matchName,
    required this.tossWinChooses,
    required this.notice,
    this.youtube,
    required this.ssmScorecard,
    required this.ssmBatter,
    required this.ssmBowler,
    required this.ssmStatCom,
    required this.ssmColorTheme,
  });

  factory TournamentMatchDetail.fromJson(Map<String, dynamic> json) {
    return TournamentMatchDetail(
      matchId: json['match_id']?.toString() ?? '',
      parentMatch: json['parent_match']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      tournamentMatchType: json['tournament_match_type']?.toString() ?? '',
      teamOne: json['team_one']?.toString() ?? '',
      teamOne11: json['team_one_11']?.toString() ?? '',
      teamOneCap: json['team_one_cap']?.toString() ?? '',
      teamOneWktkpr: json['team_one_wktkpr']?.toString() ?? '',
      teamTwo: json['team_two']?.toString() ?? '',
      teamTwoCap: json['team_two_cap']?.toString() ?? '',
      teamTwoWktkpr: json['team_two_wktkpr']?.toString() ?? '',
      teamTwo11: json['team_two_11']?.toString() ?? '',
      venue: json['venue']?.toString() ?? 'Unknown Venue',
      matchDate: json['match_date']?.toString() ?? '',
      matchTime: json['match_time']?.toString() ?? '',
      ballType: json['ball_type']?.toString() ?? '',
      matchOvers: json['match_overs']?.toString() ?? '',
      ballersMaxOvers: json['ballers_max_overs']?.toString(),
      umpires: json['umpires']?.toString() ?? '',
      commentators: json['commentators']?.toString(),
      tossWin: json['toss_win']?.toString() ?? '',
      firstInning: json['first_inning']?.toString(),
      secondInning: json['second_inning']?.toString(),
      winningTeam: json['winning_team']?.toString() ?? '',
      isFirstInningClosed: json['is_first_inning_closed']?.toString() ?? '',
      losingTeam: json['losing_team']?.toString() ?? '',
      matchResult: json['match_result']?.toString() ?? 'Result unavailable',
      motm: json['motm']?.toString(),
      resultType: json['result_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      created: json['created']?.toString() ?? '',
      matchName: json['match_name']?.toString() ?? 'Unnamed Match',
      tossWinChooses: json['toss_win_chooses']?.toString() ?? '',
      notice: json['notice']?.toString() ?? '',
      youtube: json['youtube']?.toString(),
      ssmScorecard: json['ssm_scorecard']?.toString() ?? '',
      ssmBatter: json['ssm_batter']?.toString() ?? '',
      ssmBowler: json['ssm_bowler']?.toString() ?? '',
      ssmStatCom: json['ssm_stat_com']?.toString() ?? '',
      ssmColorTheme: json['ssm_color_theme']?.toString() ?? '',
    );
  }
}