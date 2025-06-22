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

  int get playerId => userId; // 🔥 For consistent access in UI

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      userId: json['user_id'],
      name: json['name'],
      playerImage: json['player_image'].replaceAll('&amp;', '&'),
      playerType: json['player_type'],
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
    final match = json['data'][0];
    final squad = json['squad'];

    return MatchSquad(
      team1Name: match['team_1']['team_name'],
      team1Logo: match['team_1']['team_logo'],
      team2Name: match['team_2']['team_name'],
      team2Logo: match['team_2']['team_logo'],
      team1Players: List<Player>.from(squad['team_1'].map((p) => Player.fromJson(p))),
      team2Players: List<Player>.from(squad['team_2'].map((p) => Player.fromJson(p))),
    );
  }
}
