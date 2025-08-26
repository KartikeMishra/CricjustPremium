class TournamentModel {
  final int tournamentId;
  final String tournamentName;
  final String tournamentLogo;
  final String tournamentDesc;
  final String startDate;
  final String created;
  final int teams;
  final bool isGroup;
  final bool isOpen;
  final dynamic winner;
  final int? userId; // ✅ Already declared

  TournamentModel({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentLogo,
    required this.tournamentDesc,
    required this.startDate,
    required this.created,
    this.teams = 0,
    this.isGroup = false,
    this.isOpen = false,
    this.winner,
    this.userId, // ✅ ADD THIS LINE
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      tournamentId: int.tryParse(json['tournament_id']?.toString() ?? '') ?? 0,
      tournamentName: json['tournament_name'] ?? '',
      tournamentLogo: json['tournament_logo'] ?? '',
      tournamentDesc: json['tournament_desc'] ?? '',
      startDate: json['start_date'] ?? '',
      created: json['created'] ?? '',
      teams: int.tryParse(json['teams']?.toString() ?? '') ?? 0,
      isGroup: json['is_group'].toString() == '1',
      isOpen: json['is_open'].toString() == '1',
      winner: json['winner'],
      userId: json['user_id'] != null
          ? int.tryParse(json['user_id'].toString())
          : null,
    );
  }
}
