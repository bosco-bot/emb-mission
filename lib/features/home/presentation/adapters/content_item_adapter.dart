import '../../../../core/models/content_item.dart';
import '../../domain/entities/content_item_entity.dart';

/// Adaptateur pour convertir ContentItemEntity en ContentItem
class ContentItemAdapter {
  /// Convertit une entité ContentItemEntity en modèle ContentItem
  static ContentItem fromEntity(ContentItemEntity entity) {
    // Déterminer le type de contenu en fonction de la catégorie
    ContentType contentType = _mapCategoryToContentType(entity.category);
    
    return ContentItem(
      id: entity.id,
      title: entity.title,
      subtitle: entity.description,
      imageUrl: entity.imageUrl,
      date: entity.date,
      isLive: entity.isLive,
      type: contentType,
    );
  }

  /// Convertit une liste d'entités ContentItemEntity en liste de modèles ContentItem
  static List<ContentItem> fromEntityList(List<ContentItemEntity> entities) {
    return entities.map((entity) => fromEntity(entity)).toList();
  }
  
  /// Convertit une catégorie en ContentType
  static ContentType _mapCategoryToContentType(String? category) {
    switch (category?.toLowerCase()) {
      case 'prayer':
        return ContentType.prayer;
      case 'testimony':
        return ContentType.testimony;
      case 'bible':
      case 'biblestudy':
        return ContentType.bibleStudy;
      case 'audio':
        return ContentType.audio;
      case 'video':
        return ContentType.video;
      default:
        return ContentType.article;
    }
  }
}
