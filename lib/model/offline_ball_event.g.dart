// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_ball_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineBallEventAdapter extends TypeAdapter<OfflineBallEvent> {
  @override
  final int typeId = 1;

  @override
  OfflineBallEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineBallEvent(
      matchId: fields[0] as int,
      scorePayload: (fields[1] as Map).cast<String, dynamic>(),
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineBallEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.scorePayload)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineBallEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
