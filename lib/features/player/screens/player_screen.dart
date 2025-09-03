import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/widgets/home_back_button.dart';
import 'package:emb_mission/core/services/audio_service.dart' as LocalAudioService;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/data/local_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart' as ExternalAudioService;
import 'package:go_router/go_router.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';


class PlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String? title;
  final String? author;
  final String? fileUrl;
  final ValueNotifier<Map<int, bool>>? favoriteStatusNotifier;
  final int? startPosition; // en secondes

  const PlayerScreen({
    super.key,
    required this.contentId,
    this.title,
    this.author,
    this.fileUrl,
    this.favoriteStatusNotifier,
    this.startPosition,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // Valeurs fictives pour la démonstration
  final double currentPosition = 15.5; // en minutes
  final double totalDuration = 45.0; // en minutes
  bool isPlaying = false;
  Duration _lastSavedPosition = Duration.zero;
  Duration _lastKnownPosition = Duration.zero;
  static const Duration _saveInterval = Duration(seconds: 5);
  late final AudioPlayer player;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    player = ref.read(LocalAudioService.audioServiceProvider).audioPlayer;
    _restoreProgressFromHive();
    _restoreFavoriteFromHive();
    _initAudio();
    player.positionStream.listen((pos) {
      _lastKnownPosition = pos;
    });
    
    // ✅ NOUVEAU: Mettre à jour les commentaires locaux quand l'utilisateur se connecte
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateLocalComments();
    });
  }

  void _restoreProgressFromHive() async {
    final box = Hive.box('progress');
    final id = int.tryParse(widget.contentId);
    if (id != null) {
      final progress = box.values.cast<LocalProgress?>().firstWhere(
        (p) => p?.contentId == id,
        orElse: () => null,
      );
      if (progress != null && progress.position > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await player.seek(Duration(seconds: progress.position));
        });
      }
    }
  }

  void _restoreFavoriteFromHive() async {
    final box = Hive.box('favorites');
    final id = int.tryParse(widget.contentId);
    if (id != null) {
      final fav = box.values.cast<LocalFavorite?>().firstWhere(
        (f) => f?.contentId == id,
        orElse: () => null,
      );
      if (fav != null) {
        setState(() {
          _isFavorite = fav.isFavorite;
        });
        
        // Mettre à jour aussi le favoriteStatusNotifier pour la synchronisation
        if (widget.favoriteStatusNotifier != null) {
          widget.favoriteStatusNotifier!.value = {
            ...widget.favoriteStatusNotifier!.value,
            id: fav.isFavorite,
          };
        }
      }
    }
  }

  bool _isFavorite = false;

  // Fonction helper pour arrêter la radio live (VERSION SIMPLIFIÉE ET DIRECTE)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[PLAYER DEBUG] _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[PLAYER] 🚨 ARRÊT DIRECT ET FORCÉ de la radio live');
      
      try {
        // 🎯 MÉTHODE SIMPLE ET DIRECTE: Arrêter TOUT de force
        
        // 1. Arrêter le player principal
        final radioPlayer = ref.read(radioPlayerProvider);
        if (radioPlayer.playing) {
          await radioPlayer.stop();
          print('[PLAYER] ✅ Player principal arrêté');
        }
        
        // 2. Forcer l'état à false IMMÉDIATEMENT
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[PLAYER] ✅ État forcé à false');
        
        // 3. Arrêter AudioService de force
        try {
          await ExternalAudioService.AudioService.stop();
          print('[PLAYER] ✅ AudioService.stop() réussi');
        } catch (e) {
          print('[PLAYER] ⚠️ AudioService.stop() échoué: $e');
        }
        
        // 4. Attendre un peu et vérifier
        await Future.delayed(const Duration(milliseconds: 300));
        
        // 5. Vérifier l'état final
        final finalState = ref.read(radioPlayingProvider);
        print('[PLAYER] État final après arrêt: $finalState');
        
        if (finalState) {
          print('[PLAYER] ⚠️ État toujours true, forcer une dernière fois...');
          ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        }
        
        print('[PLAYER] 🎯 Radio live arrêtée avec succès (méthode directe)');
        
      } catch (e) {
        print('[PLAYER] ❌ Erreur lors de l\'arrêt direct: $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        try {
          print('[PLAYER] 🚨 Dernière tentative désespérée...');
          ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
          print('[PLAYER] 🚨 État forcé à false (dernière tentative)');
        } catch (finalError) {
          print('[PLAYER] 💥 ÉCHEC TOTAL: $finalError');
        }
      }
    } else {
      print('[PLAYER DEBUG] Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  Future<void> _toggleFavoriteHive() async {
    final box = Hive.box('favorites');
    final id = int.tryParse(widget.contentId);
    if (id == null) return;
    final existing = box.values.cast<LocalFavorite?>().firstWhere(
      (f) => f?.contentId == id,
      orElse: () => null,
    );
    if (existing != null) {
      existing.isFavorite = !existing.isFavorite;
      existing.updatedAt = DateTime.now();
      existing.needsSync = true;
      await existing.save();
      setState(() { _isFavorite = existing.isFavorite; });
      
      // Mettre à jour aussi le favoriteStatusNotifier pour la synchronisation
      if (widget.favoriteStatusNotifier != null) {
        widget.favoriteStatusNotifier!.value = {
          ...widget.favoriteStatusNotifier!.value,
          id: existing.isFavorite,
        };
      }
    } else {
      await box.add(LocalFavorite(
        contentId: id,
        isFavorite: true,
        updatedAt: DateTime.now(),
        needsSync: true,
      ));
      setState(() { _isFavorite = true; });
      
      // Mettre à jour aussi le favoriteStatusNotifier pour la synchronisation
      if (widget.favoriteStatusNotifier != null) {
        widget.favoriteStatusNotifier!.value = {
          ...widget.favoriteStatusNotifier!.value,
          id: true,
        };
      }
    }
  }

  Future<void> _saveProgressHive(Duration position) async {
    // Vérifier si le widget est encore monté avant d'accéder au contexte
    if (!mounted) {
      print('[PLAYER] ⚠️ Widget démonté, arrêt de la sauvegarde');
      return;
    }
    
    final box = Hive.box('progress');
    final id = int.tryParse(widget.contentId);
    if (id == null) return;
    final duration = player.duration?.inSeconds ?? 0;
    final title = widget.title ?? '';
    final author = widget.author ?? '';
    final fileUrl = widget.fileUrl ?? '';
    
    // Récupération de la catégorie depuis le widget ou une valeur par défaut
    String category = 'Enseignements';
    try {
      if (mounted) {
        category = (ModalRoute.of(context)?.settings.arguments as Map?)?['category'] ?? 'Enseignements';
      }
    } catch (e) {
      print('[PLAYER] ⚠️ Erreur accès contexte: $e, utilisation valeur par défaut');
    }
    final existing = box.values.cast<LocalProgress?>().firstWhere(
      (p) => p?.contentId == id,
      orElse: () => null,
    );
    if (existing != null) {
      existing.position = position.inSeconds;
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
        position: position.inSeconds,
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
  }

  Future<void> _initAudio() async {
    if (widget.fileUrl != null && widget.fileUrl!.isNotEmpty) {
      // 🚨 ARRÊTER LA RADIO AVANT DE LANCER LE CONTENU D'ENSEIGNEMENT
      // Utiliser Future.microtask pour éviter la modification de provider pendant le build
      Future.microtask(() async {
        await _stopRadioIfPlaying();
      });
      
      print('[AUDIO DEBUG] Initialisation audio avec URL: ${widget.fileUrl}');
      print('[AUDIO DEBUG] ContentId: ${widget.contentId}');
      print('[AUDIO DEBUG] StartPosition: ${widget.startPosition}');
      
      try {
        // Vérifier et potentiellement corriger l'URL
        String finalUrl = widget.fileUrl!;
        try {
          final uri = Uri.parse(widget.fileUrl!);
          print('[AUDIO DEBUG] URI parsée: $uri');
          
          // Si l'URL n'a pas de schéma, essayer d'ajouter https://
          if (!uri.hasScheme) {
            finalUrl = 'https://${widget.fileUrl!}';
            print('[AUDIO DEBUG] URL corrigée: $finalUrl');
          }
        } catch (e) {
          print('[AUDIO DEBUG] Erreur parsing URL, tentative de correction...');
          if (!widget.fileUrl!.startsWith('http')) {
            finalUrl = 'https://${widget.fileUrl!}';
            print('[AUDIO DEBUG] URL corrigée: $finalUrl');
          }
        }
        
        // Essayer de charger l'audio
        print('[AUDIO DEBUG] Tentative de chargement avec URL: $finalUrl');
        
        // Vérifier d'abord si l'URL est accessible
        try {
          final response = await http.head(Uri.parse(finalUrl));
          print('[AUDIO DEBUG] Test d\'accessibilité HTTP: ${response.statusCode}');
          if (response.statusCode != 200) {
            throw Exception('URL non accessible: ${response.statusCode}');
          }
        } catch (e) {
          print('[AUDIO DEBUG] Erreur test accessibilité: $e');
          // Continuer quand même, certains serveurs ne supportent pas HEAD
        }
        
        // Essayer de charger l'audio avec gestion d'erreur
        bool audioLoaded = false;
        List<String> urlsToTry = [finalUrl];
        
        // Si l'URL originale était différente, essayer aussi
        if (finalUrl != widget.fileUrl!) {
          urlsToTry.insert(0, widget.fileUrl!);
        }
        
        // Essayer aussi avec http:// si https:// échoue
        if (finalUrl.startsWith('https://')) {
          urlsToTry.add(finalUrl.replaceFirst('https://', 'http://'));
        }
        
        for (String url in urlsToTry) {
          try {
            print('[AUDIO DEBUG] Tentative avec URL: $url');
            await player.setUrl(url);
            print('[AUDIO DEBUG] Audio chargé avec succès: $url');
            audioLoaded = true;
            break;
          } catch (e) {
            print('[AUDIO DEBUG] Échec avec URL: $url, erreur: $e');
            continue;
          }
        }
        
        if (!audioLoaded) {
          throw Exception('Impossible de charger l\'audio avec aucune URL: ${urlsToTry.join(', ')}');
        }
        
        // Restaurer la position si nécessaire
        if (widget.startPosition != null && widget.startPosition! > 0) {
          print('[AUDIO DEBUG] Restauration position: ${widget.startPosition} secondes');
          await player.seek(Duration(seconds: widget.startPosition!));
        }
        
        // Démarrer la lecture
        print('[AUDIO DEBUG] Démarrage de la lecture...');
        await player.play();
        print('[AUDIO DEBUG] Lecture démarrée');
        
        // Écouter la position pour sauvegarder régulièrement
        player.positionStream.listen((position) {
          if ((position - _lastSavedPosition).inSeconds.abs() >= _saveInterval.inSeconds) {
            _lastSavedPosition = position;
            // Vérifier si le widget est encore monté avant de sauvegarder
            if (mounted) {
              _saveProgressHive(position);
            }
          }
        });
        
        // Écouter les erreurs de lecture
        player.playerStateStream.listen((state) {
          print('[AUDIO DEBUG] État du player: $state');
          if (state?.processingState == ProcessingState.completed && state?.playing == false) {
            print('[AUDIO DEBUG] Lecture terminée normalement');
          } else if (state?.processingState == ProcessingState.idle && state?.playing == false) {
            print('[AUDIO ERROR] Player en état idle - possible erreur de source');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Erreur de lecture audio: source error'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        });
        
              } catch (e) {
          print('[AUDIO ERROR] Exception lors de l\'initialisation: $e');
          
          // Analyser l'erreur pour donner un message plus précis
          String errorMessage = 'Erreur de lecture audio';
          if (e.toString().contains('source error')) {
            errorMessage = '❌ Fichier audio corrompu ou inaccessible';
          } else if (e.toString().contains('network')) {
            errorMessage = '❌ Problème de connexion réseau';
          } else if (e.toString().contains('format')) {
            errorMessage = '❌ Format audio non supporté';
          } else if (e.toString().contains('404')) {
            errorMessage = '❌ Fichier audio introuvable sur le serveur';
          } else if (e.toString().contains('403')) {
            errorMessage = '❌ Accès au fichier audio refusé';
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Réessayer',
                  textColor: Colors.white,
                  onPressed: () {
                    _initAudio();
                  },
                ),
              ),
            );
          }
        }
    } else {
      print('[AUDIO ERROR] URL audio vide ou null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Aucune URL audio fournie'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveProgressCloud(Duration position) async {
    final userId = ref.read(userIdProvider);
    final contentId = widget.contentId;
    debugPrint('[AUDIO] saveProgressCloud: userId=$userId, contentId=$contentId, position=${position.inSeconds}');
    if (userId == null || userId.isEmpty || contentId.isEmpty) {
      debugPrint('[AUDIO] Annulation sauvegarde: userId ou contentId manquant');
      return;
    }
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_listens_contents?userId=$userId&contentId=$contentId&position=${position.inSeconds}');
    debugPrint('[AUDIO] Appel API: $url');
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      debugPrint('[AUDIO] Succès sauvegarde cloud');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('progress_$contentId');
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('progress_$contentId', position.inSeconds);
      debugPrint('[AUDIO] Sauvegarde locale de la progression (cloud KO): $e, valeur=${position.inSeconds}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // AppBar secondaire bleue (comme dans video_player_screen.dart)
          _buildSecondaryAppBar(),
          // Contenu principal
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  // AppBar secondaire bleue (comme dans video_player_screen.dart)
  Widget _buildSecondaryAppBar() {
    return Container(
      color: const Color(0xFF4CB6FF),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.go('/contents'),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    widget.title ?? 'Lecture en cours',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  final text = 'Titre : ${widget.title ?? ''}\nAuteur : ${widget.author ?? ''}\n${widget.fileUrl ?? ''}';
                  Share.share(text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Section supérieure avec fond bleu clair
          Container(
            color: const Color(0xFFE3F2FD),
            child: Column(
              children: [
                _buildPlayerCard(),
              ],
            ),
          ),
          // Section avec fond blanc pour les contrôles
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildProgressBar(player),
                _buildControlButtons(ref),
              ],
            ),
          ),
          // Section avec fond blanc pour la BottomBar (comme le lecteur vidéo)
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
    );
  }

  Widget _buildPlayerCard() {
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
          // Bouton play central avec dégradé
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CB6FF), Color(0xFF2196F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CB6FF).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final processingState = state?.processingState;
                final playing = state?.playing ?? false;
                if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                  return const CircularProgressIndicator(color: Colors.white);
                } else if (playing) {
                  return IconButton(
                    icon: const Icon(Icons.pause, size: 60, color: Colors.white),
                    onPressed: () => player.pause(),
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.play_arrow, size: 60, color: Colors.white),
                    onPressed: () => player.play(),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          // Titre de la prière
          Text(
            widget.title ?? 'Prière du matin',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Auteur et source
          Text(
            widget.author ?? 'Pasteur Jean-Marie • EMB Mission',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          // Temps écoulé / durée totale
          Text(
            '${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AudioPlayer player) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.duration ?? Duration.zero;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: const Color(0xFF4CB6FF),
                  inactiveTrackColor: Colors.grey,
                  thumbColor: const Color(0xFF4CB6FF),
                  overlayColor: const Color(0xFF4CB6FF).withOpacity(0.2),
                ),
                child: Slider(
                  value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                  min: 0,
                  max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1,
                  onChanged: (value) {
                    player.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position.inSeconds / 60)),
                    Text(_formatDuration(duration.inSeconds / 60)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButtons(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Bouton précédent
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.skip_previous,
                color: Colors.grey[700],
                size: 28,
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 24),
          // Bouton play/pause principal synchronisé
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF4CB6FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CB6FF).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final processingState = state?.processingState;
                final playing = state?.playing ?? false;
                if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                  return const CircularProgressIndicator(color: Colors.white);
                } else if (playing) {
                  return IconButton(
                    icon: const Icon(Icons.pause, size: 40, color: Colors.white),
                    onPressed: () => player.pause(),
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
                    onPressed: () => player.play(),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 24),
          // Bouton suivant
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.skip_next,
                color: Colors.grey[700],
                size: 28,
              ),
              onPressed: () {},
            ),
          ),
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
            icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.grey,
            label: 'Favoris',
            onTap: _toggleFavoriteHive,
          ),
          _buildInteractionButton(
            icon: Icons.share,
            color: Colors.blue,
            label: 'Partager',
            onTap: () {
              final text = 'Titre : ${widget.title ?? ''}\nAuteur : ${widget.author ?? ''}\n${widget.fileUrl ?? ''}';
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

  String _formatDuration(double minutes) {
    int mins = minutes.floor();
    int secs = ((minutes - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
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

                  const SizedBox(height: 70),
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

  bool get isFavorite {
    final id = int.tryParse(widget.contentId);
    if (id != null && widget.favoriteStatusNotifier != null) {
      return widget.favoriteStatusNotifier!.value[id] ?? false;
    }
    return false;
  }

  void _toggleFavorite() {
    final id = int.tryParse(widget.contentId);
    if (id != null && widget.favoriteStatusNotifier != null) {
      final current = widget.favoriteStatusNotifier!.value[id] ?? false;
      widget.favoriteStatusNotifier!.value = {
        ...widget.favoriteStatusNotifier!.value,
        id: !current,
      };
    }
    setState(() {});
  }

  void _showCommentsBottomSheet(BuildContext context, String audioId, String userId) {
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
        final userAvatar = ref.watch(userAvatarProvider); // Pour l'avatar utilisateur
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
                                      contentId: int.tryParse(audioId) ?? 0,
                                      userId: userId.isEmpty ? 'local' : userId,
                                      text: content,
                                      createdAt: DateTime.now(),
                                      needsSync: userId.isEmpty,
                                    );
                                    await box.add(comment);
                                    
                                    // Si l'utilisateur est connecté, envoyer immédiatement au backend
                                    if (userId.isNotEmpty) {
                                      try {
                                        final success = await CommentService().postComment(audioId, userId, content);
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

  @override
  void dispose() {
    _commentController.dispose();
    // Sauvegarde locale Hive à la fermeture du lecteur audio
    // Mais seulement si le widget est encore monté
    if (mounted) {
      try {
        _saveProgressHive(_lastKnownPosition);
      } catch (e) {
        print('[PLAYER] ⚠️ Erreur lors de la sauvegarde finale: $e');
      }
    }
    player.stop();
    player.pause();
    player.seek(Duration.zero);
    print('DEBUG: PlayerScreen dispose() appelé, player.stop(), pause(), seek(0)');
    super.dispose();
  }


}

// Modèle Comment adapté au format API
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

// Service minimal pour les commentaires
class CommentService {
  Future<List<Comment>> fetchComments(String audioId, String userId) async {
    final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/view_contents_comments?id_user=$userId&idcontents=$audioId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'true' && data['alldatacontentscomments'] != null) {
        return (data['alldatacontentscomments'] as List).map((json) => Comment.fromJson(json)).toList();
      }
    }
    return [];
  }

  Future<bool> postComment(String audioId, String userId, String content) async {
    final response = await http.post(
      Uri.parse('https://embmission.com/mobileappebm/api/save_contents_comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idcontents': int.tryParse(audioId) ?? audioId,
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
