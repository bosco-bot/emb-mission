import 'package:flutter/foundation.dart';

/// Configuration de l'application selon l'environnement
class AppConfig {
  /// Détermine si l'application est en mode production
  static bool get isProduction => kReleaseMode;
  
  /// Détermine si l'application est en mode développement
  static bool get isDevelopment => kDebugMode;
  
  /// Détermine si Firebase Analytics doit être activé
  static bool get shouldEnableFirebaseAnalytics => isProduction;
  
  /// Détermine si Firebase Crashlytics doit être activé
  static bool get shouldEnableFirebaseCrashlytics => true; // Toujours utile
  
  /// Détermine si les logs de debug doivent être affichés
  static bool get shouldShowDebugLogs => isDevelopment;
  
  /// Détermine si les services de monitoring doivent être activés
  static bool get shouldEnableMonitoring => isProduction;
  
  /// Configuration des timeouts selon l'environnement
  static Duration get networkTimeout => isProduction 
    ? const Duration(seconds: 30) 
    : const Duration(seconds: 10);
  
  /// Configuration des retry selon l'environnement
  static int get maxRetryAttempts => isProduction ? 3 : 1;
  
  /// URL de base de l'API selon l'environnement
  static String get baseApiUrl => isProduction 
    ? 'https://embmission.com/mobileappebm/api'
    : 'https://embmission.com/mobileappebm/api'; // Même URL pour les deux
  
  /// Configuration des logs
  static void log(String message, {String? tag}) {
    if (shouldShowDebugLogs) {
      final timestamp = DateTime.now().toIso8601String();
      final logTag = tag != null ? '[$tag]' : '';
      print('$timestamp $logTag $message');
    }
  }
  
  /// Configuration des logs d'erreur
  static void logError(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag != null ? '[$tag]' : '';
    print('$timestamp $logTag ❌ $message');
    
    if (error != null) {
      print('$timestamp $logTag ❌ Erreur: $error');
    }
    
    if (stackTrace != null && shouldShowDebugLogs) {
      print('$timestamp $logTag ❌ Stack trace: $stackTrace');
    }
  }
  
  /// Configuration des logs de succès
  static void logSuccess(String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag != null ? '[$tag]' : '';
    print('$timestamp $logTag ✅ $message');
  }
  
  /// Configuration des logs d'information
  static void logInfo(String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag != null ? '[$tag]' : '';
    print('$timestamp $logTag ℹ️ $message');
  }
  
  /// Configuration des logs d'avertissement
  static void logWarning(String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag != null ? '[$tag]' : '';
    print('$timestamp $logTag ⚠️ $message');
  }
}
