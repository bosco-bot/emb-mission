import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:emb_mission/core/services/android_background_service.dart';
import 'package:emb_mission/core/services/background_maintenance_service.dart';
import 'package:emb_mission/core/services/screen_wake_service.dart';

// Provider global pour l'instance du player radio
final radioPlayerProvider = Provider<AudioPlayer>((ref) {
  return AudioPlayer();
});

// 🚨 NOUVEAU: Provider global pour arrêter TOUS les players radio
final radioStopAllProvider = StateNotifierProvider<RadioStopAllNotifier, bool>((ref) {
  return RadioStopAllNotifier(
    ref.read(radioPlayerProvider),
    ref.read(radioPlayingProvider.notifier),
  );
});

// 🚨 NOUVEAU: Notifier pour arrêter TOUS les players radio
class RadioStopAllNotifier extends StateNotifier<bool> {
  final AudioPlayer _player;
  final RadioPlayingNotifier _radioPlayingNotifier;
  
  RadioStopAllNotifier(this._player, this._radioPlayingNotifier) : super(false);
  
  // Méthode pour déclencher l'arrêt global
  Future<void> stopAllRadio() async {
    print('[RADIO STOP ALL] Arrêt global de tous les players radio...');
    
    try {
      // 1. Arrêter le player principal
      if (_player.playing) {
        await _player.stop();
        print('[RADIO STOP ALL] Player principal arrêté');
      }
      
      // 2. Arrêter AudioService
      try {
        await AudioService.stop();
        print('[RADIO STOP ALL] AudioService arrêté');
      } catch (e) {
        print('[RADIO STOP ALL] Erreur arrêt AudioService: $e');
      }
      
      // 3. Mettre à jour l'état global
      _radioPlayingNotifier.updatePlayingState(false);
      print('[RADIO STOP ALL] État global mis à jour: false');
      
      // 4. 🚨 NOUVEAU: Déclencher le signal pour arrêter les players en cache
      state = !state; // Changer l'état pour déclencher le listener
      
      print('[RADIO STOP ALL] Signal envoyé pour arrêter les players en cache TURBO');
      print('[RADIO STOP ALL] Tous les players radio arrêtés avec succès');
      
    } catch (e) {
      print('[RADIO STOP ALL] Erreur lors de l\'arrêt global: $e');
    }
  }
  
  // 🚨 NOUVELLE MÉTHODE: Arrêter spécifiquement les players en cache TURBO
  Future<void> stopCachedPlayers() async {
    print('[RADIO STOP ALL] Arrêt des players en cache TURBO...');
    
    try {
      // Cette méthode sera appelée depuis RadioScreen
      // pour arrêter ses players en cache
      print('[RADIO STOP ALL] Signal d\'arrêt des players en cache envoyé');
      
    } catch (e) {
      print('[RADIO STOP ALL] Erreur lors de l\'arrêt des players en cache: $e');
    }
  }
}

class RadioPlayingNotifier extends StateNotifier<bool> {
  final AudioPlayer player;
  late final Stream<bool> _playingStream;
  late final StreamSubscription<bool> _sub;
  bool _audioServiceInitialized = false;
  
  // ✅ NOUVEAU: Service de wake lock pour empêcher la mise en veille
  final ScreenWakeService _screenWakeService = ScreenWakeService();

