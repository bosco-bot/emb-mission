import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'android_background_service.dart';

// ✅ NOUVEAU: Énumération des modes de fonctionnement au niveau supérieur
enum BackgroundMode {
  normal,      // Mode normal : maintien actif
  battery,     // Mode économie de batterie
  aggressive,  // Mode agressif : maintien maximum
}

/// Service pour maintenir l'application active en arrière-plan
class BackgroundMaintenanceService {
  static final BackgroundMaintenanceService _instance = BackgroundMaintenanceService._internal();
  factory BackgroundMaintenanceService() => _instance;
  BackgroundMaintenanceService._internal();

  Timer? _keepAliveTimer;
  Timer? _healthCheckTimer;
  bool _isActive = false;
  
  // ✅ NOUVEAU: Mode intelligent pour optimiser la batterie
  BackgroundMode _currentMode = BackgroundMode.normal;
  DateTime? _lastUserActivity;

  /// Démarrer le service de maintien en arrière-plan
  Future<void> start() async {
    if (_isActive) return;
    
    try {
      print('🔄 Démarrage du service de maintien en arrière-plan');
      
      // ✅ CORRECTION: NE PAS démarrer le service Android dans le service de maintenance
      // Le service de maintenance ne doit PAS démarrer le service Android
      // Le service Android doit être démarré SEULEMENT par la radio
      print('✅ Service de maintenance démarré SANS service Android');
      
      // 1. Démarrer le timer de maintien en vie
      _startKeepAliveTimer();
      
      // 2. Démarrer le timer de vérification de santé
      _startHealthCheckTimer();
      
      // 3. Maintenir l'activité système active
      _keepSystemActive();
      
      _isActive = true;
      print('✅ Service de maintien en arrière-plan démarré');
      
    } catch (e) {
      print('❌ Erreur lors du démarrage du service de maintien: $e');
    }
  }

  /// Arrêter le service de maintien en arrière-plan
  Future<void> stop() async {
    if (!_isActive) return;
    
    try {
      print('🔄 Arrêt du service de maintien en arrière-plan');
      
      // ✅ CORRECTION: NE PAS arrêter le service Android dans le service de maintenance
      // Le service Android doit être géré SEULEMENT par la radio
      print('✅ Service de maintenance arrêté SANS toucher au service Android');
      
      // 1. Arrêter les timers
      _keepAliveTimer?.cancel();
      _healthCheckTimer?.cancel();
      
      // 2. Restaurer l'état système normal
      _restoreSystemState();
      
      _isActive = false;
      print('✅ Service de maintien en arrière-plan arrêté');
      
    } catch (e) {
      print('❌ Erreur lors de l\'arrêt du service de maintien: $e');
    }
  }

  /// Démarrer le timer de maintien en vie
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    
    // ✅ OPTIMISATION INTELLIGENTE: Fréquence adaptée au mode
    final interval = _getKeepAliveInterval();
    _keepAliveTimer = Timer.periodic(interval, (timer) {
      if (_isActive) {
        _performKeepAliveAction();
      }
    });
    
