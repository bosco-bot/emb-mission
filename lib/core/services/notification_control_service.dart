import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/radio_player_provider.dart';

/// Service pour gérer les contrôles de la notification
class NotificationControlService {
  static const MethodChannel _channel = MethodChannel('com.embmission.radio_control');
  static NotificationControlService? _instance;
  
  WidgetRef? _ref;
  
  static NotificationControlService get instance {
    _instance ??= NotificationControlService._internal();
    return _instance!;
  }
  
  NotificationControlService._internal();
  
  /// Initialiser le service avec la référence Riverpod
  void initialize(WidgetRef ref) {
    _ref = ref;
    _setupMethodCallHandler();
    print('🎛️ Service de contrôle de notification initialisé');
  }
  
  /// Configurer l'écoute des méthodes natives
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'onRadioAction') {
          final action = call.arguments['action'] as String?;
          print('🎛️ Action reçue de la notification: $action');
          
          if (action != null) {
            await _handleRadioAction(action);
          }
        }
      } catch (e) {
        print('❌ Erreur lors du traitement de l\'action: $e');
      }
    });
  }
  
  /// Traiter les actions de radio reçues
  Future<void> _handleRadioAction(String action) async {
    if (_ref == null) {
      print('❌ Référence Riverpod non initialisée');
      return;
    }
    
    try {
      final radioNotifier = _ref!.read(radioPlayingProvider.notifier);
      final isPlaying = _ref!.read(radioPlayingProvider);
      
      switch (action) {
        case 'STOP_RADIO':
          print('⏹️ Arrêt radio demandé depuis la notification');
          await radioNotifier.stopRadio();
          print('⏹️ Radio arrêtée via notification');
          break;
          
        default:
          print('❓ Action non reconnue: $action');
      }
      
    } catch (e) {
      print('❌ Erreur lors de l\'exécution de l\'action $action: $e');
    }
  }
  
  /// Nettoyer les ressources
  void dispose() {
    _ref = null;
    print('🧹 Service de contrôle de notification nettoyé');
  }
}
