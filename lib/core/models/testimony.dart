/// Catégories de témoignages disponibles
enum TestimonyCategory {
  healing,
  prayer,
  family,
  work,
}

/// Extension pour faciliter la conversion entre string et enum TestimonyCategory
extension TestimonyCategoryExtension on TestimonyCategory {
  String get displayName {
    switch (this) {
      case TestimonyCategory.healing:
        return 'Guérison';
      case TestimonyCategory.prayer:
        return 'Prière';
      case TestimonyCategory.family:
        return 'Famille';
      case TestimonyCategory.work:
        return 'Travail';
    }
  }

  static TestimonyCategory fromString(String value) {
    return TestimonyCategory.values.firstWhere(
      (category) => category.toString().split('.').last == value,
      orElse: () => TestimonyCategory.prayer,
    );
  }
}

/// Mode de saisie pour les témoignages
enum InputMode {
  text,
  audio,
}

/// Modèle pour les témoignages
class Testimony {
  final String id;
  final String authorName;
  final String? authorImageUrl;
  final TestimonyCategory category;
  final String content;
  final DateTime createdAt;
  final InputMode inputMode;
  final String? audioUrl;
  final int? duration; // en secondes pour l'audio
  final int likeCount;
  final bool isLiked;

  Testimony({
    required this.id,
    required this.authorName,
    this.authorImageUrl,
    required this.category,
    required this.content,
    required this.createdAt,
    required this.inputMode,
    this.audioUrl,
    this.duration,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: json['id'],
      authorName: json['authorName'],
      authorImageUrl: json['authorImageUrl'],
      category: TestimonyCategoryExtension.fromString(json['category']),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      inputMode: json['inputMode'] == 'audio' ? InputMode.audio : InputMode.text,
      audioUrl: json['audioUrl'],
      duration: json['duration'],
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'authorImageUrl': authorImageUrl,
      'category': category.toString().split('.').last,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'inputMode': inputMode == InputMode.audio ? 'audio' : 'text',
      'audioUrl': audioUrl,
      'duration': duration,
      'likeCount': likeCount,
      'isLiked': isLiked,
    };
  }

  Testimony copyWith({
    String? id,
    String? authorName,
    String? authorImageUrl,
    TestimonyCategory? category,
    String? content,
    DateTime? createdAt,
    InputMode? inputMode,
    String? audioUrl,
    int? duration,
    int? likeCount,
    bool? isLiked,
  }) {
    return Testimony(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      category: category ?? this.category,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      inputMode: inputMode ?? this.inputMode,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