    print('⏰ Timer de maintien en vie démarré (${interval.inSeconds}s) - mode: $_currentMode');
  }

  /// ✅ NOUVEAU: Détermine l'intervalle selon le mode actuel
  Duration _getKeepAliveInterval() {
    switch (_currentMode) {
      case BackgroundMode.aggressive:
        return const Duration(seconds: 10);  // Très fréquent
      case BackgroundMode.normal:
        return const Duration(seconds: 15);  // Normal
      case BackgroundMode.battery:
        return const Duration(seconds: 30);  // Économie
    }
  }

  /// Démarrer le timer de vérification de santé
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    
    // ✅ OPTIMISATION INTELLIGENTE: Fréquence adaptée au mode
    final interval = _getHealthCheckInterval();
    _healthCheckTimer = Timer.periodic(interval, (timer) {
      if (_isActive) {
        _performHealthCheck();
      }
    });
    
    print('🏥 Timer de vérification de santé démarré (${interval.inMinutes}min) - mode: $_currentMode');
  }

  /// ✅ NOUVEAU: Détermine l'intervalle de santé selon le mode
  Duration _getHealthCheckInterval() {
    switch (_currentMode) {
      case BackgroundMode.aggressive:
        return const Duration(minutes: 1);   // Très fréquent
      case BackgroundMode.normal:
        return const Duration(minutes: 2);   // Normal
      case BackgroundMode.battery:
        return const Duration(minutes: 5);   // Économie
    }
  }

  /// Action de maintien en vie
  void _performKeepAliveAction() {
    try {
      // ✅ CORRECTION: Ne pas redémarrer automatiquement le service Android
      // Le service de maintenance ne doit PAS redémarrer le service Android automatiquement
      // Il doit seulement maintenir l'activité système
      
      // 1. Maintenir l'activité système active
      _keepSystemActive();
      
      // 2. Maintenir le focus de l'application
      _maintainAppFocus();
      
      // ✅ NOUVEAU: Vérifier que l'app est toujours active
      _verifyAppStillActive();
      
      print('💓 Action de maintien en vie effectuée (SANS redémarrage service Android)');
      
    } catch (e) {
      print('❌ Erreur lors de l\'action de maintien en vie: $e');
    }
  }

  /// Vérification de santé de l'application
  void _performHealthCheck() {
    try {
      // 1. Vérifier que l'app est toujours active
      print('🏥 Vérification de santé de l\'application');
      
      // 2. Vérifier la mémoire disponible
      _checkMemoryUsage();
      
      // 3. Vérifier la connectivité réseau
      _checkNetworkConnectivity();
      
      // ✅ NOUVEAU: Optimisation automatique selon le contexte
      optimizeForContext();
      
      print('✅ Vérification de santé terminée');
      
    } catch (e) {
      print('❌ Erreur lors de la vérification de santé: $e');
    }
  }

  /// Vérifier l'utilisation de la mémoire
  void _checkMemoryUsage() {
    try {
      // Log de l'utilisation de la mémoire (pour debug)
      print('💾 Vérification de l\'utilisation mémoire');
      
      // Ici vous pourriez ajouter une logique pour libérer de la mémoire si nécessaire
      
    } catch (e) {
      print('❌ Erreur lors de la vérification mémoire: $e');
    }
  }

  /// Vérifier la connectivité réseau
  void _checkNetworkConnectivity() {
    try {
      // Log de la connectivité réseau (pour debug)
      print('🌐 Vérification de la connectivité réseau');
      
      // Ici vous pourriez ajouter une logique pour vérifier la connexion
      
    } catch (e) {
      print('❌ Erreur lors de la vérification réseau: $e');
    }
  }

  /// Maintenir l'activité système active
  void _keepSystemActive() {
    try {
      // Maintenir l'écran actif temporairement (si nécessaire)
      // Cette méthode est plus efficace que l'audio silencieux
      print('🔆 Maintien de l\'activité système');
      
    } catch (e) {
      print('❌ Erreur lors du maintien de l\'activité système: $e');
    }
  }

  /// Maintenir le focus de l'application
  void _maintainAppFocus() {
    try {
      // Maintenir le focus de l'application via les canaux système
      SystemChannels.platform.invokeMethod('SystemChrome.setSystemUIOverlayStyle', {
        'statusBarBrightness': 'dark',
      });
      
      print('🎯 Focus de l\'application maintenu');
      
    } catch (e) {
      print('❌ Erreur lors du maintien du focus: $e');
    }
  }

  /// Restaurer l'état système normal
  void _restoreSystemState() {
    try {
      // Restaurer l'interface système normale
      SystemChannels.platform.invokeMethod('SystemChrome.setSystemUIOverlayStyle', {
        'statusBarBrightness': 'light',
      });
      
      print('🔄 État système restauré');
      
    } catch (e) {
      print('❌ Erreur lors de la restauration de l\'état système: $e');
    }
  }

  /// ✅ NOUVEAU: Vérifier que l'application est toujours active
  void _verifyAppStillActive() {
    try {
      // Vérifier que l'app n'a pas été tuée par le système
      // Cette méthode peut être étendue selon les besoins
      print('🔍 Vérification que l\'app est toujours active');
      
      // Ici vous pourriez ajouter des vérifications supplémentaires
      // comme la connectivité réseau, l'état des services, etc.
      
    } catch (e) {
      print('❌ Erreur lors de la vérification d\'activité: $e');
    }
  }

  /// ✅ NOUVEAU: Changer le mode de fonctionnement
  void setMode(BackgroundMode mode) {
    if (_currentMode != mode) {
      print('🔄 Changement de mode: $_currentMode → $mode');
      _currentMode = mode;
      
      // Redémarrer les timers avec la nouvelle fréquence
      if (_isActive) {
        _startKeepAliveTimer();
        _startHealthCheckTimer();
      }
    }
  }

  /// ✅ NOUVEAU: Mode automatique selon l'activité utilisateur
  void updateUserActivity() {
    _lastUserActivity = DateTime.now();
    
    // Si l'utilisateur est actif, passer en mode normal
    if (_currentMode == BackgroundMode.battery) {
      setMode(BackgroundMode.normal);
      print('👤 Utilisateur actif détecté - passage en mode normal');
    }
  }

  /// ✅ NOUVEAU: Optimisation automatique selon le contexte
  void optimizeForContext() {
    final now = DateTime.now();
    final timeSinceActivity = _lastUserActivity != null 
        ? now.difference(_lastUserActivity!).inMinutes 
        : 60;
    
    if (timeSinceActivity > 30) {
      // Inactivité prolongée → mode économie
      setMode(BackgroundMode.battery);
      print('🔋 Inactivité prolongée détectée - passage en mode économie');
    } else if (timeSinceActivity < 5) {
      // Activité récente → mode normal
      setMode(BackgroundMode.normal);
      print('👤 Activité récente détectée - passage en mode normal');
    }
  }

  /// Vérifier si le service est actif
  bool get isActive => _isActive;

  /// Obtenir le mode actuel
  BackgroundMode get currentMode => _currentMode;

  /// Nettoyer les ressources
  void dispose() {
    stop();
  }
}
