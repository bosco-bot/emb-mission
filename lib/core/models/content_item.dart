/// Modèle de base pour les éléments de contenu de l'application
class ContentItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final DateTime? date;
  final ContentType type;
  final bool isLive;
  final int? duration; // en minutes
  final int? viewCount;

  ContentItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.date,
    required this.type,
    this.isLive = false,
    this.duration,
    this.viewCount,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      imageUrl: json['imageUrl'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      type: ContentTypeExtension.fromString(json['type']),
      isLive: json['isLive'] ?? false,
      duration: json['duration'],
      viewCount: json['viewCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'date': date?.toIso8601String(),
      'type': type.toString().split('.').last,
      'isLive': isLive,
      'duration': duration,
      'viewCount': viewCount,
    };
  }
}

/// Types de contenu disponibles dans l'application
enum ContentType {
  audio,
  video,
  article,
  prayer,
  testimony,
  bibleStudy,
}

/// Extension pour faciliter la conversion entre string et enum ContentType
extension ContentTypeExtension on ContentType {
  static ContentType fromString(String value) {
    return ContentType.values.firstWhere(
      (type) => type.toString().split('.').last == value,
      orElse: () => ContentType.audio,
    );
  }
}
