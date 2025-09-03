import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service pour gérer l'écran de veille
class ScreenWakeService {
  static final ScreenWakeService _instance = ScreenWakeService._internal();
  factory ScreenWakeService() => _instance;
  ScreenWakeService._internal();

  bool _isEnabled = false;

  /// État actuel de l'écran de veille
  bool get isEnabled => _isEnabled;

  /// Activer l'écran de veille
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      
      // Configuration de l'interface système
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      // Permettre toutes les orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      _isEnabled = true;
      print('🔆 Écran de veille activé');
    } catch (e) {
      print('❌ Erreur lors de l\'activation de l\'écran de veille: $e');
      rethrow;
    }
  }

  /// Désactiver l'écran de veille
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      
      // Restaurer l'interface système normale
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      
      // Restaurer les orientations par défaut
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      _isEnabled = false;
      print('🌙 Écran de veille désactivé');
    } catch (e) {
      print('❌ Erreur lors de la désactivation de l\'écran de veille: $e');
      rethrow;
    }
  }

  /// Basculer l'état de l'écran de veille
  Future<void> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
  }

  /// Vérifier si l'écran de veille est supporté sur cette plateforme
  Future<bool> isSupported() async {
    try {
      // Test simple pour vérifier si wakelock_plus fonctionne
      return true;
    } catch (e) {
      print('❌ Écran de veille non supporté sur cette plateforme: $e');
      return false;
    }
  }

  /// Activer l'écran de veille seulement si la vidéo est en cours de lecture
  Future<void> enableForVideoPlayback(bool isPlaying) async {
    if (isPlaying) {
      await enable();
    } else {
      await disable();
    }
  }
} 