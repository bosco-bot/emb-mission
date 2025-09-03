import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:emb_mission/core/config/app_config.dart';

/// Service pour la collecte de données d'utilisation avec Firebase Analytics
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  /// Initialise le service Analytics
  static Future<void> initialize() async {
    try {
      if (AppConfig.shouldEnableFirebaseAnalytics) {
        AppConfig.logSuccess('AnalyticsService initialisé', tag: 'ANALYTICS');
      } else {
        AppConfig.logWarning('AnalyticsService désactivé (mode développement)', tag: 'ANALYTICS');
      }
    } catch (e) {
      AppConfig.logError('Erreur initialisation AnalyticsService', tag: 'ANALYTICS', error: e);
    }
  }
  
  /// Enregistre un événement personnalisé
  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!AppConfig.shouldEnableFirebaseAnalytics) {
      AppConfig.log('Événement Analytics ignoré (mode développement): $name', tag: 'ANALYTICS');
      return;
    }
    
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      AppConfig.logSuccess('Événement Analytics enregistré: $name', tag: 'ANALYTICS');
    } catch (e) {
      AppConfig.logError('Erreur enregistrement événement Analytics: $name', tag: 'ANALYTICS', error: e);
    }
  }
  
  /// Enregistre l'ouverture de l'application
  static Future<void> logAppOpen() async {
    await logEvent('app_open', parameters: {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la navigation vers une page
  static Future<void> logPageView(String pageName) async {
    await logEvent('page_view', parameters: {
      'page_name': pageName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre le démarrage de la radio
  static Future<void> logRadioStart(String radioName, String radioUrl) async {
    await logEvent('radio_start', parameters: {
      'radio_name': radioName,
      'radio_url': radioUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre l'arrêt de la radio
  static Future<void> logRadioStop(String radioName) async {
    await logEvent('radio_stop', parameters: {
      'radio_name': radioName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la lecture d'un contenu
  static Future<void> logContentPlay(String contentId, String contentType) async {
    await logEvent('content_play', parameters: {
      'content_id': contentId,
      'content_type': contentType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre l'ajout d'un favori
  static Future<void> logFavoriteAdd(String contentId, String contentType) async {
    await logEvent('favorite_add', parameters: {
      'content_id': contentId,
      'content_type': contentType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la suppression d'un favori
  static Future<void> logFavoriteRemove(String contentId, String contentType) async {
    await logEvent('favorite_remove', parameters: {
      'content_id': contentId,
      'content_type': contentType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre l'envoi d'un commentaire
  static Future<void> logCommentSend(String contentId) async {
    await logEvent('comment_send', parameters: {
      'content_id': contentId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la connexion d'un utilisateur
  static Future<void> logUserLogin(String userId) async {
    await logEvent('user_login', parameters: {
      'user_id': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la déconnexion d'un utilisateur
  static Future<void> logUserLogout(String userId) async {
    await logEvent('user_logout', parameters: {
      'user_id': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre une erreur
  static Future<void> logError(String errorType, String errorMessage) async {
    await logEvent('error_occurred', parameters: {
      'error_type': errorType,
      'error_message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre l'utilisation d'une fonctionnalité
  static Future<void> logFeatureUsage(String featureName) async {
    await logEvent('feature_usage', parameters: {
      'feature_name': featureName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre le temps passé sur une page
  static Future<void> logTimeSpent(String pageName, int secondsSpent) async {
    await logEvent('time_spent', parameters: {
      'page_name': pageName,
      'seconds_spent': secondsSpent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la recherche
  static Future<void> logSearch(String searchQuery, int resultsCount) async {
    await logEvent('search', parameters: {
      'search_query': searchQuery,
      'results_count': resultsCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre le partage de contenu
  static Future<void> logShare(String contentId, String contentType, String shareMethod) async {
    await logEvent('share', parameters: {
      'content_id': contentId,
      'content_type': contentType,
      'share_method': shareMethod,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la notification reçue
  static Future<void> logNotificationReceived(String notificationType) async {
    await logEvent('notification_received', parameters: {
      'notification_type': notificationType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la notification cliquée
  static Future<void> logNotificationClicked(String notificationType) async {
    await logEvent('notification_clicked', parameters: {
      'notification_type': notificationType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la mise à jour de l'application
  static Future<void> logAppUpdate(String oldVersion, String newVersion) async {
    await logEvent('app_update', parameters: {
      'old_version': oldVersion,
      'new_version': newVersion,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre la première ouverture de l'application
  static Future<void> logFirstOpen() async {
    await logEvent('first_open', parameters: {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre l'achat d'un contenu premium
  static Future<void> logPurchase(String contentId, double price, String currency) async {
    await logEvent('purchase', parameters: {
      'content_id': contentId,
      'price': price,
      'currency': currency,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Enregistre l'abonnement
  static Future<void> logSubscription(String subscriptionType, double price, String currency) async {
    await logEvent('subscription', parameters: {
      'subscription_type': subscriptionType,
      'price': price,
      'currency': currency,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
