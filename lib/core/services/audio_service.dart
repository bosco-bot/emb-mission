import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';

/// État du lecteur audio
enum AudioPlayerState {
  initial,
  loading,
  playing,
  paused,
  stopped,
  error,
}

/// Service pour gérer la lecture audio
class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayerState _state = AudioPlayerState.initial;
  String? _currentAudioUrl;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  ProviderContainer? _container;
  Timer? _reconnectTimer;
  bool _shouldBePlaying = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  void setProviderContainer(ProviderContainer container) {
    _container = container;
  }

  /// État actuel du lecteur
  AudioPlayerState get state => _state;
  
  /// URL de l'audio en cours de lecture
  String? get currentAudioUrl => _currentAudioUrl;
  
  /// Durée totale de l'audio
  Duration get duration => _duration;
  
  /// Position actuelle dans l'audio
  Duration get position => _position;
  
  /// Initialise le service
  Future<void> initialize() async {
    // Configurer la session audio pour la lecture continue
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false, // Ne pas mettre en pause quand d'autres apps jouent
    ));

    // Écouter les changements d'état du lecteur
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      print('[AUDIO SERVICE] playerStateStream: playing=\u001b[32m${playerState.playing}\u001b[0m, processingState=${playerState.processingState}');
      
      if (playerState.playing) {
        _state = AudioPlayerState.playing;
        print('[AUDIO SERVICE] _state -> playing');
        _container?.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.playing;
      } else {
        if (playerState.processingState == ProcessingState.completed) {
          _state = AudioPlayerState.stopped;
          print('[AUDIO SERVICE] _state -> stopped');
          _container?.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.stopped;
          
          // Si c'est une radio et qu'elle devrait continuer, redémarrer
          if (_shouldBePlaying && _currentAudioUrl != null && _isRadioUrl(_currentAudioUrl!)) {
            print('[AUDIO SERVICE] Radio terminée, redémarrage automatique...');
            _scheduleReconnect();
          }
        } else if (playerState.processingState == ProcessingState.ready) {
          _state = AudioPlayerState.paused;
          print('[AUDIO SERVICE] _state -> paused');
          _container?.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.paused;
        } else if (playerState.processingState == ProcessingState.loading) {
          _state = AudioPlayerState.loading;
          print('[AUDIO SERVICE] _state -> loading');
          _container?.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.loading;
        } else if (playerState.processingState == ProcessingState.idle) {
          // Si le player est en erreur et qu'on devrait jouer une radio, essayer de reconnecter
          if (_shouldBePlaying && _currentAudioUrl != null && _isRadioUrl(_currentAudioUrl!)) {
            print('[AUDIO SERVICE] Player en erreur, tentative de reconnexion...');
            _scheduleReconnect();
          }
        }
      }
    });

    // Écouter les changements de durée
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        print('[AUDIO SERVICE] duration: $_duration');
      }
    });

    // Écouter les changements de position
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      // print('[AUDIO SERVICE] position: $_position');
    });

    // Gérer les interruptions audio
    session.interruptionEventStream.listen((event) {
      print('[AUDIO SERVICE] Interruption audio: ${event.begin}, ${event.type}');
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Réduire le volume temporairement
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Mettre en pause
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Restaurer le volume
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Reprendre la lecture si c'était une radio
            if (_shouldBePlaying && _currentAudioUrl != null && _isRadioUrl(_currentAudioUrl!)) {
              playRadioBackground(_currentAudioUrl!);
            }
            break;
        }
      }
    });

    // Gérer les changements de focus audio
    session.becomingNoisyEventStream.listen((_) {
      print('[AUDIO SERVICE] Écouteurs débranchés, pause automatique');
      pause();
    });
  }

  // Vérifier si c'est une URL de radio
  bool _isRadioUrl(String url) {
    return url.contains('stream') || 
           url.contains('radio') || 
           url.contains('icecast') || 
           url.contains('zeno.fm') ||
           url.contains('aac') ||
           url.contains('mp3');
  }

  // Planifier une tentative de reconnexion
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_shouldBePlaying && _currentAudioUrl != null) {
        print('[AUDIO SERVICE] Tentative de reconnexion automatique...');
        playRadioBackground(_currentAudioUrl!);
      }
    });
  }

  /// Joue un audio à partir d'une URL
  Future<void> play(String audioUrl) async {
    print('[AUDIO SERVICE] play demandé pour $audioUrl');
    try {
      print('[AUDIO SERVICE] _currentAudioUrl=$audioUrl, _state=$_state');
      if (_currentAudioUrl != audioUrl) {
        _state = AudioPlayerState.loading;
        print('[AUDIO SERVICE] _state -> loading (nouvelle URL)');
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        _currentAudioUrl = audioUrl;
        print('[AUDIO SERVICE] setUrl terminé');
      }
      if (_audioPlayer.processingState == ProcessingState.completed) {
        print('[AUDIO SERVICE] seek to zero (reset)');
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play();
      _state = AudioPlayerState.playing;
      print('[AUDIO SERVICE] _audioPlayer.play() appelé, _state -> playing');
    } catch (e) {
      _state = AudioPlayerState.error;
      print('[AUDIO SERVICE] ERREUR lors du play: $e');
      rethrow;
    }
  }

  /// Joue la radio en arrière-plan sans limite de temps
  Future<void> playRadioBackground(String radioUrl) async {
    print('[AUDIO SERVICE] playRadioBackground demandé pour $radioUrl');
    try {
      _shouldBePlaying = true;
      _currentAudioUrl = radioUrl;
      
      // Arrêter le player actuel s'il joue
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      
      // ✅ NOUVELLE OPTIMISATION: Configuration ultra-rapide pour le streaming
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(radioUrl)),
        preload: false, // ⚡ Désactivé pour un démarrage plus rapide
      );
      
      // ✅ OPTIMISATION: Configuration minimale pour la performance
      await _audioPlayer.setLoopMode(LoopMode.off); // Pas de boucle pour la radio live
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSpeed(1.0); // ✅ Correction: setSpeed au lieu de setPlaybackRate
      
      // ✅ OPTIMISATION: Démarrer la lecture immédiatement
      await _audioPlayer.play();
      print('[AUDIO SERVICE] Radio démarrée en arrière-plan: $radioUrl');
      
      // ✅ OPTIMISATION: Configuration AudioService en arrière-plan (non bloquant)
      _configureAudioServiceInBackground();
      
    } catch (e) {
      print('[AUDIO SERVICE] Erreur lors du démarrage de la radio: $e');
      _shouldBePlaying = false;
      _currentAudioUrl = null;
      rethrow;
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Démarrage ultra-rapide de la radio
  Future<void> playRadioUltraFast(String radioUrl) async {
    print('[AUDIO SERVICE] 🚀 playRadioUltraFast demandé pour $radioUrl');
    try {
      _shouldBePlaying = true;
      _currentAudioUrl = radioUrl;
      
      // 🚀 OPTIMISATION: Arrêt ultra-rapide du player actuel
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      
      // 🚀 OPTIMISATION: Configuration ultra-rapide pour le streaming
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(radioUrl)),
        preload: false, // ⚡ Désactivé pour un démarrage plus rapide
      );
      
      // 🚀 OPTIMISATION: Configuration ultra-minimale pour la performance
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setLoopMode(LoopMode.off);
      
      // 🚀 OPTIMISATION: Démarrage immédiat avec timeout ultra-agressif
      await _audioPlayer.play().timeout(
        const Duration(milliseconds: 250), // ⚡ Timeout ultra-agressif réduit de 400ms à 250ms
        onTimeout: () {
          print('[AUDIO SERVICE ULTRA-FAST] ⚠️ Timeout ultra-agressif atteint');
          throw TimeoutException('Démarrage ultra-rapide trop long');
        },
      );
      
      print('[AUDIO SERVICE ULTRA-FAST] 🚀 Radio démarrée ultra-rapidement: $radioUrl');
      
      // 🚀 OPTIMISATION: Configuration AudioService en arrière-plan (non bloquant)
      _configureAudioServiceInBackground();
      
    } catch (e) {
      print('[AUDIO SERVICE ULTRA-FAST] Erreur lors du démarrage ultra-rapide: $e');
      _shouldBePlaying = false;
      _currentAudioUrl = null;
      rethrow;
    }
  }
  
  // ✅ NOUVELLE MÉTHODE: Configuration AudioService en arrière-plan
  Future<void> _configureAudioServiceInBackground() async {
    try {
      // Configuration minimale pour la performance
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      
      print('[AUDIO SERVICE] Configuration AudioService terminée en arrière-plan');
      
    } catch (e) {
      print('[AUDIO SERVICE] Erreur configuration AudioService (non critique): $e');
      // Ne pas faire échouer la lecture pour cette erreur
    }
  }

  /// Met en pause la lecture
  Future<void> pause() async {
    print('[AUDIO SERVICE] pause demandé');
    await _audioPlayer.pause();
    _state = AudioPlayerState.paused;
  }

  /// Reprend la lecture
  Future<void> resume() async {
    await _audioPlayer.play();
    _state = AudioPlayerState.playing;
  }

  /// Arrête la lecture
  Future<void> stop() async {
    await _audioPlayer.stop();
    _state = AudioPlayerState.stopped;
  }

  /// Arrête spécifiquement la radio
  Future<void> stopRadio() async {
    print('[AUDIO SERVICE] stopRadio demandé');
    _shouldBePlaying = false;
    _reconnectTimer?.cancel();
    await _audioPlayer.stop();
    _state = AudioPlayerState.stopped;
    _currentAudioUrl = null;
    print('[AUDIO SERVICE] Radio arrêtée');
  }

  /// Avance ou recule dans l'audio
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Libère les ressources
  Future<void> dispose() async {
    _shouldBePlaying = false;
    _reconnectTimer?.cancel();
    _playerStateSubscription?.cancel();
    await _audioPlayer.dispose();
  }

  AudioPlayer get audioPlayer => _audioPlayer;
}

/// Provider pour le service audio
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.initialize();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Provider pour l'état du lecteur audio
final audioPlayerStateProvider = StateProvider<AudioPlayerState>((ref) {
  return AudioPlayerState.initial;
});

/// Provider pour l'URL de l'audio en cours de lecture
final currentAudioUrlProvider = StateProvider<String?>((ref) {
  return null;
});

/// Provider pour la durée de l'audio
final audioDurationProvider = StateProvider<Duration>((ref) {
  return Duration.zero;
});

/// Provider pour la position dans l'audio
final audioPositionProvider = StateProvider<Duration>((ref) {
  return Duration.zero;
});


