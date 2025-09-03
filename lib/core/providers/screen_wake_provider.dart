import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/screen_wake_service.dart';

/// Provider pour le service d'écran de veille
final screenWakeServiceProvider = Provider<ScreenWakeService>((ref) {
  return ScreenWakeService();
});

/// Provider pour l'état de l'écran de veille
final screenWakeStateProvider = StateNotifierProvider<ScreenWakeStateNotifier, bool>((ref) {
  return ScreenWakeStateNotifier(ref.read(screenWakeServiceProvider));
});

/// Notifier pour gérer l'état de l'écran de veille
class ScreenWakeStateNotifier extends StateNotifier<bool> {
  final ScreenWakeService _screenWakeService;

  ScreenWakeStateNotifier(this._screenWakeService) : super(false);

  /// Activer l'écran de veille
  Future<void> enable() async {
    try {
      await _screenWakeService.enable();
      state = true;
    } catch (e) {
      print('❌ Erreur lors de l\'activation de l\'écran de veille: $e');
    }
  }

  /// Désactiver l'écran de veille
  Future<void> disable() async {
    try {
      await _screenWakeService.disable();
      state = false;
    } catch (e) {
      print('❌ Erreur lors de la désactivation de l\'écran de veille: $e');
    }
  }

  /// Basculer l'état de l'écran de veille
  Future<void> toggle() async {
    try {
      await _screenWakeService.toggle();
      state = _screenWakeService.isEnabled;
    } catch (e) {
      print('❌ Erreur lors du basculement de l\'écran de veille: $e');
    }
  }

  /// Activer l'écran de veille seulement si la vidéo est en cours de lecture
  Future<void> enableForVideoPlayback(bool isPlaying) async {
    try {
      await _screenWakeService.enableForVideoPlayback(isPlaying);
      state = _screenWakeService.isEnabled;
    } catch (e) {
      print('❌ Erreur lors de la gestion de l\'écran de veille pour la vidéo: $e');
    }
  }
} 