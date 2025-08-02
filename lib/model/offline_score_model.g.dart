// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_score_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineScoreAdapter extends TypeAdapter<OfflineScore> {
  @override
  final int typeId = 0;

  @override
  OfflineScore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineScore(
      matchId: fields[0] as int,
      battingTeamId: fields[1] as int,
      onStrikePlayerId: fields[2] as int,
      onStrikeOrder: fields[3] as int,
      nonStrikePlayerId: fields[4] as int,
      nonStrikeOrder: fields[5] as int,
      bowlerId: fields[6] as int,
      overNumber: fields[7] as int,
      ballNumber: fields[8] as int,
      runs: fields[9] as int,
      extraRunType: fields[10] as String?,
      extraRun: fields[11] as int?,
      isWicket: fields[12] as bool,
      wicketType: fields[13] as String?,
      commentary: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineScore obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.battingTeamId)
      ..writeByte(2)
      ..write(obj.onStrikePlayerId)
      ..writeByte(3)
      ..write(obj.onStrikeOrder)
      ..writeByte(4)
      ..write(obj.nonStrikePlayerId)
      ..writeByte(5)
      ..write(obj.nonStrikeOrder)
      ..writeByte(6)
      ..write(obj.bowlerId)
      ..writeByte(7)
      ..write(obj.overNumber)
      ..writeByte(8)
      ..write(obj.ballNumber)
      ..writeByte(9)
      ..write(obj.runs)
      ..writeByte(10)
      ..write(obj.extraRunType)
      ..writeByte(11)
      ..write(obj.extraRun)
      ..writeByte(12)
      ..write(obj.isWicket)
      ..writeByte(13)
      ..write(obj.wicketType)
      ..writeByte(14)
      ..write(obj.commentary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineScoreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
