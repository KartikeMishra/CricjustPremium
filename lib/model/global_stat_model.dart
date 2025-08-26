import 'dart:convert';

class GlobalStat {
  final String id;
  final String displayName;
  final String playerImage;
  final String? matchName;
  final String? strikeRate;
  final Map<String, dynamic> additionalStats;

  GlobalStat({
    required this.id,
    required this.displayName,
    this.playerImage = '',
    this.matchName,
    this.strikeRate,
    this.additionalStats = const {},
  });

  factory GlobalStat.fromJson(Map<String, dynamic> json) {
    final image = json['player_image'] ?? '';
    final match = json['Match_Name'] ?? '';
    final sr = json['sr'] ?? json['SR'];

    final id =
        json['batter_id'] ?? json['bowler_id'] ?? json['player_id'] ?? '';
    final name = json['display_Name'] ?? json['Display_Name'] ?? '';

    final additional = Map<String, dynamic>.from(json)
      ..removeWhere(
        (key, _) => [
          'batter_id',
          'bowler_id',
          'player_id',
          'display_Name',
          'Display_Name',
          'player_image',
          'Match_Name',
          'sr',
          'SR',
        ].contains(key),
      );

    return GlobalStat(
      id: id,
      displayName: name,
      playerImage: image,
      matchName: match,
      strikeRate: sr,
      additionalStats: additional,
    );
  }

  static List<GlobalStat> fromJsonList(String responseBody) {
    final Map<String, dynamic> parsed = json.decode(responseBody);
    final List<dynamic> data = parsed['data'] ?? [];
    return data.map((item) => GlobalStat.fromJson(item)).toList();
  }
}
