// lib/model/team_model.dart

class TeamModel {
  final int teamId;
  final int tournamentId;
  final int fairplay;
  final int groupId;
  final String teamName;
  final String teamDescription;
  final String teamOrigin;
  final List<int> teamPlayers;
  final String teamLogo;
  final int status;
  final DateTime created;
  final int userId;

  TeamModel({
    required this.teamId,
    required this.tournamentId,
    required this.fairplay,
    required this.groupId,
    required this.teamName,
    required this.teamDescription,
    required this.teamOrigin,
    required this.teamPlayers,
    required this.teamLogo,
    required this.status,
    required this.created,
    required this.userId,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    // Parse the comma-separated players string into ints
    List<int> players = [];
    if (json['team_players'] != null &&
        (json['team_players'] as String).isNotEmpty) {
      players = (json['team_players'] as String)
          .split(',')
          .map((s) => int.tryParse(s) ?? 0)
          .where((id) => id != 0)
          .toList();
    }

    return TeamModel(
      teamId: json['team_id'] as int,
      tournamentId: (json['tournament_id'] as int?) ?? 0,
      fairplay: (json['fairplay'] as int?) ?? 0,
      groupId: (json['group_id'] as int?) ?? 0,
      teamName: (json['team_name'] as String?) ?? '',
      teamDescription: (json['team_description'] as String?) ?? '',
      teamOrigin: (json['team_origin']?.toString()) ?? '',
      teamPlayers: players,
      teamLogo: (json['team_logo'] as String?) ?? '',
      status: (json['status'] as int?) ?? 0,
      created: json['created'] != null
          ? DateTime.tryParse(json['created'] as String) ?? DateTime.now()
          : DateTime.now(),
      userId: (json['user_id'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'team_id': teamId,
    'tournament_id': tournamentId,
    'fairplay': fairplay,
    'group_id': groupId,
    'team_name': teamName,
    'team_description': teamDescription,
    'team_origin': teamOrigin,
    'team_players': teamPlayers.join(','),
    'team_logo': teamLogo,
    'status': status,
    'created': created.toIso8601String(),
    'user_id': userId,
  };
}
