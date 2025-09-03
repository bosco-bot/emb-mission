import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/screen_wake_provider.dart';
import '../../../core/providers/radio_player_provider.dart';

class TVLiveScreen extends ConsumerStatefulWidget {
  final String streamUrl;
  final String tvName;

  const TVLiveScreen({super.key, required this.streamUrl, required this.tvName});

  @override
  ConsumerState<TVLiveScreen> createState() => _TVLiveScreenState();
}

class _TVLiveScreenState extends ConsumerState<TVLiveScreen> with WidgetsBindingObserver {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlaying = false;

  // Fonction helper pour arrêter la radio live
  Future<void> _stopRadioIfPlaying() async {
    final radioPlayer = ref.read(radioPlayerProvider);
    final radioPlaying = ref.read(radioPlayingProvider);
    
    if (radioPlaying) {
      print('[TV_LIVE] Arrêt complet de la radio live avant lancement TV');
      try {
        // Arrêter le player audio
        await radioPlayer.stop();
        // Mettre à jour l'état du provider
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        // Forcer l'arrêt complet via la méthode stopRadio
        await ref.read(radioPlayingProvider.notifier).stopRadio();
        print('[TV_LIVE] Radio live arrêtée avec succès');
      } catch (e) {
        print('[TV_LIVE] Erreur lors de l\'arrêt de la radio: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Plein écran immersif pour la TV Live
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() async {
    // Arrêter la radio live si elle joue avant d'initialiser la TV
    await _stopRadioIfPlaying();
    
    _videoPlayerController = VideoPlayerController.network(widget.streamUrl)
      ..initialize().then((_) {
        setState(() {});
        _setupVideoPlayer();
      });
  }

  void _setupVideoPlayer() {
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: 16 / 9,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: false,
      showControls: true,
    );
    
    // Écouter les changements d'état du player vidéo
    _videoPlayerController.addListener(_onVideoPlayerStateChanged);
  }
  
  void _onVideoPlayerStateChanged() {
    final isPlaying = _videoPlayerController.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
      _updateScreenWake();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // L'app revient au premier plan
        if (_isPlaying) {
          ref.read(screenWakeStateProvider.notifier).enableForVideoPlayback(true);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // L'app passe en arrière-plan ou est fermée
        ref.read(screenWakeStateProvider.notifier).disable();
        break;
      default:
        break;
    }
  }

  void _toggleScreenWake() {
    ref.read(screenWakeStateProvider.notifier).toggle();
    
    // Afficher un message à l'utilisateur
    final isEnabled = ref.read(screenWakeStateProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEnabled 
            ? '🔆 Écran de veille activé - L\'écran restera allumé'
            : '🌙 Écran de veille désactivé - L\'écran peut s\'éteindre',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isEnabled ? Colors.green : Colors.orange,
      ),
    );
  }

  void _updateScreenWake() {
    ref.read(screenWakeStateProvider.notifier).enableForVideoPlayback(_isPlaying);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // ✅ Arrêter la lecture vidéo avant de disposer
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    }
    
    // ✅ Restaure l'interface complète
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    ref.read(screenWakeStateProvider.notifier).disable();
    _videoPlayerController.removeListener(_onVideoPlayerStateChanged);
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: _chewieController != null && _videoPlayerController.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : const CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF4CB6FF),
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // ✅ Arrêter la lecture vidéo avant de quitter
              if (_videoPlayerController.value.isPlaying) {
                _videoPlayerController.pause();
              }
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          const Text(
            'TV Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              // Bouton écran de veille avec indicateur visuel
              Consumer(
                builder: (context, ref, child) {
                  final isScreenWakeEnabled = ref.watch(screenWakeStateProvider);
                  return Container(
                    decoration: BoxDecoration(
                      color: isScreenWakeEnabled ? Colors.green.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isScreenWakeEnabled ? Icons.brightness_high : Icons.brightness_low,
                        color: isScreenWakeEnabled ? Colors.green : Colors.white,
                      ),
                      onPressed: _toggleScreenWake,
                      tooltip: isScreenWakeEnabled ? 'Désactiver écran de veille' : 'Activer écran de veille',
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  final url = widget.streamUrl;
                  Share.share('Regarde la TV en direct sur EMB Mission : $url');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
} 