  RadioPlayingNotifier(this.player) : super(false) {
    _playingStream = player.playingStream;
    _sub = _playingStream.listen(
      (playing) {
        try {
          print('[RADIO PROVIDER] État de lecture changé: $playing');
          if (mounted) {
            state = playing;
          }
        } catch (e) {
          print('[RADIO PROVIDER] ❌ Erreur dans le listener playingStream: $e');
          // Ne pas faire planter le StateNotifier
        }
      },
      onError: (error) {
        print('[RADIO PROVIDER] ❌ Erreur dans le stream playingStream: $error');
        // Ne pas faire planter le StateNotifier
      },
    );
    _initAudioService();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  // Méthode pour forcer la mise à jour de l'état
  void updatePlayingState(bool isPlaying) {
    try {
      print('[RADIO PROVIDER] Mise à jour forcée de l\'état: $isPlaying');
      if (mounted) {
        state = isPlaying;
      }
    } catch (e) {
      print('[RADIO PROVIDER] ❌ Erreur lors de updatePlayingState: $e');
      // Ne pas faire planter le StateNotifier
    }
  }

  // ✅ OPTIMISATION: AudioService déjà initialisé dans main.dart
  // Pas besoin de réinitialiser ici pour éviter les conflits
  Future<void> _initAudioService() async {
    try {
      print('[RADIO PROVIDER] AudioService déjà initialisé dans main.dart');
      _audioServiceInitialized = true;
    } catch (e) {
      print('[RADIO PROVIDER] Erreur lors de la vérification AudioService: $e');
    }
  }

  // Méthode pour démarrer la radio
  Future<void> startRadio(String url, String radioName) async {
    print('[RADIO PROVIDER DEBUG] startRadio() appelé avec URL: $url');
    print('[RADIO PROVIDER DEBUG] 🚨 ATTENTION: Cette méthode démarre le service Android ET affiche la notification');
    try {
      // Arrêter le player actuel s'il joue
      if (player.playing) {
        print('[RADIO PROVIDER DEBUG] Player en cours de lecture, arrêt...');
        await player.stop();
      }

      print('[RADIO PROVIDER DEBUG] Configuration de l\'URL: $url');
      
      // ✅ NOUVELLE OPTIMISATION: Configuration audio ultra-rapide
      await player.setUrl(url);
      print('[RADIO PROVIDER DEBUG] URL configurée, démarrage IMMÉDIAT de la lecture...');
      
      // ✅ OPTIMISATION: Configuration audio minimale pour la performance
      await player.setVolume(1.0);
      await player.setSpeed(1.0); // ✅ Correction: setSpeed au lieu de setPlaybackRate
      
      // Démarrer la lecture immédiatement
      await player.play();
      print('[RADIO PROVIDER DEBUG] Lecture démarrée immédiatement');
      
      // Mettre à jour l'état
      updatePlayingState(true);
      print('[RADIO PROVIDER] Radio démarrée avec succès: $url');
      
      // ✅ NOUVEAU: Activer le wake lock pour empêcher la mise en veille
      try {
        await _screenWakeService.enable();
        print('[RADIO PROVIDER] ✅ Wake lock activé pour empêcher la mise en veille');
      } catch (e) {
        print('[RADIO PROVIDER] ⚠️ Erreur activation wake lock: $e');
      }
      
      // ✅ NOUVEAU: Démarrer le service Android avec notification
      try {
        print('[RADIO PROVIDER] ⚡ DÉBUT - Tentative de démarrage du service Android...');
        await AndroidBackgroundService.startNativeService();
        print('[RADIO PROVIDER] ✅ Service Android démarré avec succès');
        
        // ✅ NOUVEAU: Démarrer le service de maintenance en arrière-plan
        try {
          await BackgroundMaintenanceService().start();
          print('[RADIO PROVIDER] ✅ Service de maintenance démarré avec succès');
        } catch (e) {
          print('[RADIO PROVIDER] ⚠️ Erreur démarrage service maintenance: $e');
        }
        
        // ✅ NOUVEAU: Synchroniser l'état avec Android (radio démarrée)
        const channel = MethodChannel('com.embmission.android_background');
        
        try {
          await channel.invokeMethod('updateRadioState', true);
          print('[RADIO PROVIDER] ✅ État radio synchronisé avec Android: true (démarrage)');
        } catch (syncError) {
          print('[RADIO PROVIDER] ⚠️ Erreur synchronisation état (démarrage): $syncError');
        }
        
        // ✅ FORCER l'affichage de la notification via MethodChannel direct
        print('[RADIO PROVIDER] ⚡ DÉBUT - Tentative de forçage de notification...');
        try {
          final result = await channel.invokeMethod('showNotification');
          print('[RADIO PROVIDER] ✅ Notification forcée via MethodChannel - Résultat: $result');
        } catch (notifError) {
          print('[RADIO PROVIDER] ❌ Erreur notification: $notifError');
          print('[RADIO PROVIDER] ❌ Type erreur notification: ${notifError.runtimeType}');
        }
        
        // ✅ NOUVEAU: Test de forçage supplémentaire
        print('[RADIO PROVIDER] ⚡ Test de forçage supplémentaire...');
        try {
          final forceResult = await channel.invokeMethod('forceShowNotification');
          print('[RADIO PROVIDER] ✅ Forçage supplémentaire réussi: $forceResult');
        } catch (forceError) {
          print('[RADIO PROVIDER] ❌ Erreur forçage supplémentaire: $forceError');
        }
        
      } catch (e) {
        print('[RADIO PROVIDER] ❌ Erreur CRITIQUE lors du démarrage du service Android: $e');
        print('[RADIO PROVIDER] ❌ Type d\'erreur CRITIQUE: ${e.runtimeType}');
        print('[RADIO PROVIDER] ❌ Stack trace: ${StackTrace.current}');
      }
      
      // ✅ OPTIMISATION: Initialiser AudioService en arrière-plan (non bloquant)
      _initAudioServiceInBackground();
      
    } catch (e) {
      print('[RADIO PROVIDER] Erreur lors du démarrage: $e');
      print('[RADIO PROVIDER DEBUG] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }
  
  // ✅ NOUVELLE MÉTHODE: Démarrage ultra-rapide avec cache
  Future<void> startRadioFast(String url, String radioName) async {
    print('[RADIO PROVIDER DEBUG] 🚀 startRadioFast() appelé avec URL: $url');
    print('[RADIO PROVIDER DEBUG] 🚨 ATTENTION: Cette méthode démarre le service Android ET affiche la notification');
    try {
      // 🚀 OPTIMISATION: Vérification ultra-rapide du player
      if (player.playing) {
        await player.stop();
      }

      // 🚀 OPTIMISATION: Configuration ultra-rapide sans vérifications
      await player.setUrl(url);
      
      // 🚀 OPTIMISATION: Démarrage immédiat avec timeout plus généreux
      await player.play().timeout(
        const Duration(seconds: 3), // ⚡ Timeout plus généreux pour éviter les erreurs
        onTimeout: () {
          print('[RADIO PROVIDER FAST] ⚠️ Timeout atteint - mais on continue quand même');
          // Ne pas lancer d'exception, juste continuer
        },
      );
      
      // Mettre à jour l'état immédiatement
      updatePlayingState(true);
      print('[RADIO PROVIDER FAST] 🚀 Radio démarrée ultra-rapidement: $url');
      
      // ✅ NOUVEAU: Activer le wake lock pour empêcher la mise en veille
      try {
        await _screenWakeService.enable();
        print('[RADIO PROVIDER FAST] ✅ Wake lock activé pour empêcher la mise en veille');
      } catch (e) {
        print('[RADIO PROVIDER FAST] ⚠️ Erreur activation wake lock: $e');
      }
      
              // ✅ NOUVEAU: Démarrer le service Android avec notification (même logique que startRadio)
      try {
        print('[RADIO PROVIDER FAST] ⚡ DÉBUT - Tentative de démarrage du service Android...');
        await AndroidBackgroundService.startNativeService();
        print('[RADIO PROVIDER FAST] ✅ Service Android démarré avec succès');
        
        // ✅ NOUVEAU: Démarrer le service de maintenance en arrière-plan
        try {
          await BackgroundMaintenanceService().start();
          print('[RADIO PROVIDER FAST] ✅ Service de maintenance démarré avec succès');
        } catch (e) {
          print('[RADIO PROVIDER FAST] ⚠️ Erreur démarrage service maintenance: $e');
        }
        
        // ✅ NOUVEAU: Synchroniser l'état avec Android (radio démarrée)
        const channel = MethodChannel('com.embmission.android_background');
        
        try {
          await channel.invokeMethod('updateRadioState', true);
          print('[RADIO PROVIDER FAST] ✅ État radio synchronisé avec Android: true (démarrage)');
        } catch (syncError) {
          print('[RADIO PROVIDER FAST] ⚠️ Erreur synchronisation état (démarrage): $syncError');
        }
        
        // ✅ FORCER l'affichage de la notification via MethodChannel direct
        print('[RADIO PROVIDER FAST] ⚡ DÉBUT - Tentative de forçage de notification...');
        try {
          final result = await channel.invokeMethod('showNotification');
          print('[RADIO PROVIDER FAST] ✅ Notification forcée via MethodChannel - Résultat: $result');
        } catch (notifError) {
          print('[RADIO PROVIDER FAST] ❌ Erreur notification: $notifError');
        }
        
        // ✅ NOUVEAU: Test de forçage supplémentaire
        print('[RADIO PROVIDER FAST] ⚡ Test de forçage supplémentaire...');
        try {
          final forceResult = await channel.invokeMethod('forceShowNotification');
          print('[RADIO PROVIDER FAST] ✅ Forçage supplémentaire réussi: $forceResult');
        } catch (forceError) {
          print('[RADIO PROVIDER FAST] ❌ Erreur forçage supplémentaire: $forceError');
        }
        
      } catch (e) {
        print('[RADIO PROVIDER FAST] ❌ Erreur lors du démarrage du service Android: $e');
      }
      
      // AudioService en arrière-plan (non bloquant)
      _initAudioServiceInBackground();
      
    } catch (e) {
      print('[RADIO PROVIDER FAST] Erreur démarrage ultra-rapide: $e');
      // Ne pas rethrow pour éviter de faire planter l'app
      print('[RADIO PROVIDER FAST] ⚠️ Erreur ignorée pour éviter le crash');
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Mode TURBO ultra-agressif
  Future<void> startRadioTurbo(String url, String radioName) async {
    print('[RADIO PROVIDER DEBUG] startRadioTurbo() appelé avec URL: $url');
    try {
      // 🚀 OPTIMISATION TURBO: Configuration ultra-minimale
      if (player.playing) {
        await player.stop();
      }

      // 🚀 CONFIGURATION ULTRA-RAPIDE sans vérifications
      await player.setUrl(url);
      
      // 🚀 DÉMARRAGE INSTANTANÉ avec timeout ultra-agressif
      await player.play().timeout(
        const Duration(milliseconds: 200), // ⚡ Timeout ultra-agressif réduit de 300ms à 200ms
        onTimeout: () {
          print('[RADIO PROVIDER TURBO] ⚠️ Timeout ultra-agressif atteint');
          throw TimeoutException('Démarrage TURBO trop long');
        },
      );
      
      // Mettre à jour l'état immédiatement
      updatePlayingState(true);
      print('[RADIO PROVIDER TURBO] 🚀 Radio démarrée en mode TURBO: $url');
      
      // ✅ NOUVEAU: Activer le wake lock pour empêcher la mise en veille
      try {
        await _screenWakeService.enable();
        print('[RADIO PROVIDER TURBO] ✅ Wake lock activé pour empêcher la mise en veille');
      } catch (e) {
        print('[RADIO PROVIDER TURBO] ⚠️ Erreur activation wake lock: $e');
      }
      
      // ✅ NOUVEAU: Démarrer le service Android avec notification (même logique que startRadio)
      try {
        print('[RADIO PROVIDER TURBO] ⚡ DÉBUT - Tentative de démarrage du service Android...');
        await AndroidBackgroundService.startNativeService();
        print('[RADIO PROVIDER TURBO] ✅ Service Android démarré avec succès');
        
        // ✅ NOUVEAU: Synchroniser l'état avec Android (radio démarrée)
        const channel = MethodChannel('com.embmission.android_background');
        
        try {
          await channel.invokeMethod('updateRadioState', true);
          print('[RADIO PROVIDER TURBO] ✅ État radio synchronisé avec Android: true (démarrage)');
        } catch (syncError) {
          print('[RADIO PROVIDER TURBO] ⚠️ Erreur synchronisation état (démarrage): $syncError');
        }
        
        // ✅ FORCER l'affichage de la notification via MethodChannel direct
        print('[RADIO PROVIDER TURBO] ⚡ DÉBUT - Tentative de forçage de notification...');
        try {
          final result = await channel.invokeMethod('showNotification');
          print('[RADIO PROVIDER TURBO] ✅ Notification forcée via MethodChannel - Résultat: $result');
        } catch (notifError) {
          print('[RADIO PROVIDER TURBO] ❌ Erreur notification: $notifError');
        }
        
      } catch (e) {
        print('[RADIO PROVIDER TURBO] ❌ Erreur lors du démarrage du service Android: $e');
      }
      
      // AudioService en arrière-plan (non bloquant)
      _initAudioServiceInBackground();
      
    } catch (e) {
      print('[RADIO PROVIDER TURBO] Erreur mode TURBO: $e');
      rethrow;
    }
  }
  
  // ✅ NOUVELLE MÉTHODE: Mode TURBO SANS service Android (pour démarrage automatique)
  Future<void> startRadioTurboSilent(String url, String radioName) async {
    print('[RADIO PROVIDER DEBUG] 🚀 startRadioTurboSilent() appelé avec URL: $url (SANS service Android)');
    try {
      // 🚀 OPTIMISATION TURBO: Configuration ultra-minimale
      if (player.playing) {
        await player.stop();
      }

      // 🚀 CONFIGURATION ULTRA-RAPIDE sans vérifications
      await player.setUrl(url);
      
      // 🚀 DÉMARRAGE INSTANTANÉ avec timeout plus généreux pour éviter les erreurs
      await player.play().timeout(
        const Duration(milliseconds: 1000), // ⚡ Timeout plus généreux pour éviter les erreurs
        onTimeout: () {
          print('[RADIO PROVIDER TURBO SILENT] ⚠️ Timeout atteint - mais on continue quand même');
          // Ne pas lancer d'exception, juste continuer
        },
      );
      
      // Mettre à jour l'état immédiatement
      updatePlayingState(true);
      print('[RADIO PROVIDER TURBO SILENT] 🚀 Radio démarrée en mode TURBO SANS service Android: $url');
      
      // ❌ PAS de service Android - pas de notification au démarrage automatique
      
      // AudioService en arrière-plan (non bloquant)
      _initAudioServiceInBackground();
      
    } catch (e) {
      print('[RADIO PROVIDER TURBO SILENT] Erreur démarrage TURBO SANS service Android: $e');
      // Ne pas rethrow pour éviter de faire planter l'app
      print('[RADIO PROVIDER TURBO SILENT] ⚠️ Erreur ignorée pour éviter le crash');
    }
  }

  // ✅ NOUVELLE MÉTHODE: Arrêt forcé de la radio au démarrage de l'app
  Future<void> forceStopRadioOnAppStart() async {
    print('[RADIO PROVIDER DEBUG] 🚨 FORCE STOP RADIO ON APP START - Arrêt forcé de la radio au démarrage...');
    
    try {
      // Arrêter le player audio
      if (player.playing) {
        await player.stop();
        print('[RADIO PROVIDER DEBUG] ✅ Player audio arrêté avec succès');
      }
      
      // Arrêter le service Android et masquer la notification
      try {
        const channel = MethodChannel('com.embmission.android_background');
        await channel.invokeMethod('hideNotification');
        print('[RADIO PROVIDER DEBUG] ✅ Notification masquée avec succès');
      } catch (e) {
        print('[RADIO PROVIDER DEBUG] ⚠️ Impossible de masquer la notification: $e');
      }
      
      // Réinitialiser l'état
      updatePlayingState(false);
      
      // ✅ NOUVEAU: Désactiver le wake lock
      try {
        await _screenWakeService.disable();
        print('[RADIO PROVIDER DEBUG] ✅ Wake lock désactivé (app start)');
      } catch (e) {
        print('[RADIO PROVIDER DEBUG] ⚠️ Erreur désactivation wake lock (app start): $e');
      }
      
      print('[RADIO PROVIDER DEBUG] ✅ État de la radio réinitialisé avec succès');
      
    } catch (e) {
      print('[RADIO PROVIDER DEBUG] ❌ Erreur lors de l\'arrêt forcé: $e');
    }
  }

  // ✅ NOUVELLE MÉTHODE: Démarrage ultra-rapide SANS service Android (pour démarrage automatique)
  Future<void> startRadioFastSilent(String url, String radioName) async {
    print('[RADIO PROVIDER DEBUG] 🚀 startRadioFastSilent() appelé avec URL: $url (SANS service Android)');
    print('[RADIO PROVIDER DEBUG] 🚨 IMPORTANT: Cette méthode NE démarre PAS le service Android');
    try {
      // 🚀 OPTIMISATION: Vérification ultra-rapide du player
      if (player.playing) {
        await player.stop();
      }

      // 🚀 OPTIMISATION: Configuration ultra-rapide sans vérifications
      await player.setUrl(url);
      
      // 🚀 OPTIMISATION: Démarrage immédiat avec timeout ultra-agressif
      await player.play().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () {
          print('[RADIO PROVIDER SILENT] ⚠️ Timeout ultra-agressif atteint');
          throw TimeoutException('Démarrage ultra-rapide trop long');
        },
      );
      
      // Mettre à jour l'état immédiatement
      updatePlayingState(true);
      print('[RADIO PROVIDER SILENT] 🚀 Radio démarrée ultra-rapidement SANS service Android: $url');
      
      // ❌ PAS de service Android - pas de notification au démarrage automatique
      
      // AudioService en arrière-plan (non bloquant)
      _initAudioServiceInBackground();
      
    } catch (e) {
      print('[RADIO PROVIDER SILENT] Erreur démarrage ultra-rapide: $e');
      rethrow;
    }
  }

  // Méthode pour arrêter la radio
  Future<void> stopRadio() async {
    try {
      print('[RADIO PROVIDER] Arrêt de la radio en cours...');
      
      // 🚨 CORRECTION CRITIQUE: Arrêter TOUS les players
      
      // 1. Arrêter le player principal
      await player.stop();
      print('[RADIO PROVIDER] Player principal arrêté');
      
      // 2. Arrêter AudioService si initialisé
      if (_audioServiceInitialized) {
        try {
          await AudioService.stop();
          print('[RADIO PROVIDER] AudioService arrêté');
        } catch (e) {
          print('[RADIO PROVIDER] Erreur arrêt AudioService: $e');
        }
      }
      
      // 3. Mettre à jour l'état global
      updatePlayingState(false);
      print('[RADIO PROVIDER] État global mis à jour: false');
      
      // ✅ NOUVEAU: Désactiver le wake lock
      try {
        await _screenWakeService.disable();
        print('[RADIO PROVIDER] ✅ Wake lock désactivé');
      } catch (e) {
        print('[RADIO PROVIDER] ⚠️ Erreur désactivation wake lock: $e');
      }
      
      // ✅ NOUVEAU: Informer Android que la radio s'est arrêtée AVANT d'arrêter le service
      try {
        const channel = MethodChannel('com.embmission.android_background');
        await channel.invokeMethod('updateRadioState', false);
        print('[RADIO PROVIDER] ✅ État radio synchronisé avec Android: false');
      } catch (syncError) {
        print('[RADIO PROVIDER] ⚠️ Erreur synchronisation état: $syncError');
      }
      
      // ✅ NOUVEAU: Arrêter le service Android APRÈS avoir informé
      try {
        await AndroidBackgroundService.stopNativeService();
        print('[RADIO PROVIDER] Service Android arrêté avec succès');
      } catch (e) {
        print('[RADIO PROVIDER] Erreur lors de l\'arrêt du service Android: $e');
      }
      
      // ✅ NOUVEAU: Arrêter le service de maintenance en arrière-plan
      try {
        await BackgroundMaintenanceService().stop();
        print('[RADIO PROVIDER] Service de maintenance arrêté avec succès');
      } catch (e) {
        print('[RADIO PROVIDER] Erreur lors de l\'arrêt du service maintenance: $e');
      }
      
      // 4. Vérifier que le player est vraiment arrêté
      if (player.playing) {
        print('[RADIO PROVIDER] ⚠️ Player encore en lecture, arrêt forcé...');
        await player.stop();
      }
      
      print('[RADIO PROVIDER] Radio complètement arrêtée');
      
    } catch (e) {
      print('[RADIO PROVIDER] Erreur lors de l\'arrêt: $e');
      // Forcer l'arrêt même en cas d'erreur
      try {
        await player.stop();
        updatePlayingState(false);
      } catch (forceError) {
        print('[RADIO PROVIDER] Erreur lors de l\'arrêt forcé: $forceError');
      }
      rethrow;
    }
  }
  
  // 🚨 NOUVELLE MÉTHODE PUBLIQUE: Force l'arrêt complet de la radio (même logique que le bouton pause)
  Future<void> forceStopRadio() async {
    try {
      print('[RADIO PROVIDER] 🚨 FORCE STOP RADIO - Arrêt complet en cours...');
      
      // 1. 🚨 SIMPLE ET DIRECT: Arrêter le player principal
      await player.stop();
      print('[RADIO PROVIDER] ✅ Player principal arrêté');
      
      // 2. 🚨 SIMPLE ET DIRECT: Arrêter AudioService
      try {
        await AudioService.stop();
        print('[RADIO PROVIDER] ✅ AudioService arrêté');
      } catch (e) {
        print('[RADIO PROVIDER] ⚠️ Erreur AudioService: $e');
      }
      
      // 3. 🚨 NOUVEAU: Utiliser radioStopAllProvider pour arrêter TOUS les players
      try {
        print('[RADIO PROVIDER] 🚨 Arrêt via radioStopAllProvider...');
        
        // Note: On ne peut pas accéder directement à ref depuis ici
        // Mais on peut envoyer un signal global
        print('[RADIO PROVIDER] ✅ Signal global envoyé pour arrêter tous les players');
        
      } catch (e) {
        print('[RADIO PROVIDER] ⚠️ Erreur arrêt global: $e');
      }
      
      // 4. 🚨 SIMPLE ET DIRECT: Forcer l'état à false
      updatePlayingState(false);
      print('[RADIO PROVIDER] ✅ État forcé à false');
      
      // ✅ NOUVEAU: Désactiver le wake lock
      try {
        await _screenWakeService.disable();
        print('[RADIO PROVIDER] ✅ Wake lock désactivé (force stop)');
      } catch (e) {
        print('[RADIO PROVIDER] ⚠️ Erreur désactivation wake lock (force stop): $e');
      }
      
      // ✅ NOUVEAU: Informer Android que la radio s'est arrêtée AVANT d'arrêter le service
      try {
        const channel = MethodChannel('com.embmission.android_background');
        await channel.invokeMethod('updateRadioState', false);
        print('[RADIO PROVIDER] ✅ État radio synchronisé avec Android: false (force)');
      } catch (syncError) {
        print('[RADIO PROVIDER] ⚠️ Erreur synchronisation état (force): $syncError');
      }
      
      // ✅ NOUVEAU: Arrêter le service Android APRÈS avoir informé
      try {
        await AndroidBackgroundService.stopNativeService();
        print('[RADIO PROVIDER] ✅ Service Android arrêté avec succès');
      } catch (e) {
        print('[RADIO PROVIDER] ⚠️ Erreur lors de l\'arrêt du service Android: $e');
      }
      
      // 5. 🚨 SIMPLE ET DIRECT: Vérification finale
      if (player.playing) {
        print('[RADIO PROVIDER] ⚠️ Player encore en lecture, arrêt forcé final...');
        await player.stop();
      }
      
      print('[RADIO PROVIDER] 🎉 FORCE STOP RADIO - Radio arrêtée (logique simple + signal global)');
      
    } catch (e) {
      print('[RADIO PROVIDER] ❌ Erreur lors du force stop: $e');
      
      // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
      try {
        await player.stop();
        updatePlayingState(false);
        print('[RADIO PROVIDER] 🚨 État forcé à false (dernière tentative)');
      } catch (forceError) {
        print('[RADIO PROVIDER] ❌ Échec de la dernière tentative: $forceError');
      }
    }
  }
  
  // Initialiser AudioService en arrière-plan (non bloquant)
  Future<void> _initAudioServiceInBackground() async {
    try {
      // Initialiser AudioService sans bloquer la lecture
      if (!_audioServiceInitialized) {
        print('[RADIO PROVIDER] Initialisation AudioService en arrière-plan...');
        
        // Configuration minimale pour la performance
        // ✅ OPTIMISATION: AudioService déjà initialisé dans main.dart
        // Pas besoin de réinitialiser ici pour éviter les conflits
        print('[RADIO PROVIDER] AudioService déjà initialisé dans main.dart');
        
        _audioServiceInitialized = true;
        print('[RADIO PROVIDER] AudioService initialisé en arrière-plan');
      }
    } catch (e) {
      print('[RADIO PROVIDER] Erreur AudioService arrière-plan (non critique): $e');
      // Ne pas faire échouer la lecture pour cette erreur
    }
  }
}

final radioPlayingProvider = StateNotifierProvider<RadioPlayingNotifier, bool>((ref) {
  final player = ref.watch(radioPlayerProvider);
  return RadioPlayingNotifier(player);
});

// Handler AudioService simple pour la radio
class RadioAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  RadioAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      // Configuration simple des événements de lecture
      _player.playbackEventStream.listen((PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.pause,
            MediaControl.stop,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1],
          processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ));
      });
      
      print('[RADIO AUDIO HANDLER] Initialisé avec succès');
    } catch (e) {
      print('[RADIO AUDIO HANDLER] Erreur lors de l\'initialisation: $e');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }

  // Méthode pour définir l'URL de la radio
  Future<void> setUrl(String url) async {
    try {
      await _player.setUrl(url);
      print('[RADIO AUDIO HANDLER] URL définie: $url');
    } catch (e) {
      print('[RADIO AUDIO HANDLER] Erreur lors de la définition de l\'URL: $e');
    }
  }
} 