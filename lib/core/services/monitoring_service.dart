import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service centralisé pour le monitoring Firebase
/// ✅ SÉCURISÉ : Gestion d'erreur robuste, pas d'impact sur l'app
class MonitoringService {
  static bool _isInitialized = false;
  static bool _isEnabled = true;
  
  /// Initialisation du service
  static Future<void> initialize() async {
    try {
      _isInitialized = true;
      print('✅ MonitoringService initialisé');
    } catch (e) {
      print('❌ Erreur initialisation MonitoringService: $e');
      _isEnabled = false;
    }
  }
  
  /// Vérifier si le monitoring est disponible
  static bool get isAvailable => _isInitialized && _isEnabled;
  
  /// ✅ Événements Analytics sécurisés
  static Future<void> logEvent(String eventName, Map<String, Object>? parameters) async {
    if (!isAvailable) {
      print('⚠️ Monitoring non disponible, événement ignoré: $eventName');
      return;
    }
    
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: eventName,
        parameters: parameters,
      );
      print('📊 Analytics: Événement enregistré: $eventName');
    } catch (e) {
      print('❌ Erreur Analytics: $e');
      // ✅ Pas d'impact sur l'app
    }
  }
  
  /// ✅ Métriques de performance sécurisées
  static Future<void> logPerformanceMetric(String metricName, int value) async {
    if (!isAvailable) return;
    
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'performance_metric',
        parameters: {
          'metric_name': metricName,
          'value': value,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      print('❌ Erreur métrique performance: $e');
    }
  }
  
  /// ✅ Gestion des erreurs sécurisée
  static Future<void> logError(dynamic error, StackTrace? stackTrace, {bool fatal = false}) async {
    if (!isAvailable) return;
    
    try {
      await FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: fatal);
      print('🐛 Crashlytics: Erreur enregistrée (fatal: $fatal)');
    } catch (e) {
      print('❌ Erreur Crashlytics: $e');
    }
  }
  
  /// ✅ Événements utilisateur sécurisés
  static Future<void> logUserAction(String action, Map<String, dynamic>? context) async {
    if (!isAvailable) return;
    
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'user_action',
        parameters: {
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
          ...?context,
        },
      );
    } catch (e) {
      print('❌ Erreur événement utilisateur: $e');
    }
  }
  
  /// ✅ Événements de contenu sécurisés
  static Future<void> logContentView(String contentType, String contentId, {String? title}) async {
    if (!isAvailable) return;
    
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'content_view',
        parameters: {
          'content_type': contentType,
          'content_id': contentId,
          'title': title ?? 'Unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Erreur événement contenu: $e');
    }
  }
  
  /// ✅ Événements de session sécurisés
  static Future<void> logSessionStart() async {
    if (!isAvailable) return;
    
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'app_session_start', // ✅ Changé de 'session_start' (réservé) à 'app_session_start'
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'app_version': '1.0.0', // À récupérer dynamiquement
        },
      );
    } catch (e) {
      print('❌ Erreur événement session: $e');
    }
  }
  
  /// ✅ Événements de session sécurisés
  static Future<void> logSessionEnd(int durationSeconds) async {
    if (!isAvailable) return;
    
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'app_session_end', // ✅ Changé de 'session_end' (réservé) à 'app_session_end'
        parameters: {
          'duration_seconds': durationSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Erreur événement session: $e');
    }
  }
}
