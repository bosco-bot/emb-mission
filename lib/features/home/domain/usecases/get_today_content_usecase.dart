import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/content_item_entity.dart';
import '../repositories/content_repository.dart';

/// Cas d'utilisation pour récupérer les contenus du jour
class GetTodayContentUseCase implements UseCase<List<ContentItemEntity>, NoParams> {
  final ContentRepository repository;

  GetTodayContentUseCase(this.repository);

  @override
  Future<Either<Failure, List<ContentItemEntity>>> call(NoParams params) {
    return repository.getTodayContent();
  }
}
