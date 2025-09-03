import '../../domain/entities/content_item_entity.dart';

/// Modèle de données pour un élément de contenu
class ContentItemModel extends ContentItemEntity {
  const ContentItemModel({
    required super.id,
    required super.title,
    super.description,
    super.imageUrl,
    super.audioUrl,
    super.videoUrl,
    super.date,
    super.isLive,
    super.category,
  });

  /// Crée un modèle à partir d'un JSON
  factory ContentItemModel.fromJson(Map<String, dynamic> json) {
    return ContentItemModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      videoUrl: json['videoUrl'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      isLive: json['isLive'] ?? false,
      category: json['category'],
    );
  }

  /// Convertit le modèle en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'videoUrl': videoUrl,
      'date': date?.toIso8601String(),
      'isLive': isLive,
      'category': category,
    };
  }
}
