import 'package:hive/hive.dart';

part 'local_models.g.dart';

@HiveType(typeId: 0)
class LocalFavorite extends HiveObject {
  @HiveField(0)
  int contentId;
  @HiveField(1)
  bool isFavorite;
  @HiveField(2)
  DateTime updatedAt;
  @HiveField(3)
  bool needsSync;

  LocalFavorite({
    required this.contentId,
    required this.isFavorite,
    required this.updatedAt,
    this.needsSync = true,
  });
}

@HiveType(typeId: 1)
class LocalProgress extends HiveObject {
  @HiveField(0)
  int contentId;
  @HiveField(1)
  int position;
  @HiveField(2)
  bool isCompleted;
  @HiveField(3)
  DateTime updatedAt;
  @HiveField(4)
  bool needsSync;
  @HiveField(5)
  int duration; // durée totale en secondes
  @HiveField(6)
  String title;
  @HiveField(7)
  String author;
  @HiveField(8)
  String fileUrl;
  @HiveField(9)
  String category;

  LocalProgress({
    required this.contentId,
    required this.position,
    this.isCompleted = false,
    required this.updatedAt,
    this.needsSync = true,
    required this.duration,
    required this.title,
    required this.author,
    required this.fileUrl,
    required this.category,
  });
}

@HiveType(typeId: 2)
class LocalComment extends HiveObject {
  @HiveField(0)
  int contentId;
  @HiveField(1)
  String userId;
  @HiveField(2)
  String text;
  @HiveField(3)
  DateTime createdAt;
  @HiveField(4)
  bool needsSync;

  LocalComment({
    required this.contentId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.needsSync = true,
  });
} 