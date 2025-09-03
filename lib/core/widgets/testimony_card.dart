import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:emb_mission/core/models/testimony.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

/// Widget pour afficher une carte de témoignage
class TestimonyCard extends StatefulWidget {
  final Testimony testimony;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onFavoriteChanged;

  const TestimonyCard({
    super.key,
    required this.testimony,
    required this.onTap,
    this.onLike,
    this.onFavoriteChanged,
  });

  @override
  State<TestimonyCard> createState() => _TestimonyCardState();
}

class _TestimonyCardState extends State<TestimonyCard> {
  // Assure qu'un seul témoignage joue à la fois
  static _TestimonyCardState? _currentlyPlayingCard;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _currentTestimonyId = '';

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      // Arrêter automatiquement à la fin (ne pas boucler)
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _setupAudioPlayer();
    } catch (e) {
      print('Erreur d\'initialisation AudioPlayer: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = false;
        });

        // Si ce player vient de s'arrêter/pauser, libérer le jeton global
        if (state != PlayerState.playing && _currentlyPlayingCard == this) {
          _currentlyPlayingCard = null;
        }
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        if (_currentlyPlayingCard == this) {
          _currentlyPlayingCard = null;
        }
      }
    });
  }

  Future<void> _pauseSelf() async {
    try {
      await _audioPlayer.pause();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (widget.testimony.audioUrl == null || widget.testimony.audioUrl!.isEmpty) {
      return;
    }

    try {
      // Arrêter la radio live si elle joue (même logique que PlayerScreen)
      try {
        final container = ProviderScope.containerOf(context);
        final isRadioPlaying = container.read(radioPlayingProvider);
        if (isRadioPlaying) {
          try {
            final radioPlayer = container.read(radioPlayerProvider);
            await radioPlayer.stop();
          } catch (_) {}
          try {
            await container.read(radioPlayingProvider.notifier).stopRadio();
          } catch (_) {}
          container.read(radioPlayingProvider.notifier).updatePlayingState(false);
        }
      } catch (_) {}

      // Met en pause tout autre témoignage en cours
      if (_currentlyPlayingCard != null && _currentlyPlayingCard != this) {
        await _currentlyPlayingCard!._pauseSelf();
        _currentlyPlayingCard = null;
      }

      if (_currentTestimonyId != widget.testimony.id) {
        // Nouvel audio à charger
        _currentTestimonyId = widget.testimony.id;
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(widget.testimony.audioUrl!));
        _currentlyPlayingCard = this;
      } else {
        // Même audio, toggle play/pause
        if (_isPlaying) {
          await _audioPlayer.pause();
          if (_currentlyPlayingCard == this) {
            _currentlyPlayingCard = null;
          }
        } else {
          await _audioPlayer.resume();
          _currentlyPlayingCard = this;
        }
      }
    } catch (e) {
      print('Erreur audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de lecture audio: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final userId = container.read(userIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour gérer les favoris.')),
      );
      return;
    }
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favorietestimony');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'id_temoignage': int.tryParse(widget.testimony.id) ?? widget.testimony.id,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (widget.onFavoriteChanged != null) widget.onFavoriteChanged!();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Favori mis à jour')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la gestion du favori. Code: \\${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec l'auteur et la catégorie
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Photo de profil
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getCategoryColor().withAlpha(51),
                    backgroundImage: widget.testimony.authorImageUrl != null
                        ? AssetImage(widget.testimony.authorImageUrl!)
                        : null,
                    child: widget.testimony.authorImageUrl == null
                        ? Text(
                            widget.testimony.authorName[0].toUpperCase(),
                            style: TextStyle(
                              color: _getCategoryColor(),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Nom et catégorie
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.testimony.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor().withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.testimony.category.displayName,
                            style: TextStyle(
                              color: _getCategoryColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date
                  Text(
                    _formatDate(widget.testimony.createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Contenu du témoignage
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.testimony.inputMode == InputMode.text
                  ? Text(
                      widget.testimony.content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : _buildAudioPlayer(),
            ),
            // Boutons d'action
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Bouton J'aime
                  InkWell(
                    onTap: () => _toggleFavorite(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Icon(
                            widget.testimony.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.testimony.isLiked
                                ? AppTheme.primaryColor
                                : Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.testimony.likeCount.toString(),
                            style: TextStyle(
                              color: widget.testimony.isLiked
                                  ? AppTheme.primaryColor
                                  : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bouton Partager
                  InkWell(
                    onTap: () {
                      final testimony = widget.testimony;
                      final text = [
                        testimony.authorName,
                        '',
                        testimony.content,
                        if (testimony.audioUrl != null && testimony.audioUrl!.isNotEmpty)
                          '\nAudio : \\${testimony.audioUrl}',
                        '\nPartagé via EMB Mission App'
                      ].join('\n');
                      Share.share(text);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.share,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit le lecteur audio pour les témoignages audio
  Widget _buildAudioPlayer() {
    final isCurrentAudio = _currentTestimonyId == widget.testimony.id;
    final progress = _duration.inMilliseconds > 0 
        ? _position.inMilliseconds / _duration.inMilliseconds 
        : 0.0;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _getCategoryColor().withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bouton de lecture
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(),
                shape: BoxShape.circle,
              ),
              child: _isLoading && isCurrentAudio
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Icon(
                      _isPlaying && isCurrentAudio ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Barre de progression
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Barre de progression
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6 * progress,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Durée
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCurrentAudio ? _formatDuration(_position) : '0:00',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      isCurrentAudio ? _formatDuration(_duration) : '0:00',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Retourne la couleur associée à la catégorie du témoignage
  Color _getCategoryColor() {
    switch (widget.testimony.category) {
      case TestimonyCategory.healing:
        return AppTheme.healingColor;
      case TestimonyCategory.prayer:
        return AppTheme.prayerColor;
      case TestimonyCategory.family:
        return AppTheme.familyColor;
      case TestimonyCategory.work:
        return AppTheme.workColor;
    }
  }

  /// Formate la date de création du témoignage
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Il y a ${difference.inMinutes} min';
      } else {
        return 'Il y a ${difference.inHours} h';
      }
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
