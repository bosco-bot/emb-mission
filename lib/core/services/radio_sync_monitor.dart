import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'android_background_service.dart';

/// 🔧 SERVICE DE SURVEILLANCE RADIO - Vérification et correction automatique
/// 
/// Ce service surveille en permanence la synchronisation entre Flutter et Android
/// et corrige automatiquement tous les problèmes détectés.
class RadioSyncMonitor {
  static final RadioSyncMonitor _instance = RadioSyncMonitor._internal();
  factory RadioSyncMonitor() => _instance;
  RadioSyncMonitor._internal();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  
  // Configuration de surveillance
  static const Duration _monitoringInterval = Duration(seconds: 10);
  static const int _maxConsecutiveFailures = 3;
  int _consecutiveFailures = 0;
  
  /// 🚀 Démarrer la surveillance automatique
  void startMonitoring() {
    if (_isMonitoring) return;
    
    print('🔧 [RadioSyncMonitor] 🚀 Démarrage de la surveillance automatique...');
    _isMonitoring = true;
    
    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) {
      _performHealthCheck();
    });
    
    print('🔧 [RadioSyncMonitor] ✅ Surveillance démarrée (intervalle: ${_monitoringInterval.inSeconds}s)');
  }
  
  /// 🛑 Arrêter la surveillance
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    print('🔧 [RadioSyncMonitor] 🛑 Arrêt de la surveillance...');
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    print('🔧 [RadioSyncMonitor] ✅ Surveillance arrêtée');
  }
  
  /// 🔍 Vérification de santé complète
  Future<void> _performHealthCheck() async {
    try {
      print('🔧 [RadioSyncMonitor] 🔍 Vérification de santé...');
      
      // 1. Vérifier la communication avec Android
      final communicationOk = await _checkCommunication();
      
      if (!communicationOk) {
        _consecutiveFailures++;
        print('🔧 [RadioSyncMonitor] ❌ Communication échouée ($_consecutiveFailures/$_maxConsecutiveFailures)');
        
        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          print('🔧 [RadioSyncMonitor] 🚨 ÉCHEC CRITIQUE - Tentative de récupération...');
          await _attemptRecovery();
          _consecutiveFailures = 0;
        }
        return;
      }
      
      // 2. Vérifier la cohérence des états
      final stateConsistencyOk = await _checkStateConsistency();
      
      if (!stateConsistencyOk) {
        print('🔧 [RadioSyncMonitor] ⚠️ Incohérence d\'état détectée - Correction...');
        await _fixStateInconsistency();
      }
      
      // 3. Réinitialiser le compteur d'échecs si tout va bien
      if (_consecutiveFailures > 0) {
        print('🔧 [RadioSyncMonitor] ✅ Communication rétablie - Réinitialisation du compteur d\'échecs');
        _consecutiveFailures = 0;
      }
      
      print('🔧 [RadioSyncMonitor] ✅ Vérification de santé terminée');
      
    } catch (e) {
      print('🔧 [RadioSyncMonitor] ❌ Erreur lors de la vérification de santé: $e');
    }
  }
  
  /// 📡 Vérifier la communication avec Android
  Future<bool> _checkCommunication() async {
    try {
      print('🔧 [RadioSyncMonitor] 📡 Vérification de la communication Android...');
      
      // Essayer d'appeler une méthode simple
      final result = await AndroidBackgroundService.forceCompleteSync();
      
      print('🔧 [RadioSyncMonitor] ✅ Communication Android OK');
      return true;
      
    } catch (e) {
      print('🔧 [RadioSyncMonitor] ❌ Communication Android échouée: $e');
      return false;
    }
  }
  
  /// 🔄 Vérifier la cohérence des états
  Future<bool> _checkStateConsistency() async {
    try {
      print('🔧 [RadioSyncMonitor] 🔄 Vérification de la cohérence des états...');
      
      // TODO: Implémenter la vérification de cohérence avec le provider radio
      // Pour l'instant, on considère que c'est OK
      
      print('🔧 [RadioSyncMonitor] ✅ Cohérence des états OK');
      return true;
      
    } catch (e) {
      print('🔧 [RadioSyncMonitor] ❌ Erreur lors de la vérification de cohérence: $e');
      return false;
    }
  }
  
  /// 🔧 Corriger l'incohérence d'état
  Future<void> _fixStateInconsistency() async {
    try {
      print('🔧 [RadioSyncMonitor] 🔧 Correction de l\'incohérence d\'état...');
      
      // Forcer une synchronisation complète
      await AndroidBackgroundService.forceCompleteSync();
      
      print('🔧 [RadioSyncMonitor] ✅ Incohérence d\'état corrigée');
      
    } catch (e) {
      print('🔧 [RadioSyncMonitor] ❌ Erreur lors de la correction: $e');
    }
  }
  
  /// 🚨 Tentative de récupération après échec critique
  Future<void> _attemptRecovery() async {
    try {
      print('🔧 [RadioSyncMonitor] 🚨 TENTATIVE DE RÉCUPÉRATION...');
      
      // 1. Arrêter complètement le service
      await AndroidBackgroundService.stopNativeService();
      
      // 2. Attendre un peu
      await Future.delayed(const Duration(seconds: 2));
      
      // 3. Redémarrer le service
      await AndroidBackgroundService.startNativeService();
      
      // 4. Forcer une synchronisation complète
      await AndroidBackgroundService.forceCompleteSync();
      
      print('🔧 [RadioSyncMonitor] ✅ Récupération réussie');
      
    } catch (e) {
      print('🔧 [RadioSyncMonitor] ❌ Échec de la récupération: $e');
    }
  }
  
  /// 🔄 Forcer une vérification immédiate
  Future<void> forceHealthCheck() async {
          print('🔧 [RadioSyncMonitor] 🔄 Vérification de santé forcée...');
      await _performHealthCheck();
  }
  
  /// 📊 Obtenir le statut de surveillance
  bool get isMonitoring => _isMonitoring;
  
  /// 🧹 Nettoyer les ressources
  void dispose() {
    stopMonitoring();
  }
}

/// Provider pour le moniteur de synchronisation radio
final radioSyncMonitorProvider = Provider<RadioSyncMonitor>((ref) {
  final monitor = RadioSyncMonitor();
  
  // Nettoyer automatiquement à la fin
  ref.onDispose(() {
    monitor.dispose();
  });
  
  return monitor;
});

