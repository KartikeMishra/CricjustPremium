import 'package:hive/hive.dart';

part 'offline_ball_event.g.dart';

@HiveType(typeId: 1)
class OfflineBallEvent extends HiveObject {
  @HiveField(0)
  final int matchId;

  @HiveField(1)
  final Map<String, dynamic> scorePayload;

  @HiveField(2)
  final DateTime timestamp;

  OfflineBallEvent({
    required this.matchId,
    required this.scorePayload,
    required this.timestamp,
  });
}
