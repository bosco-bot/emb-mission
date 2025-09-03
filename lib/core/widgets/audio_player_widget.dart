import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/audio_service.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

/// Widget pour le lecteur audio
class AudioPlayerWidget extends ConsumerWidget {
  final String audioUrl;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final bool showTitle;
  final bool mini;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.showTitle = true,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Utilisation du provider sans stocker la référence dans une variable
    ref.watch(audioServiceProvider);
    final playerState = ref.watch(audioPlayerStateProvider);
    final currentUrl = ref.watch(currentAudioUrlProvider);
    final duration = ref.watch(audioDurationProvider);
    final position = ref.watch(audioPositionProvider);
    
    final isPlaying = playerState == AudioPlayerState.playing && 
                      currentUrl == audioUrl;
    final isLoading = playerState == AudioPlayerState.loading && 
                      currentUrl == audioUrl;
    final isError = playerState == AudioPlayerState.error && currentUrl == audioUrl;
    
    final color = accentColor ?? AppTheme.primaryColor;
    
    // LOG pour debug
    print('[AUDIO WIDGET] build: playerState=$playerState, currentUrl=$currentUrl, audioUrl=$audioUrl, isPlaying=$isPlaying, isLoading=$isLoading, isError=$isError');
    
    return Container(
      padding: EdgeInsets.all(mini ? 8 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et sous-titre
          if (showTitle) ...[
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: mini ? 14 : 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: mini ? 12 : 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            SizedBox(height: mini ? 8 : 12),
          ],
          
          // Contrôles du lecteur
          Row(
            children: [
              // Bouton de lecture/pause
              InkWell(
                onTap: () => _handlePlayPause(ref, context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: mini ? 36 : 48,
                  height: mini ? 36 : 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isError
                        ? Icon(Icons.error, color: Colors.red, size: mini ? 20 : 28)
                        : (isPlaying || isLoading)
                            ? Icon(Icons.pause, color: Colors.white, size: mini ? 20 : 28)
                            : Icon(Icons.play_arrow, color: Colors.white, size: mini ? 20 : 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Barre de progression
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _calculateProgress(position, duration),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Durée
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: mini ? 10 : 12,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: mini ? 10 : 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Gère l'action de lecture/pause
  void _handlePlayPause(WidgetRef ref, BuildContext context) async {
    final audioService = ref.read(audioServiceProvider);
    final playerState = ref.read(audioPlayerStateProvider);
    final currentUrl = ref.read(currentAudioUrlProvider);
    
    print('[AUDIO WIDGET] _handlePlayPause: playerState=$playerState, currentUrl=$currentUrl, audioUrl=$audioUrl');

    if (currentUrl != audioUrl || playerState == AudioPlayerState.error) {
      // Arrêter la radio live si elle joue avant de lancer l'audio
      final radioPlayer = ref.read(radioPlayerProvider);
      final radioPlaying = ref.read(radioPlayingProvider);
      
      if (radioPlaying) {
        print('[AUDIO WIDGET] Arrêt de la radio live avant lecture audio');
        try {
          await radioPlayer.stop();
          ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          print('[AUDIO WIDGET] Radio live arrêtée avec succès');
        } catch (e) {
          print('[AUDIO WIDGET] Erreur lors de l\'arrêt de la radio: $e');
        }
      }
      
      // Réinitialise l'état si on change d'audio ou si on était en erreur
      ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.loading;
      ref.read(currentAudioUrlProvider.notifier).state = audioUrl;
      try {
        await audioService.play(audioUrl);
        ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.playing;
        print('[AUDIO WIDGET] play lancé, état mis à playing');
      } catch (e) {
        ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.error;
        print('[AUDIO WIDGET] erreur lors du play: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la lecture audio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (playerState == AudioPlayerState.playing) {
      await audioService.pause();
      ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.paused;
      print('[AUDIO WIDGET] pause demandé, état mis à paused');
    } else if (playerState == AudioPlayerState.paused) {
      await audioService.resume();
      ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.playing;
      print('[AUDIO WIDGET] resume demandé, état mis à playing');
    }
  }

  /// Calcule la progression de la lecture
  double _calculateProgress(Duration position, Duration duration) {
    if (duration.inMilliseconds == 0) {
      return 0.0;
    }
    return position.inMilliseconds / duration.inMilliseconds;
  }

  /// Formate la durée au format mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
