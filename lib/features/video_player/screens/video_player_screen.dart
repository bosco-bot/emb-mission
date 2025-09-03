import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:emb_mission/core/data/local_models.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String? title;
  final String? author;
  final String? videoUrl;
  final ValueNotifier<Map<int, bool>>? favoriteStatusNotifier;
  final String? date;
  final String? description;
  final int? startPosition; // en secondes

  VideoPlayerScreen({
    Key? key,
    required this.contentId,
    this.title,
    this.author,
    this.videoUrl,
    this.favoriteStatusNotifier,
    this.date,
    this.description,
    this.startPosition,
  }) : super(key: key) {
    print('[VIDEO HIVE] VideoPlayerScreen construit (video_player/screens)');
  }

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  YoutubePlayerController? _ytController;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isYoutubeControllerDisposed = false; // Flag pour suivre l'état du contrôleur YouTube
  Duration _lastSavedPosition = Duration.zero;
  static const Duration _saveInterval = Duration(seconds: 5);
  final TextEditingController _commentController = TextEditingController();
  Timer? _progressTimer;

  bool isYoutubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  // Méthode helper pour vérifier si le contrôleur YouTube est valide
  bool get _isYoutubeControllerValid {
    return _ytController != null && !_isYoutubeControllerDisposed;
  }

  // Fonction helper pour arrêter la radio live
  Future<void> _stopRadioIfPlaying() async {
    final radioPlayer = ref.read(radioPlayerProvider);
    final radioPlaying = ref.read(radioPlayingProvider);
    
    if (radioPlaying) {
      print('[VIDEO_PLAYER] Arrêt complet de la radio live avant lancement vidéo');
      try {
        // Arrêter le player audio
        await radioPlayer.stop();
        // Mettre à jour l'état du provider
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        // Forcer l'arrêt complet via la méthode stopRadio
        await ref.read(radioPlayingProvider.notifier).stopRadio();
        print('[VIDEO_PLAYER] Radio live arrêtée avec succès');
      } catch (e) {
        print('[VIDEO_PLAYER] Erreur lors de l\'arrêt de la radio: $e');
      }
    }
  }

  /// Extrait l'ID d'une URL YouTube
  String? _extractYouTubeId(String url) {
    try {
    final uri = Uri.parse(url);
      
      // Format: https://www.youtube.com/watch?v=VIDEO_ID
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v']!;
      }
      
      // Format: https://youtu.be/VIDEO_ID
      if (uri.pathSegments.isNotEmpty && (url.contains('youtu.be') || url.contains('youtube.com'))) {
        final lastSegment = uri.pathSegments.last;
        if (lastSegment.isNotEmpty && lastSegment.length == 11) {
          return lastSegment;
        }
      }
      
      // Format: https://www.youtube.com/embed/VIDEO_ID
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
        return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
      }
      
      return null;
    } catch (e) {
      print('[YOUTUBE] Erreur extraction ID: $e');
      return null;
    }
  }

  // Méthode pour restaurer la position YouTube de manière plus fiable
  void _restoreYoutubePosition(int positionToSeek) {
    if (positionToSeek <= 0 || !_isYoutubeControllerValid) return;
    
    print('[VIDEO YOUTUBE] Tentative de restauration à $positionToSeek secondes');
    
    // Attendre que le lecteur soit prêt
    Future.delayed(Duration(milliseconds: 2000), () async {
      if (_isYoutubeControllerValid && mounted) {
        try {
          print('[VIDEO YOUTUBE] Lecteur prêt, exécution du seek');
          await _ytController!.seekTo(seconds: positionToSeek.toDouble());
          print('[VIDEO YOUTUBE] Seek effectué à $positionToSeek secondes');
          
          // Vérifier après un délai si le seek a fonctionné
          Future.delayed(Duration(milliseconds: 1500), () async {
            if (_isYoutubeControllerValid) {
              try {
                final currentPos = await _ytController!.currentTime;
                print('[VIDEO YOUTUBE] Position vérifiée: ${currentPos.toInt()} secondes');
                
                // Si le seek n'a pas fonctionné, réessayer une dernière fois
                if (currentPos < positionToSeek - 20) {
                  print('[VIDEO YOUTUBE] Seek échoué, dernière tentative...');
                  await _ytController!.seekTo(seconds: positionToSeek.toDouble());
                }
              } catch (e) {
                print('[VIDEO YOUTUBE] Erreur vérification position: $e');
              }
            }
          });
        } catch (e) {
          print('[VIDEO YOUTUBE] Erreur lors du seek: $e');
        }
      }
    });
  }

  // Méthode pour charger la progression depuis Hive pour YouTube
  Future<int> _loadProgressFromHive() async {
    final box = Hive.box('progress');
    final id = int.tryParse(widget.contentId);
    if (id == null) return 0;
    
    final existing = box.values.cast<LocalProgress?>().firstWhere(
      (p) => p?.contentId == id,
      orElse: () => null,
    );
    
    if (existing != null && existing.position > 0) {
      print('[VIDEO YOUTUBE] Progression trouvée dans Hive: ${existing.position} secondes');
      return existing.position;
    }
    
    return 0;
  }

  @override
  void initState() {
    super.initState();
    print('[VIDEO HIVE] initState appelé');
    print('[VIDEO HIVE] startPosition: ${widget.startPosition}');
    print('[VIDEO HIVE] videoUrl: ${widget.videoUrl}');
    print('[VIDEO HIVE] isYoutubeUrl: ${isYoutubeUrl(widget.videoUrl ?? '')}');
    
    // Arrêter la radio live si elle joue
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _stopRadioIfPlaying();
    });
    
    // ✅ NOUVEAU: Mettre à jour les commentaires locaux quand l'utilisateur se connecte
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateLocalComments();
    });
    
    if (widget.videoUrl != null && isYoutubeUrl(widget.videoUrl!)) {
      final videoId = _extractYouTubeId(widget.videoUrl!);
      print('[VIDEO HIVE] YouTube videoId: $videoId');
      if (videoId != null) {
        _ytController = YoutubePlayerController(
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
          ),
        );

        // Charger la vidéo
        _ytController!.loadVideoById(
          videoId: videoId,
          startSeconds: 0.0,
        );
        
        // Pour youtube_player_iframe, on utilise un timer pour suivre la progression
        _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          if (_isYoutubeControllerValid && _isPlaying) {
            try {
              final pos = await _ytController!.currentTime;
              final posDuration = Duration(seconds: pos.toInt());
              if ((posDuration - _lastSavedPosition).inSeconds.abs() >= _saveInterval.inSeconds) {
                _lastSavedPosition = posDuration;
                _saveProgressCloud(posDuration);
                _saveProgressHive();
              }
            } catch (e) {
              print('[VIDEO YOUTUBE] Erreur récupération position: $e');
            }
          }
        });
        
        // Reprise à la position sauvegardée pour YouTube
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          print('[VIDEO YOUTUBE] Début restauration position');
          // Priorité au startPosition passé en paramètre (depuis "En cours d'écoute")
          int positionToSeek = 0;
          if (widget.startPosition != null && widget.startPosition! > 0) {
            positionToSeek = widget.startPosition!;
            debugPrint('[VIDEO YOUTUBE] Utilisation startPosition: $positionToSeek secondes');
          } else {
            // Fallback sur Hive (même logique que pour les vidéos normales)
            positionToSeek = await _loadProgressFromHive();
            
            // Si pas dans Hive, essayer SharedPreferences
            if (positionToSeek == 0) {
              final prefs = await SharedPreferences.getInstance();
              final key = 'progress_${widget.contentId}';
              final saved = prefs.getInt(key);
              print('[VIDEO YOUTUBE] Sauvegarde SharedPreferences trouvée: $saved');
              if (saved != null && saved > 0) {
                positionToSeek = saved;
                debugPrint('[VIDEO YOUTUBE] Utilisation SharedPreferences: $positionToSeek secondes');
              }
            }
          }
          
          print('[VIDEO YOUTUBE] Position finale à seek: $positionToSeek');
          if (positionToSeek > 0) {
            _restoreYoutubePosition(positionToSeek);
          }
        });
      }
      _isInitialized = true;
    } else {
      // Pour les vidéos normales, utiliser la logique existante
      _restoreProgressIfNeeded();
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl ?? ''))
        ..initialize().then((_) async {
          print('[VIDEO NORMALE] Contrôleur initialisé');
          setState(() {
            _isInitialized = true;
          });
        });
      _controller.addListener(() {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
        // Sauvegarde régulière de la progression
        final pos = _controller.value.position;
        if ((pos - _lastSavedPosition).inSeconds.abs() >= _saveInterval.inSeconds) {
          _lastSavedPosition = pos;
          _saveProgressCloud(pos);
        }
      });
    }
  }

  Future<void> _restoreProgressIfNeeded() async {
    // Cette fonction n'est utilisée que pour les vidéos normales
    // La restauration YouTube est gérée directement dans initState
    if (isYoutubeUrl(widget.videoUrl ?? '')) {
      return;
    }
    
    print('[VIDEO NORMALE] _restoreProgressIfNeeded appelé');
    print('[VIDEO NORMALE] startPosition: ${widget.startPosition}');
    
    // Priorité au startPosition passé en paramètre
    int positionToSeek = 0;
    if (widget.startPosition != null && widget.startPosition! > 0) {
      positionToSeek = widget.startPosition!;
      print('[VIDEO NORMALE] Utilisation startPosition: $positionToSeek secondes');
    } else {
      // Fallback sur la sauvegarde locale
      final prefs = await SharedPreferences.getInstance();
      final key = 'progress_${widget.contentId}';
      final saved = prefs.getInt(key);
      print('[VIDEO NORMALE] Sauvegarde locale trouvée: $saved');
      debugPrint('[VIDEO] Tentative restauration locale: key=$key, valeur=$saved');
      if (saved != null && saved > 0) {
        positionToSeek = saved;
        print('[VIDEO NORMALE] Utilisation sauvegarde locale: $positionToSeek secondes');
      }
    }
    
    print('[VIDEO NORMALE] Position finale à seek: $positionToSeek');
    if (positionToSeek > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_isInitialized && _controller.value.isInitialized) {
          await _controller.seekTo(Duration(seconds: positionToSeek));
          debugPrint('[VIDEO] Restauration locale effectuée: seek à $positionToSeek secondes');
        }
      });
    }
  }

  Future<void> _saveProgressCloud(Duration position) async {
    final userId = ref.read(userIdProvider);
    final contentId = widget.contentId;
    debugPrint('[VIDEO] saveProgressCloud: userId=$userId, contentId=$contentId, position=${position.inSeconds}');
    if (userId == null || userId.isEmpty || contentId.isEmpty) {
      debugPrint('[VIDEO] Annulation sauvegarde: userId ou contentId manquant');
      return;
    }
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_listens_contents?userId=$userId&contentId=$contentId&position=${position.inSeconds}');
    debugPrint('[VIDEO] Appel API: $url');
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      debugPrint('[VIDEO] Succès sauvegarde cloud');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('progress_$contentId');
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('progress_$contentId', position.inSeconds);
      debugPrint('[VIDEO] Sauvegarde locale de la progression (cloud KO): $e, valeur=${position.inSeconds}');
    }
  }

  Future<void> _saveProgressHive() async {
    final box = Hive.box('progress');
    final id = int.tryParse(widget.contentId);
    if (id == null) return;
    
         // Récupérer la position selon le type de vidéo
     int position;
     int duration;
     if (isYoutubeUrl(widget.videoUrl ?? '')) {
       try {
         if (_isYoutubeControllerValid) {
           position = (await _ytController!.currentTime).toInt();
         } else {
           position = 0;
         }
         duration = 0; // YouTube iframe ne fournit pas facilement la durée totale
       } catch (e) {
         position = 0;
         duration = 0;
       }
     } else {
      position = _controller.value.position.inSeconds;
      final durationValue = _controller.value.duration;
      duration = durationValue?.inSeconds ?? 0;
    }
    
    final title = widget.title ?? '';
    final author = widget.author ?? '';
    final fileUrl = widget.videoUrl ?? '';
    final category = 'Replays';
    print('[VIDEO HIVE] Sauvegarde: id=$id, position=$position, duration=$duration, category=$category');
    final existing = box.values.cast<LocalProgress?>().firstWhere(
      (p) => p?.contentId == id,
      orElse: () => null,
    );
    if (existing != null) {
      existing.position = position;
      existing.duration = duration;
      existing.title = title;
      existing.author = author;
      existing.fileUrl = fileUrl;
      existing.category = category;
      existing.updatedAt = DateTime.now();
      existing.needsSync = true;
      await existing.save();
    } else {
      await box.add(LocalProgress(
        contentId: id,
        position: position,
        isCompleted: false,
        updatedAt: DateTime.now(),
        needsSync: true,
        duration: duration,
        title: title,
        author: author,
        fileUrl: fileUrl,
        category: category,
      ));
    }
    // LOG TOUTE LA BOX HIVE
    print('[VIDEO HIVE][DUMP] Progress box:');
    for (var p in box.values) {
      if (p is LocalProgress) {
        print('[VIDEO HIVE][DUMP] id=${p.contentId}, cat=${p.category}, pos=${p.position}, dur=${p.duration}, title=${p.title}');
      }
    }
  }



  @override
  void dispose() {
    print('[VIDEO HIVE] dispose called');
    _progressTimer?.cancel();
    _commentController.dispose();
    
    // Sauvegarder la progression pour tous les types de vidéos
    _saveProgressHive();
    
    if (!isYoutubeUrl(widget.videoUrl ?? '')) {
      _controller.dispose();
    } else {
      // Fermer le contrôleur YouTube de manière sécurisée
      if (_ytController != null) {
        try {
          _ytController!.close();
          _ytController = null; // Marquer comme fermé
          _isYoutubeControllerDisposed = true; // Marquer comme disposé
        } catch (e) {
          print('[VIDEO YOUTUBE] Erreur lors de la fermeture du contrôleur: $e');
          _isYoutubeControllerDisposed = true; // Marquer comme disposé même en cas d'erreur
        }
      }
    }
    super.dispose();
  }

  bool get isFavorite {
    final id = int.tryParse(widget.contentId);
    if (id != null && widget.favoriteStatusNotifier != null) {
      return widget.favoriteStatusNotifier!.value[id] ?? false;
    }
    return false;
  }

  void _toggleFavorite() async {
    final id = int.tryParse(widget.contentId);
    if (id == null) return;
    
    // Sauvegarder dans Hive (même logique que dans les autres écrans)
    final box = Hive.box('favorites');
    final existing = box.values.cast<LocalFavorite?>().firstWhere(
      (fav) => fav?.contentId == id,
      orElse: () => null,
    );
    
    final current = widget.favoriteStatusNotifier?.value[id] ?? false;
    final newFav = !current;
    
    if (existing != null) {
      existing.isFavorite = newFav;
      existing.needsSync = true;
      await existing.save();
    } else {
      await box.add(LocalFavorite(
        contentId: id,
        isFavorite: newFav,
        updatedAt: DateTime.now(),
        needsSync: true,
      ));
    }
    
    // Mettre à jour le notifier
    if (widget.favoriteStatusNotifier != null) {
      widget.favoriteStatusNotifier!.value = {
        ...widget.favoriteStatusNotifier!.value,
        id: newFav,
      };
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print('[VIDEO HIVE] build appelé (video_player/screens)');
    final theme = Theme.of(context);
     return Scaffold(
       backgroundColor: Colors.white,
       resizeToAvoidBottomInset: false,
       appBar: AppBar(
         backgroundColor: const Color(0xFF4CB6FF),
         elevation: 0,
         leading: IconButton(
           icon: const Icon(Icons.arrow_back, color: Colors.white),
           onPressed: () => Navigator.of(context).pop(),
         ),
         title: Text(
           widget.title ?? 'Lecteur vidéo',
           style: const TextStyle(
             color: Colors.white,
             fontSize: 18,
             fontWeight: FontWeight.w500,
           ),
         ),
         actions: [
           IconButton(
             icon: const Icon(Icons.share, color: Colors.white),
             onPressed: () {
               final text = 'Titre : ${widget.title ?? ''}\nAuteur : ${widget.author ?? ''}\n${widget.videoUrl ?? ''}';
               Share.share(text);
             },
           ),
         ],
       ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFE3F2FD),
              child: Column(
                children: [
                  _buildVideoCard(),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildInteractionButtons(),
                ],
              ),
            ),
            _buildCommentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
                     if (widget.videoUrl != null && isYoutubeUrl(widget.videoUrl!) && _isYoutubeControllerValid)
             YoutubePlayerScaffold(
               controller: _ytController!,
               aspectRatio: 16 / 9,
               builder: (context, player) {
                 return player;
               },
             )
          else if (_controller.value.hasError)
            Text(
              'Impossible de lire la vidéo.\nVérifiez le lien ou le format.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            )
          else if (!_isInitialized)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: VideoPlayer(_controller),
                      ),
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Color(0xFF64B5F6),
                          backgroundColor: Colors.white54,
                          bufferedColor: Colors.grey.shade400,
                        ),
                      ),
                                             Center(
                         child: IconButton(
                           iconSize: 64,
                           icon: Icon(
                             _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                             color: Colors.white.withOpacity(0.8),
                           ),
                           onPressed: () {
                             if (isYoutubeUrl(widget.videoUrl ?? '')) {
                               // Contrôle manuel pour YouTube avec vérification de sécurité
                               if (_isYoutubeControllerValid) {
                                 if (_isPlaying) {
                                   _ytController!.pauseVideo();
                                 } else {
                                   _ytController!.playVideo();
                                 }
                                 setState(() {
                                   _isPlaying = !_isPlaying;
                                 });
                               } else {
                                 print('[VIDEO YOUTUBE] Contrôleur fermé, impossible de contrôler la lecture');
                               }
                             } else {
                               setState(() {
                                 _isPlaying ? _controller.pause() : _controller.play();
                               });
                             }
                           },
                         ),
                       ),
                    ],
                  ),
                ),
                // Affichage de la durée courante et totale
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_controller.value.position), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      Text(_formatDuration(_controller.value.duration), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text(
            widget.title ?? 'Vidéo',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.author ?? 'Auteur inconnu',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          if (widget.date != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.date!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
          if (widget.description != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInteractionButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.grey,
            label: 'Favoris',
            onTap: _toggleFavorite,
          ),
          _buildInteractionButton(
            icon: Icons.share,
            color: Colors.blue,
            label: 'Partager',
            onTap: () {
              final text = 'Titre : ${widget.title ?? ''}\nAuteur : ${widget.author ?? ''}\n${widget.videoUrl ?? ''}';
              Share.share(text);
            },
          ),
          _buildInteractionButton(
            icon: Icons.chat_bubble_outline,
            color: Colors.green,
            label: 'Commenter',
            onTap: () {
              final userId = ref.read(userIdProvider) ?? '';
              _showCommentsBottomSheet(context, widget.contentId, userId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    final box = Hive.box('comments');
    final localComments = box.values.cast<LocalComment>().where((c) => c.contentId == int.tryParse(widget.contentId)).toList();
    final userId = ref.read(userIdProvider) ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF5F5F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<Comment>>(
            future: CommentService().fetchComments(widget.contentId, userId),
            builder: (context, snapshot) {
              final backendComments = snapshot.data ?? [];
              final allComments = [
                ...localComments.where((c) => c.needsSync),
                ...backendComments.map((comment) => LocalComment(
                      contentId: int.tryParse(widget.contentId) ?? 0,
                      userId: comment.userId,
                      text: comment.content,
                      createdAt: comment.createdAt,
                      needsSync: false,
                    )),
              ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Trier du plus récent au plus ancien
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commentaires (${allComments.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (allComments.isEmpty)
                    const Text('Aucun commentaire pour ce contenu.')
                  else
                    ...allComments.map((comment) => _buildCommentItem(
                          avatarUrl: _getUserAvatar(comment.userId), // ✅ NOUVEAU: Récupérer l'avatar
                          name: _getUserName(comment.userId), // ✅ NOUVEAU: Récupérer le nom
                          time: _formatCommentTime(comment.createdAt),
                          comment: comment.text,
                        )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  // ✅ NOUVELLE MÉTHODE: Récupérer l'avatar de l'utilisateur
  String _getUserAvatar(String userId) {
    // Si c'est l'utilisateur connecté, utiliser son avatar
    final currentUserId = ref.read(userIdProvider);
    if (userId == currentUserId) {
      final userAvatar = ref.read(userAvatarProvider);
      if (userAvatar != null && userAvatar.isNotEmpty) {
        return userAvatar;
      }
    }
    
    // Sinon, utiliser l'avatar par défaut
    return 'assets/images/default_avatar.png';
  }

  // ✅ NOUVELLE MÉTHODE: Récupérer le nom de l'utilisateur
  String _getUserName(String userId) {
    // Si c'est l'utilisateur connecté, utiliser son nom
    final currentUserId = ref.read(userIdProvider);
    if (userId == currentUserId) {
      final userName = ref.read(userNameProvider);
      if (userName != null && userName.isNotEmpty) {
        return userName;
      }
    }
    
    // Sinon, afficher l'ID utilisateur ou un nom par défaut
    return userId.isNotEmpty ? 'Utilisateur $userId' : 'Utilisateur';
  }

  // ✅ NOUVELLE MÉTHODE: Mettre à jour les commentaires locaux quand l'utilisateur se connecte
  Future<void> _updateLocalComments() async {
    try {
      final currentUserId = ref.read(userIdProvider);
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final box = Hive.box('comments');
        final localComments = box.values.cast<LocalComment>().where((c) => c.userId == 'local').toList();
        
        if (localComments.isNotEmpty) {
          print('[COMMENT] 🔄 Mise à jour de ${localComments.length} commentaires locaux...');
          
          for (final comment in localComments) {
            comment.userId = currentUserId;
            comment.needsSync = true; // Marquer pour synchronisation
            await comment.save();
            print('[COMMENT] ✅ Commentaire local mis à jour: ${comment.text}');
          }
          
          // Forcer le rafraîchissement de l'écran
          setState(() {});
          print('[COMMENT] ✅ Tous les commentaires locaux mis à jour');
        }
      }
    } catch (e) {
      print('[COMMENT] ❌ Erreur lors de la mise à jour des commentaires locaux: $e');
    }
  }

  Widget _buildCommentItem({
    required String avatarUrl,
    required String name,
    required String time,
    required String comment,
  }) {
    // ✅ NOUVEAU: Gestion intelligente de l'avatar
    Widget avatarWidget;
    
    if (avatarUrl.isNotEmpty && avatarUrl != 'assets/images/default_avatar.png') {
      if (avatarUrl.startsWith('data:image')) {
        // ✅ Gestion des images base64
        try {
          final bytes = base64Decode(avatarUrl.split(',')[1]);
          avatarWidget = CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200], // ✅ Fond neutre
            backgroundImage: MemoryImage(bytes),
          );
        } catch (e) {
          print('❌ Erreur décodage base64: $e');
          avatarWidget = CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200], // ✅ Fond neutre
            backgroundImage: const AssetImage('assets/images/default_avatar.png'),
          );
        }
      } else if (avatarUrl.startsWith('http')) {
        // ✅ URL réseau
        avatarWidget = CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[200], // ✅ Fond neutre
          backgroundImage: NetworkImage(avatarUrl),
        );
      } else {
        // ✅ Fallback vers l'avatar par défaut
        avatarWidget = CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[200], // ✅ Fond neutre
          backgroundImage: const AssetImage('assets/images/default_avatar.png'),
        );
      }
    } else {
      // ✅ Avatar par défaut
      avatarWidget = CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[200], // ✅ Fond neutre
        backgroundImage: const AssetImage('assets/images/default_avatar.png'),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatarWidget, // ✅ Utilisation du widget avatar intelligent
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
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

  void _showCommentsBottomSheet(BuildContext context, String videoId, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Fonction pour rafraîchir l'écran principal
        void refreshMainScreen() {
          if (mounted) {
            setState(() {});
          }
        }
        final TextEditingController _commentController = TextEditingController();
        // Remplace par ton provider d'avatar utilisateur si besoin
        final userAvatar = null;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 0, right: 0, top: 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Padding(
                    padding: EdgeInsets.only(left: 16, top: 16),
                    child: Text('Commentaires', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  )),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.transparent,
                          backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                              ? NetworkImage(userAvatar)
                              : null,
                          child: (userAvatar == null || userAvatar.isEmpty)
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Partager votre réflexion...',
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: _commentController.text.trim().isEmpty ? Colors.grey : Colors.blue),
                          onPressed: _commentController.text.trim().isEmpty
                              ? null
                              : () async {
                                  final content = _commentController.text.trim();
                                  if (content.isNotEmpty) {
                                    final box = Hive.box('comments');
                                    final comment = LocalComment(
                                      contentId: int.tryParse(videoId) ?? 0,
                                      userId: userId.isEmpty ? 'local' : userId,
                                      text: content,
                                      createdAt: DateTime.now(),
                                      needsSync: userId.isEmpty,
                                    );
                                    await box.add(comment);
                                    
                                    // Si l'utilisateur est connecté, envoyer immédiatement au backend
                                    if (userId.isNotEmpty) {
                                      try {
                                        final success = await CommentService().postComment(videoId, userId, content);
                                        if (success) {
                                          // Marquer comme synchronisé
                                          comment.needsSync = false;
                                          await comment.save();
                                        }
                                      } catch (e) {
                                        print('[COMMENT] Erreur synchronisation: $e');
                                        // Garder needsSync = true pour retry plus tard
                                      }
                                    }
                                    
                                    _commentController.clear();
                                    Navigator.of(context).pop();
                                    // Forcer le rafraîchissement de l'écran principal
                                    refreshMainScreen();
                                  }
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}

// Modèle Comment adapté au format API (identique à player_screen)
class Comment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final String? avatarUrl;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.avatarUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    String userName = '';
    String? avatarUrl;
    if (json['avatar'] is List && (json['avatar'] as List).isNotEmpty) {
      final avatar = json['avatar'][0];
      userName = avatar['nameavatar'] ?? '';
      avatarUrl = avatar['urlavatar'];
    }
    return Comment(
      id: json['id'].toString(),
      userId: json['id_user'].toString(),
      userName: userName,
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      avatarUrl: avatarUrl,
    );
  }
}

// Service minimal pour les commentaires (identique à player_screen)
class CommentService {
  Future<List<Comment>> fetchComments(String videoId, String userId) async {
    final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/view_contents_comments?id_user=$userId&idcontents=$videoId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'true' && data['alldatacontentscomments'] != null) {
        return (data['alldatacontentscomments'] as List).map((json) => Comment.fromJson(json)).toList();
      }
    }
    return [];
  }

  Future<bool> postComment(String videoId, String userId, String content) async {
    final response = await http.post(
      Uri.parse('https://embmission.com/mobileappebm/api/save_contents_comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idcontents': int.tryParse(videoId) ?? videoId,
        'id_user': userId,
        'contentscomments': content,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == 'true';
    }
    return false;
  }
} 