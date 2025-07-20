// lib/model/offline_score_model.dart

import 'package:hive/hive.dart';

part 'offline_score_model.g.dart'; // ✅ Correct

@HiveType(typeId: 0)
class OfflineScore extends HiveObject {
  @HiveField(0)
  int matchId;

  @HiveField(1)
  int battingTeamId;

  @HiveField(2)
  int onStrikePlayerId;

  @HiveField(3)
  int onStrikeOrder;

  @HiveField(4)
  int nonStrikePlayerId;

  @HiveField(5)
  int nonStrikeOrder;

  @HiveField(6)
  int bowlerId;

  @HiveField(7)
  int overNumber;

  @HiveField(8)
  int ballNumber;

  @HiveField(9)
  int runs;

  @HiveField(10)
  String? extraRunType;

  @HiveField(11)
  int? extraRun;

  @HiveField(12)
  bool isWicket;

  @HiveField(13)
  String? wicketType;

  @HiveField(14)
  String? commentary;

  OfflineScore({
    required this.matchId,
    required this.battingTeamId,
    required this.onStrikePlayerId,
    required this.onStrikeOrder,
    required this.nonStrikePlayerId,
    required this.nonStrikeOrder,
    required this.bowlerId,
    required this.overNumber,
    required this.ballNumber,
    required this.runs,
    this.extraRunType,
    this.extraRun,
    required this.isWicket,
    this.wicketType,
    this.commentary,
  });

  Map<String, dynamic> toJson(String token) {
    return {
      "api_logged_in_token": token,
      "match_id": matchId,
      "batting_team_id": battingTeamId,
      "on_strike_player_id": onStrikePlayerId,
      "on_strike_player_order": onStrikeOrder,
      "non_strike_player_id": nonStrikePlayerId,
      "non_strike_player_order": nonStrikeOrder,
      "bowler": bowlerId,
      "over_number": overNumber,
      "ball_number": ballNumber,
      "runs": runs,
      "extra_run_type": extraRunType,
      "extra_run": extraRun,
      "is_wicket": isWicket ? 1 : 0,
      "wicket_type": wicketType,
      "commentry": commentary,
    };
  }
}
