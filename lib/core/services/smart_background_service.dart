import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'background_maintenance_service.dart';

/// Service intelligent pour gérer l'activité en arrière-plan
/// Adapte automatiquement le niveau d'activité selon le contexte
class SmartBackgroundService {
  static final SmartBackgroundService _instance = SmartBackgroundService._internal();
  factory SmartBackgroundService() => _instance;
  SmartBackgroundService._internal();

  Timer? _contextAnalysisTimer;
  bool _isActive = false;
  
  // ✅ NOUVEAU: Analyse du contexte utilisateur
  DateTime? _lastUserInteraction;
  bool _isRadioPlaying = false;
  bool _hasActiveNotifications = false;
  bool _isLowBattery = false;

  /// Démarrer le service intelligent
  Future<void> start() async {
    if (_isActive) return;
    
    try {
      print('🧠 Démarrage du service intelligent de gestion en arrière-plan');
      
      // Démarrer le service de maintien en mode normal
      BackgroundMaintenanceService().start();
      
      // Démarrer l'analyse du contexte
      _startContextAnalysis();
      
      _isActive = true;
      print('✅ Service intelligent démarré');
      
    } catch (e) {
      print('❌ Erreur lors du démarrage du service intelligent: $e');
    }
  }

  /// Arrêter le service intelligent
  Future<void> stop() async {
    if (!_isActive) return;
    
    try {
      print('🧠 Arrêt du service intelligent');
      
      // Arrêter l'analyse du contexte
      _contextAnalysisTimer?.cancel();
      
      // Arrêter le service de maintien
      BackgroundMaintenanceService().stop();
      
      _isActive = false;
      print('✅ Service intelligent arrêté');
      
    } catch (e) {
      print('❌ Erreur lors de l\'arrêt du service intelligent: $e');
    }
  }

  /// Démarrer l'analyse du contexte
  void _startContextAnalysis() {
    _contextAnalysisTimer?.cancel();
    
    // Analyser le contexte toutes les minutes
    _contextAnalysisTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isActive) {
        _analyzeContext();
      }
    });
    
    print('🔍 Analyse du contexte démarrée (1min)');
  }

  /// Analyser le contexte et adapter l'activité
  void _analyzeContext() {
    try {
      print('🧠 Analyse du contexte en cours...');
      
      // 1. Analyser l'activité utilisateur
      _analyzeUserActivity();
      
      // 2. Analyser l'état de la radio
      _analyzeRadioState();
      
      // 3. Analyser les notifications
      _analyzeNotifications();
      
      // 4. Analyser la batterie
      _analyzeBatteryState();
      
      // 5. Prendre une décision intelligente
      _makeSmartDecision();
      
      print('✅ Analyse du contexte terminée');
      
    } catch (e) {
      print('❌ Erreur lors de l\'analyse du contexte: $e');
    }
  }

  /// Analyser l'activité utilisateur
  void _analyzeUserActivity() {
    final now = DateTime.now();
    final timeSinceInteraction = _lastUserInteraction != null 
        ? now.difference(_lastUserInteraction!).inMinutes 
        : 60;
    
    print('👤 Activité utilisateur: ${timeSinceInteraction}min depuis la dernière interaction');
    
    // Mettre à jour le service de maintien
    BackgroundMaintenanceService().updateUserActivity();
  }

  /// Analyser l'état de la radio
  void _analyzeRadioState() {
    // Cette méthode sera appelée depuis le provider radio
    print('📻 État radio: ${_isRadioPlaying ? "En cours" : "Arrêtée"}');
  }

  /// Analyser les notifications
  void _analyzeNotifications() {
    // Cette méthode sera appelée depuis le service de notifications
    print('🔔 Notifications: ${_hasActiveNotifications ? "Actives" : "Aucune"}');
  }

  /// Analyser l'état de la batterie
  void _analyzeBatteryState() {
    // Cette méthode peut être étendue pour vérifier le niveau de batterie
    print('🔋 État batterie: ${_isLowBattery ? "Faible" : "Normal"}');
  }

  /// Prendre une décision intelligente sur le niveau d'activité
  void _makeSmartDecision() {
    final maintenanceService = BackgroundMaintenanceService();
    
    // ✅ LOGIQUE INTELLIGENTE: Adapter le mode selon le contexte
    
    if (_isRadioPlaying) {
      // Radio en cours → mode agressif pour maintenir la stabilité
      maintenanceService.setMode(BackgroundMaintenanceService.BackgroundMode.aggressive);
      print('🎵 Radio active → mode agressif activé');
      
    } else if (_hasActiveNotifications) {
      // Notifications actives → mode normal
      maintenanceService.setMode(BackgroundMaintenanceService.BackgroundMode.normal);
      print('🔔 Notifications actives → mode normal activé');
      
    } else if (_isLowBattery) {
      // Batterie faible → mode économie
      maintenanceService.setMode(BackgroundMaintenanceService.BackgroundMode.battery);
      print('🔋 Batterie faible → mode économie activé');
      
    } else {
      // Contexte normal → mode normal
      maintenanceService.setMode(BackgroundMaintenanceService.BackgroundMode.normal);
      print('📱 Contexte normal → mode normal activé');
    }
  }

  /// ✅ NOUVEAU: Mettre à jour l'état de la radio
  void updateRadioState(bool isPlaying) {
    _isRadioPlaying = isPlaying;
    print('📻 État radio mis à jour: ${isPlaying ? "En cours" : "Arrêtée"}');
  }

  /// ✅ NOUVEAU: Mettre à jour l'état des notifications
  void updateNotificationState(bool hasActive) {
    _hasActiveNotifications = hasActive;
    print('🔔 État notifications mis à jour: ${hasActive ? "Actives" : "Aucune"}');
  }

  /// ✅ NOUVEAU: Mettre à jour l'état de la batterie
  void updateBatteryState(bool isLow) {
    _isLowBattery = isLow;
    print('🔋 État batterie mis à jour: ${isLow ? "Faible" : "Normal"}');
  }

  /// ✅ NOUVEAU: Enregistrer une interaction utilisateur
  void recordUserInteraction() {
    _lastUserInteraction = DateTime.now();
    print('👤 Interaction utilisateur enregistrée');
  }

  /// Vérifier si le service est actif
  bool get isActive => _isActive;

  /// Obtenir le mode actuel
  BackgroundMaintenanceService.BackgroundMode get currentMode {
    return BackgroundMaintenanceService().currentMode;
  }

  /// Nettoyer les ressources
  void dispose() {
    stop();
  }
}


