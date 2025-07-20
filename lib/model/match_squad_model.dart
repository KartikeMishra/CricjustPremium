class Player {
  final int userId;
  final String name;
  final String playerImage;
  final String playerType;

  Player({
    required this.userId,
    required this.name,
    required this.playerImage,
    required this.playerType,
  });

  int get playerId => userId;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      playerImage: (json['player_image'] ?? '').toString().replaceAll(
        '&amp;',
        '&',
      ),
      playerType: json['player_type'] ?? '',
    );
  }
}

class MatchSquad {
  final String team1Name;
  final String team1Logo;
  final String team2Name;
  final String team2Logo;
  final List<Player> team1Players;
  final List<Player> team2Players;

  MatchSquad({
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
    required this.team1Players,
    required this.team2Players,
  });

  factory MatchSquad.fromJson(Map<String, dynamic> json) {
    final matchList = json['data'] ?? [];
    final match = matchList.isNotEmpty ? matchList[0] ?? {} : {};
    final squad = json['squad'] ?? {};

    final team1 = match['team_1'] ?? {};
    final team2 = match['team_2'] ?? {};

    final team1Players = List<Player>.from(
      (squad['team_1'] ?? []).map((p) => Player.fromJson(p)),
    );

    final team2Players = List<Player>.from(
      (squad['team_2'] ?? []).map((p) => Player.fromJson(p)),
    );

    return MatchSquad(
      team1Name: team1['team_name'] ?? 'Team 1',
      team1Logo: (team1['team_logo'] ?? '').toString().replaceAll('&amp;', '&'),
      team2Name: team2['team_name'] ?? 'Team 2',
      team2Logo: (team2['team_logo'] ?? '').toString().replaceAll('&amp;', '&'),
      team1Players: team1Players,
      team2Players: team2Players,
    );
  }
}

class TournamentStats {
  final Map<String, dynamic>? mostRuns;
  final Map<String, dynamic>? mostWickets;
  final Map<String, dynamic>? mostSixes;
  final Map<String, dynamic>? mostFours;
  final Map<String, dynamic>? mvp;
  final Map<String, dynamic>? highestScores;

  TournamentStats({
    this.mostRuns,
    this.mostWickets,
    this.mostSixes,
    this.mostFours,
    this.mvp,
    this.highestScores,
  });

  factory TournamentStats.fromJson(Map<String, dynamic> json) {
    return TournamentStats(
      mostRuns: json['most_runs'],
      mostWickets: json['most_wickets'],
      mostSixes: json['most_sixes'],
      mostFours: json['most_fours'],
      mvp: json['mvp'],
      highestScores: json['highest_scores'],
    );
  }
}
