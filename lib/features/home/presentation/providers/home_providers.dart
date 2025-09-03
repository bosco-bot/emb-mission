import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/content_local_data_source.dart';
import '../../data/datasources/content_remote_data_source.dart';
import '../../data/repositories/content_repository_impl.dart';
import '../../domain/entities/content_item_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/usecases/get_today_content_usecase.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour NetworkInfo
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl(InternetConnectionChecker());
});

/// Provider pour ContentRemoteDataSource
final contentRemoteDataSourceProvider = Provider<ContentRemoteDataSource>((ref) {
  return ContentRemoteDataSourceImpl();
});

/// Provider pour ContentLocalDataSource
final contentLocalDataSourceProvider = FutureProvider<ContentLocalDataSource>((ref) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  return ContentLocalDataSourceImpl(sharedPreferences: sharedPreferences);
});

/// Provider pour ContentRepository
final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final remoteDataSource = ref.watch(contentRemoteDataSourceProvider);
  final localDataSourceAsync = ref.watch(contentLocalDataSourceProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  
  // Nous ne pouvons pas utiliser directement le FutureProvider dans un Provider synchrone
  // Nous devons donc gérer le cas où les données ne sont pas encore disponibles
  if (localDataSourceAsync.hasValue) {
    final localDataSource = localDataSourceAsync.value!;
    return ContentRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
  } else {
    // Retourner une implémentation par défaut ou gérer l'erreur
    throw Exception('ContentLocalDataSource n\'est pas encore initialisé');
  }
});

/// Provider pour GetTodayContentUseCase
final getTodayContentUseCaseProvider = Provider<GetTodayContentUseCase>((ref) {
  final repository = ref.watch(contentRepositoryProvider);
  return GetTodayContentUseCase(repository);
});

/// Provider pour les contenus du jour
final todayContentProvider = FutureProvider<List<ContentItemEntity>>((ref) async {
  final useCase = ref.watch(getTodayContentUseCaseProvider);
  final result = await useCase(NoParams());
  
  return result.fold(
    (failure) => throw Exception('Erreur lors du chargement des contenus du jour'),
    (content) => content,
  );
});

/// Provider pour le statut du live
final liveStatusProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(contentRepositoryProvider);
  final result = await repository.getLiveStatus();
  
  return result.fold(
    (failure) => false,
    (isLive) => isLive,
  );
});
