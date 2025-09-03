import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/content_item_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/content_local_data_source.dart';
import '../datasources/content_remote_data_source.dart';

/// Implémentation du repository pour les contenus
class ContentRepositoryImpl implements ContentRepository {
  final ContentRemoteDataSource remoteDataSource;
  final ContentLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ContentRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ContentItemEntity>>> getTodayContent() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteContent = await remoteDataSource.getTodayContent();
        localDataSource.cacheTodayContent(remoteContent);
        return Right(remoteContent);
      } on ServerException {
        return const Left(ServerFailure());
      }
    } else {
      try {
        final localContent = await localDataSource.getCachedTodayContent();
        return Right(localContent);
      } on CacheException {
        return const Left(CacheFailure());
      }
    }
  }

  @override
  Future<Either<Failure, List<ContentItemEntity>>> getPopularContent() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteContent = await remoteDataSource.getPopularContent();
        localDataSource.cachePopularContent(remoteContent);
        return Right(remoteContent);
      } on ServerException {
        return const Left(ServerFailure());
      }
    } else {
      try {
        final localContent = await localDataSource.getCachedPopularContent();
        return Right(localContent);
      } on CacheException {
        return const Left(CacheFailure());
      }
    }
  }

  @override
  Future<Either<Failure, bool>> getLiveStatus() async {
    if (await networkInfo.isConnected) {
      try {
        final isLive = await remoteDataSource.getLiveStatus();
        localDataSource.cacheLiveStatus(isLive);
        return Right(isLive);
      } on ServerException {
        return const Left(ServerFailure());
      }
    } else {
      try {
        final isLive = await localDataSource.getCachedLiveStatus();
        return Right(isLive);
      } on CacheException {
        return const Left(CacheFailure());
      }
    }
  }
}
