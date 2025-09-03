// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalFavoriteAdapter extends TypeAdapter<LocalFavorite> {
  @override
  final int typeId = 0;

  @override
  LocalFavorite read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalFavorite(
      contentId: fields[0] as int,
      isFavorite: fields[1] as bool,
      updatedAt: fields[2] as DateTime,
      needsSync: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalFavorite obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.isFavorite)
      ..writeByte(2)
      ..write(obj.updatedAt)
      ..writeByte(3)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalFavoriteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalProgressAdapter extends TypeAdapter<LocalProgress> {
  @override
  final int typeId = 1;

  @override
  LocalProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalProgress(
      contentId: fields[0] as int,
      position: fields[1] as int,
      isCompleted: fields[2] as bool,
      updatedAt: fields[3] as DateTime,
      needsSync: fields[4] as bool,
      duration: fields[5] as int,
      title: fields[6] as String,
      author: fields[7] as String,
      fileUrl: fields[8] as String,
      category: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LocalProgress obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.position)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.needsSync)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.title)
      ..writeByte(7)
      ..write(obj.author)
      ..writeByte(8)
      ..write(obj.fileUrl)
      ..writeByte(9)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalCommentAdapter extends TypeAdapter<LocalComment> {
  @override
  final int typeId = 2;

  @override
  LocalComment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalComment(
      contentId: fields[0] as int,
      userId: fields[1] as String,
      text: fields[2] as String,
      createdAt: fields[3] as DateTime,
      needsSync: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalComment obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalCommentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
