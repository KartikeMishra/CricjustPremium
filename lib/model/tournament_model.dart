class TournamentModel {
  final int tournamentId;
  final String tournamentName;
  final String tournamentLogo;
  final String tournamentDesc;
  final String startDate;
  final String created;
  final int teams;

  TournamentModel({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentLogo,
    required this.tournamentDesc,
    required this.startDate,
    required this.created,
    required this.teams,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      tournamentId: json['tournament_id'] ?? 0,
      tournamentName: json['tournament_name'] ?? '',
      tournamentLogo: json['tournament_logo'] ?? '',
      tournamentDesc: json['tournament_desc'] ?? '',
      startDate: json['start_date'] ?? '',
      created: json['created'] ?? '',
      teams: int.tryParse(json['teams'].toString()) ?? 0,
    );
  }
}
