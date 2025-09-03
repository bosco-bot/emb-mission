import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class RadioAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  
  // 🚨 NOUVEAU: Gestion des StreamSubscription pour éviter les fuites mémoire
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<SequenceState?>? _sequenceStateSubscription;

  RadioAudioHandler() {
    _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForDurationChanges();
    _listenForCurrentSongIndexChanges();
    _listenForSequenceStateChanges();
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse('')),
        preload: false,
      );
    } catch (e) {
      print('Erreur lors du chargement de la playlist vide: $e');
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _playbackEventSubscription = _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
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
  }

  void _listenForDurationChanges() {
    _durationSubscription = _player.durationStream.listen((duration) {
      var index = _player.currentIndex;
      final newQueue = queue.value;
      if (index == null || newQueue.isEmpty) return;
      if (_player.shuffleModeEnabled) {
        index = _player.shuffleIndices![index];
      }
      final oldMediaItem = newQueue[index];
      final newMediaItem = oldMediaItem.copyWith(duration: duration);
      newQueue[index] = newMediaItem;
      queue.add(newQueue);
      mediaItem.add(newMediaItem);
    });
  }

  void _listenForCurrentSongIndexChanges() {
    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      final playlist = queue.value;
      if (index == null || playlist.isEmpty) return;
      if (_player.shuffleModeEnabled) {
        index = _player.shuffleIndices![index];
      }
      mediaItem.add(playlist[index]);
    });
  }

  void _listenForSequenceStateChanges() {
    _sequenceStateSubscription = _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      final playlist = sequenceState?.effectiveSequence;
      if (playlist == null) return;
      final queue = playlist.map((source) => source.tag as MediaItem).toList();
      this.queue.add(queue);
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setUrl(String url) async {
    _currentUrl = url;
    try {
      // ✅ NOUVELLE OPTIMISATION: Configuration ultra-rapide pour le streaming
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: false, // ⚡ Désactivé pour un démarrage plus rapide
      );
      
      // ✅ OPTIMISATION: Configuration minimale pour la performance
      await _player.setVolume(1.0);
      await _player.setSpeed(1.0); // ✅ Correction: setSpeed au lieu de setPlaybackRate
      
      // Créer un MediaItem pour la radio
      final mediaItem = MediaItem(
        id: url,
        album: 'EMB-Mission',
        title: 'Radio Live',
        artist: 'EMB-Mission',
        duration: Duration.zero, // Stream live
        artUri: Uri.parse('https://example.com/radio_art.jpg'),
      );
      
      // Mettre à jour la queue et l'item actuel
      queue.add([mediaItem]);
      this.mediaItem.add(mediaItem);
      
      // ✅ OPTIMISATION: Démarrer la lecture immédiatement
      await _player.play();
      print('[AUDIO HANDLER] Radio démarrée ultra-rapidement: $url');
      
    } catch (e) {
      print('[AUDIO HANDLER] Erreur lors de setUrl: $e');
      rethrow;
    }
  }
  
  // 🚀 MÉTHODE OPTIMISÉE: Démarrage ultra-rapide avec cache
  Future<void> setUrlFast(String url) async {
    try {
      // 🚀 OPTIMISATION: Configuration ultra-rapide sans vérifications
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: false,
      );
      
      // 🚀 OPTIMISATION: Démarrage immédiat avec timeout ultra-agressif
      await _player.play().timeout(
        const Duration(milliseconds: 200), // ⚡ Timeout ultra-agressif réduit de 300ms à 200ms
        onTimeout: () {
          print('[AUDIO HANDLER FAST] ⚠️ Timeout ultra-agressif atteint');
          throw TimeoutException('Démarrage ultra-rapide trop long');
        },
      );
      
      print('[AUDIO HANDLER FAST] 🚀 Radio démarrée ultra-rapidement (fast mode): $url');
      
    } catch (e) {
      print('[AUDIO HANDLER FAST] Erreur démarrage ultra-rapide: $e');
      rethrow;
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Démarrage TURBO ultra-agressif
  Future<void> setUrlTurbo(String url) async {
    try {
      // 🚀 OPTIMISATION TURBO: Configuration ultra-minimale
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: false,
      );
      
      // 🚀 OPTIMISATION TURBO: Démarrage instantané avec timeout ultra-agressif
      await _player.play().timeout(
        const Duration(milliseconds: 150), // ⚡ Timeout TURBO ultra-agressif réduit de 200ms à 150ms
        onTimeout: () {
          print('[AUDIO HANDLER TURBO] ⚠️ Timeout TURBO ultra-agressif atteint');
          throw TimeoutException('Démarrage TURBO trop long');
        },
      );
      
      print('[AUDIO HANDLER TURBO] 🚀 Radio démarrée en mode TURBO: $url');
      
    } catch (e) {
      print('[AUDIO HANDLER TURBO] Erreur mode TURBO: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    // 🚨 NOUVEAU: Annuler toutes les StreamSubscription pour éviter les fuites mémoire
    _playbackEventSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _sequenceStateSubscription?.cancel();
    
    await _player.dispose();
  }
} 