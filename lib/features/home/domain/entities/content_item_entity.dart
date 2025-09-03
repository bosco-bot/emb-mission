import 'package:equatable/equatable.dart';

/// Entity représentant un élément de contenu dans l'application
class ContentItemEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? audioUrl;
  final String? videoUrl;
  final DateTime? date;
  final bool isLive;
  final String? category;

  const ContentItemEntity({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.audioUrl,
    this.videoUrl,
    this.date,
    this.isLive = false,
    this.category,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        imageUrl,
        audioUrl,
        videoUrl,
        date,
        isLive,
        category,
      ];
}
