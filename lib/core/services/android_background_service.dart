import 'package:flutter/services.dart';
import 'dart:async';

/// Service pour démarrer et gérer le service Android natif
class AndroidBackgroundService {
  static const MethodChannel _channel = MethodChannel('com.embmission.android_background');
  
  static final AndroidBackgroundService _instance = AndroidBackgroundService._internal();
  factory AndroidBackgroundService() => _instance;
  AndroidBackgroundService._internal();
  
  static bool _isActive = false;
  static Timer? _keepAliveTimer;
  
  // ✅ NOUVEAU: Système de vérification et correction automatique
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  
  /// ✅ NOUVEAU: Méthode robuste avec vérification et retry automatique
  static Future<bool> _invokeMethodWithRetry(String method, [dynamic arguments]) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < _maxRetries) {
      try {
        attempts++;
        print('🔧 [AndroidBackgroundService] Tentative $attempts/$_maxRetries: $method');
        
        final result = await _channel.invokeMethod(method, arguments);
        print('🔧 [AndroidBackgroundService] ✅ Succès: $method - Résultat: $result');
        return true;
        
      } catch (e) {
        lastError = e as Exception;
        print('🔧 [AndroidBackgroundService] ❌ Tentative $attempts échouée: $method - Erreur: $e');
        
        if (attempts < _maxRetries) {
          print('🔧 [AndroidBackgroundService] ⏳ Nouvelle tentative dans ${_retryDelay.inMilliseconds}ms...');
          await Future.delayed(_retryDelay);
        }
      }
    }
    
    print('🔧 [AndroidBackgroundService] ❌ ÉCHEC FINAL après $_maxRetries tentatives: $method');
    print('🔧 [AndroidBackgroundService] ❌ Dernière erreur: $lastError');
    return false;
  }
  
  /// ✅ NOUVEAU: Vérification de l'état du service Android
  static Future<bool> _verifyServiceState() async {
    try {
      print('🔧 [AndroidBackgroundService] 🔍 Verification de l\'etat du service Android...');
      
      // Essayer d'appeler une méthode simple pour vérifier la communication
      final result = await _channel.invokeMethod('keepServiceAlive');
      print('🔧 [AndroidBackgroundService] ✅ Communication OK: $result');
      return true;
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Communication echouee: $e');
      return false;
    }
  }
  
  /// ✅ NOUVEAU: Synchronisation complète avec vérification
  static Future<bool> _forceCompleteSync() async {
    try {
      print('🔧 [AndroidBackgroundService] 🔄 Synchronisation complète...');
      
      // 1. Vérifier la communication
      if (!await _verifyServiceState()) {
        print('🔧 [AndroidBackgroundService] ❌ Communication échouée - Impossible de synchroniser');
        return false;
      }
      
      // 2. Forcer la synchronisation côté Android
      final result = await _invokeMethodWithRetry('forceCompleteSync');
      if (result) {
        print('🔧 [AndroidBackgroundService] ✅ Synchronisation complète réussie');
        return true;
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Synchronisation complète échouée');
        return false;
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors de la synchronisation complète: $e');
      return false;
    }
  }
  
  /// ✅ NOUVEAU: Démarrage silencieux du service Android (pour maintenance)
  static Future<void> startNativeServiceSilent() async {
    if (_isActive) return;
    
    try {
      print('🔧 [AndroidBackgroundService] Démarrage silencieux du service Android natif...');
      
      // ✅ Utiliser startRadioBackgroundServiceSilent pour éviter la notification
      final success = await _invokeMethodWithRetry('startRadioBackgroundServiceSilent');
      
      if (success) {
        _isActive = true;
        print('🔧 [AndroidBackgroundService] ✅ Service Android natif démarré silencieusement');
        _startKeepAliveTimer();
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Échec du démarrage silencieux après retry - Fallback...');
        await _startServiceViaIntentSilent();
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors du démarrage silencieux: $e');
      // Fallback vers Intent silencieux
      try {
        await _startServiceViaIntentSilent();
      } catch (fallbackError) {
        print('🔧 [AndroidBackgroundService] ❌ Erreur critique du fallback silencieux: $fallbackError');
      }
    }
  }
  
  /// ✅ AMÉLIORÉ: Démarrage robuste du service Android
  static Future<void> startNativeService() async {
    if (_isActive) return;
    
    try {
      print('🔧 [AndroidBackgroundService] Démarrage du service Android natif...');
      
      // ✅ CORRECTION: Utiliser startRadioBackgroundService pour avoir la notification
      final success = await _invokeMethodWithRetry('startRadioBackgroundService');
      
      if (success) {
        _isActive = true;
        print('🔧 [AndroidBackgroundService] ✅ Service Android natif démarré avec succès (avec notification)');
        _startKeepAliveTimer();
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Échec du démarrage après retry - Fallback...');
        await _startServiceViaIntent();
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur critique lors du démarrage: $e');
      await _startServiceViaIntent();
    }
  }
  
  /// ✅ AMÉLIORÉ: Arrêt robuste du service Android
  static Future<void> stopNativeService() async {
    try {
      print('🔧 [AndroidBackgroundService] Arrêt du service Android natif...');
      
      // Utiliser la méthode robuste avec retry
      final success = await _invokeMethodWithRetry('stopRadioBackgroundService');
      
      if (success) {
        _isActive = false;
        print('🔧 [AndroidBackgroundService] ✅ Service Android natif arrêté avec succès');
        _stopKeepAliveTimer();
      } else {
        print('🔧 [AndroidBackgroundService] ⚠️ Échec de l\'arrêt après retry - Service peut rester actif');
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors de l\'arrêt: $e');
    }
  }
  
  /// ✅ AMÉLIORÉ: Affichage robuste de la notification
  static Future<void> showNotification() async {
    try {
      print('🔧 [AndroidBackgroundService] Affichage de la notification...');
      
      // Utiliser la méthode robuste avec retry
      final success = await _invokeMethodWithRetry('showNotification');
      
      if (success) {
        print('🔧 [AndroidBackgroundService] ✅ Notification affichée avec succès');
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Échec de l\'affichage après retry');
        // Essayer la synchronisation complète
        await _forceCompleteSync();
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors de l\'affichage: $e');
    }
  }
  
  /// ✅ AMÉLIORÉ: Masquage robuste de la notification
  static Future<void> hideNotification() async {
    try {
      print('🔧 [AndroidBackgroundService] Masquage de la notification...');
      
      // Utiliser la méthode robuste avec retry
      final success = await _invokeMethodWithRetry('hideNotification');
      
      if (success) {
        print('🔧 [AndroidBackgroundService] ✅ Notification masquée avec succès');
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Échec du masquage après retry');
        // Essayer la synchronisation complète
        await _forceCompleteSync();
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors du masquage: $e');
    }
  }
  
  /// ✅ AMÉLIORÉ: Mise à jour robuste de l'état radio
  static Future<void> updateRadioState(bool isPlaying) async {
    try {
      print('🔧 [AndroidBackgroundService] Mise à jour de l\'état radio: $isPlaying');
      
      // Utiliser la méthode robuste avec retry
      final success = await _invokeMethodWithRetry('updateRadioState', isPlaying);
      
      if (success) {
        print('🔧 [AndroidBackgroundService] ✅ État radio mis à jour avec succès: $isPlaying');
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Échec de la mise à jour après retry');
        // Essayer la synchronisation complète
        await _forceCompleteSync();
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors de la mise à jour: $e');
    }
  }
  
  /// ✅ AMÉLIORÉ: Forçage robuste de l'affichage de la notification
  static Future<void> forceShowNotification() async {
    try {
      print('🔧 [AndroidBackgroundService] Forçage de l\'affichage de la notification...');
      
      // Utiliser la méthode robuste avec retry
      final success = await _invokeMethodWithRetry('forceShowNotification');
      
      if (success) {
        print('🔧 [AndroidBackgroundService] ✅ Notification forcée avec succès');
      } else {
        print('🔧 [AndroidBackgroundService] ❌ Échec du forçage après retry');
        // Essayer la synchronisation complète
        await _forceCompleteSync();
      }
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors du forçage: $e');
    }
  }
  
  /// ✅ NOUVEAU: Synchronisation complète accessible publiquement
  static Future<void> forceCompleteSync() async {
    await _forceCompleteSync();
  }
  
  /// ✅ NOUVEAU: Démarrage silencieux via Intent (fallback)
  static Future<void> _startServiceViaIntentSilent() async {
    try {
      print('🔧 [AndroidBackgroundService] Démarrage silencieux via Intent...');
      
      const channel = MethodChannel('com.embmission.android_background');
      await channel.invokeMethod('startServiceViaIntentSilent');
      
      _isActive = true;
      print('🔧 [AndroidBackgroundService] ✅ Service démarré silencieusement via Intent');
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur démarrage silencieux via Intent: $e');
      rethrow;
    }
  }
  
  /// Démarrer le service via Intent (fallback)
  static Future<void> _startServiceViaIntent() async {
    try {
      print('🔧 [AndroidBackgroundService] Tentative de démarrage via Intent...');
      print('🔧 [AndroidBackgroundService] Canal utilisé pour Intent: ${_channel.name}');
      
      // Utiliser le canal pour démarrer le service via Intent
      final result = await _channel.invokeMethod('startServiceViaIntent');
      print('🔧 [AndroidBackgroundService] Résultat Intent: $result');
      
      _isActive = true;
      print('🔧 [AndroidBackgroundService] ✅ Service démarré via Intent');
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors du démarrage via Intent: $e');
      print('🔧 [AndroidBackgroundService] ❌ Type d\'erreur Intent: ${e.runtimeType}');
    }
  }
  
  /// Démarrer le timer de maintien en vie
  static void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    
    // Maintenir le service actif toutes les 30 secondes
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isActive) {
        _keepServiceAlive();
      }
    });
    
    print('🔧 [AndroidBackgroundService] ⏰ Timer de maintien du service Android démarré (30s)');
  }
  
  /// Arrêter le timer de maintien en vie
  static void _stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    print('🔧 [AndroidBackgroundService] ⏰ Timer de maintien du service Android arrêté');
  }
  
  /// Maintenir le service Android actif
  static Future<void> _keepServiceAlive() async {
    try {
      // Envoyer un signal de maintien en vie
      await _channel.invokeMethod('keepServiceAlive');
      print('💓 [AndroidBackgroundService] Signal de maintien en vie envoyé au service Android');
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors du maintien en vie: $e');
      // Essayer de redémarrer le service
      await _restartService();
    }
  }
  
  /// Redémarrer le service si nécessaire
  static Future<void> _restartService() async {
    try {
      print('🔄 [AndroidBackgroundService] Redémarrage du service Android...');
      
      await stopNativeService();
      await Future.delayed(const Duration(seconds: 1));
      await startNativeService();
      
      print('🔧 [AndroidBackgroundService] ✅ Service Android redémarré');
      
    } catch (e) {
      print('🔧 [AndroidBackgroundService] ❌ Erreur lors du redémarrage: $e');
    }
  }
  
  /// Vérifier si le service est actif
  static bool get isActive => _isActive;
  
  /// Nettoyer les ressources
  static void dispose() {
    stopNativeService();
  }
}

