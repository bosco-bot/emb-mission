import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/exceptions.dart';
import '../models/content_item_model.dart';

/// Clés pour le stockage local
const String CACHED_TODAY_CONTENT = 'CACHED_TODAY_CONTENT';
const String CACHED_POPULAR_CONTENT = 'CACHED_POPULAR_CONTENT';
const String CACHED_LIVE_STATUS = 'CACHED_LIVE_STATUS';

/// Interface pour la source de données locale des contenus
abstract class ContentLocalDataSource {
  /// Récupère les contenus du jour depuis le cache
  Future<List<ContentItemModel>> getCachedTodayContent();
  
  /// Récupère les contenus populaires depuis le cache
  Future<List<ContentItemModel>> getCachedPopularContent();
  
  /// Récupère le statut du live depuis le cache
  Future<bool> getCachedLiveStatus();
  
  /// Cache les contenus du jour
  Future<void> cacheTodayContent(List<ContentItemModel> contentToCache);
  
  /// Cache les contenus populaires
  Future<void> cachePopularContent(List<ContentItemModel> contentToCache);
  
  /// Cache le statut du live
  Future<void> cacheLiveStatus(bool isLive);
}

/// Implémentation de la source de données locale des contenus
class ContentLocalDataSourceImpl implements ContentLocalDataSource {
  final SharedPreferences sharedPreferences;
  
  ContentLocalDataSourceImpl({required this.sharedPreferences});
  
  @override
  Future<List<ContentItemModel>> getCachedTodayContent() async {
    final jsonString = sharedPreferences.getString(CACHED_TODAY_CONTENT);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) => ContentItemModel.fromJson(item))
          .toList();
    } else {
      throw CacheException();
    }
  }
  
  @override
  Future<List<ContentItemModel>> getCachedPopularContent() async {
    final jsonString = sharedPreferences.getString(CACHED_POPULAR_CONTENT);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) => ContentItemModel.fromJson(item))
          .toList();
    } else {
      throw CacheException();
    }
  }
  
  @override
  Future<bool> getCachedLiveStatus() async {
    final isLive = sharedPreferences.getBool(CACHED_LIVE_STATUS);
    if (isLive != null) {
      return isLive;
    } else {
      throw CacheException();
    }
  }
  
  @override
  Future<void> cacheTodayContent(List<ContentItemModel> contentToCache) {
    final List<Map<String, dynamic>> jsonList = 
        contentToCache.map((content) => content.toJson()).toList();
    return sharedPreferences.setString(
      CACHED_TODAY_CONTENT,
      json.encode(jsonList),
    );
  }
  
  @override
  Future<void> cachePopularContent(List<ContentItemModel> contentToCache) {
    final List<Map<String, dynamic>> jsonList = 
        contentToCache.map((content) => content.toJson()).toList();
    return sharedPreferences.setString(
      CACHED_POPULAR_CONTENT,
      json.encode(jsonList),
    );
  }
  
  @override
  Future<void> cacheLiveStatus(bool isLive) {
    return sharedPreferences.setBool(CACHED_LIVE_STATUS, isLive);
  }
}
