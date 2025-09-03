import 'package:dartz/dartz.dart';
import '../entities/content_item_entity.dart';
import '../../../../core/error/failures.dart';

/// Interface définissant les méthodes pour accéder aux contenus
abstract class ContentRepository {
  /// Récupère les contenus du jour
  Future<Either<Failure, List<ContentItemEntity>>> getTodayContent();
  
  /// Récupère les contenus populaires
  Future<Either<Failure, List<ContentItemEntity>>> getPopularContent();
  
  /// Récupère le statut du live
  Future<Either<Failure, bool>> getLiveStatus();
}
