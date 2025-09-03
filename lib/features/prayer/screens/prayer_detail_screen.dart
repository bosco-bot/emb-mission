import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:emb_mission/core/models/prayer.dart';
import 'package:emb_mission/core/services/content_service.dart';
// import 'package:emb_mission/core/widgets/audio_player_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:audio_service/audio_service.dart';

/// Provider pour récupérer les détails d'une prière par ID
final prayerDetailProvider = FutureProvider.family<PrayerDetail, int>((ref, prayerId) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getPrayerDetailById(prayerId);
});

/// Provider pour afficher le player audio
final showAudioPlayerProvider = StateProvider<bool>((ref) => false);

/// Écran de détail d'une prière
class PrayerDetailScreen extends ConsumerStatefulWidget {
  final int prayerId;
  
  const PrayerDetailScreen({
    super.key,
    required this.prayerId,
  });

  @override
  ConsumerState<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends ConsumerState<PrayerDetailScreen> {
  bool isFavorite = false;

  void updateFavorite(bool value) {
    setState(() {
      isFavorite = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prayerAsync = ref.watch(prayerDetailProvider(widget.prayerId));
    return Scaffold(
      backgroundColor: Colors.white,
      body: prayerAsync.when(
        data: (prayer) => _PrayerDetailContent(
          prayer: prayer,
          isFavorite: isFavorite,
          onFavoriteChanged: updateFavorite,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erreur de chargement: $error'),
        ),
      ),

    );
  }

  
}

// Nouveau widget qui gère l'affichage du player audio
class _PrayerDetailContent extends ConsumerStatefulWidget {
  final PrayerDetail prayer;
  final bool isFavorite;
  final ValueChanged<bool> onFavoriteChanged;
  const _PrayerDetailContent({required this.prayer, required this.isFavorite, required this.onFavoriteChanged});
  @override
  ConsumerState<_PrayerDetailContent> createState() => _PrayerDetailContentState();
}

class _PrayerDetailContentState extends ConsumerState<_PrayerDetailContent> {
  bool showFullTranscription = false;
  late bool isFavorite;
  // Player audio local à cette page
  late final AudioPlayer _localPlayer;
  Duration _localDuration = Duration.zero;
  Duration _localPosition = Duration.zero;
  bool _localIsPlaying = false;

  // 🚨 FONCTION ULTRA-SIMPLIFIÉE pour arrêter la radio live (utilise la nouvelle fonction publique)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[PRAYER DETAIL] 🎯 _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[PRAYER DETAIL] 🚨 ARRÊT RADIO NÉCESSAIRE - Utilisation de forceStopRadio()');
      
      try {
        // 🚨 LOGIQUE SIMPLE: Utiliser la fonction publique forceStopRadio()
        await ref.read(radioPlayingProvider.notifier).forceStopRadio();
        print('[PRAYER DETAIL] ✅ forceStopRadio() exécuté avec succès');
        
      } catch (e) {
        print('[PRAYER DETAIL] ❌ Erreur lors de forceStopRadio(): $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[PRAYER DETAIL] 🚨 État forcé à false (dernière tentative)');
      }
    } else {
      print('[PRAYER DETAIL] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  @override
  void initState() {
    super.initState();
    isFavorite = widget.isFavorite;
    // Initialiser le player local
    _localPlayer = AudioPlayer();
    // Charger la source si disponible
    final url = widget.prayer.audioUrl;
    if (url != null && url.isNotEmpty) {
      _localPlayer.setUrl(url);
    }
    // Écouter la durée/position/état pour la barre de progression
    _localPlayer.durationStream.listen((d) {
      if (d != null && mounted) {
        setState(() => _localDuration = d);
      }
    });
    _localPlayer.positionStream.listen((p) {
      if (mounted) {
        setState(() => _localPosition = p);
      }
    });
    _localPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      final completed = state.processingState == ProcessingState.completed;
      setState(() => _localIsPlaying = playing);
      if (completed) {
        // Mettre la position à la fin et permettre la relecture
        setState(() => _localIsPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    // S'assurer que le mini-lecteur s'arrête en quittant la page
    try {
      _localPlayer.stop();
    } catch (_) {}
    _localPlayer.dispose();
    super.dispose();
  }

  void _toggleFavorite() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
      return;
    }
    final idprayer = widget.prayer.id.toString();
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favorie');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'idprayer': idprayer,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          isFavorite = !isFavorite;
        });
        widget.onFavoriteChanged(isFavorite);
        String message = isFavorite ? 'Favori ajouté' : 'Favori supprimé';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la gestion du favori. Code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAudioPlayer = ref.watch(showAudioPlayerProvider);
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // AppBar avec image de fond
              SliverAppBar(
                expandedHeight: 180, // Diminue légèrement la hauteur
                 pinned: true,
                 backgroundColor: const Color(0xFF4CB6FF),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                title: Row(
                  children: [
                     const CircleAvatar(
                      radius: 12,
                       backgroundColor: Colors.red,
                      child: Text(
                        'emb',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Détails Contenu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      final prayer = widget.prayer;
                      final text = '''
${prayer.titre}

${prayer.description}

${prayer.verset.isNotEmpty ? 'Verset : ${prayer.verset}\n' : ''}${prayer.transcription.isNotEmpty ? 'Transcription : ${prayer.transcription}\n' : ''}${prayer.ressourcesLiees.isNotEmpty ? 'Ressources liées :\n' : ''}${prayer.ressourcesLiees.map((r) => '- ${r.titre} (${r.type}) : ${r.url}').join('\n')}
''';
                      Share.share(text);
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                            color: const Color(0xFF4CB6FF),
                    child: Column(
                      children: [
                        Spacer(),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Colors.white30,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Titre avec limitation de taille
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.prayer.titre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Description avec limitation de taille
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                            color: const Color(0xFF3A8FC1),
                          width: double.infinity,
                          child: Text(
                            widget.prayer.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Contenu de la prière
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations sur la durée et la publication
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Row(
                            children: [
                               const Icon(
                                Icons.access_time,
                                size: 20,
                                  color: Color(0xFF4CB6FF),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.prayer.duree > 0)
                                    Text(
                                      'Durée: ${widget.prayer.duree} minutes',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  if (widget.prayer.date.isNotEmpty && widget.prayer.heure.isNotEmpty)
                                    Text(
                                      _getElapsedTime(widget.prayer.date, widget.prayer.heure),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (widget.prayer.statut.toLowerCase() == 'live')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5252),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (widget.prayer.vues > 0)
                                Text(
                                  '${widget.prayer.vues} vues',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                    // Description complète
                    if (widget.prayer.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Description complète',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              constraints: const BoxConstraints(
                                maxHeight: 200, // Limite la hauteur maximale
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  widget.prayer.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            // Player audio intégré sous la description (local à la page)
                            if (showAudioPlayer && (widget.prayer.audioUrl != null && widget.prayer.audioUrl!.isNotEmpty))
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          // Play / Pause
                                          InkWell(
                                            onTap: () async {
                                              // 🚨 ARRÊTER LA RADIO LIVE AVANT LECTURE AUDIO DE PRIÈRE
                                              await _stopRadioIfPlaying();
                                              final state = _localPlayer.playerState;
                                              final isCompleted = state.processingState == ProcessingState.completed ||
                                                  (_localDuration.inMilliseconds > 0 &&
                                                   _localPosition.inMilliseconds + 200 >= _localDuration.inMilliseconds);

                                              if (isCompleted) {
                                                await _localPlayer.seek(Duration.zero);
                                                await _localPlayer.play();
                                                return;
                                              }

                                              if (_localIsPlaying) {
                                                await _localPlayer.pause();
                                              } else {
                                                await _localPlayer.play();
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(24),
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _localIsPlaying ? Icons.pause : Icons.play_arrow,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Barre de progression + temps
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Slider(
                                                  value: _localDuration.inMilliseconds == 0
                                                      ? 0
                                                      : _localPosition.inMilliseconds.clamp(0, _localDuration.inMilliseconds).toDouble(),
                                                  max: (_localDuration.inMilliseconds == 0
                                                      ? 1
                                                      : _localDuration.inMilliseconds).toDouble(),
                                                  onChanged: (v) async {
                                                    final newPos = Duration(milliseconds: v.toInt());
                                                    await _localPlayer.seek(newPos);
                                                  },
                                                  activeColor: Colors.red,
                                                  inactiveColor: Colors.grey.shade300,
                                                ),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(_formatDuration(_localPosition), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                    Text(_formatDuration(_localDuration), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          // Masquer et stopper le player local
                                          ref.read(showAudioPlayerProvider.notifier).state = false;
                                          await _localPlayer.stop();
                                        },
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        label: const Text('Fermer', style: TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (widget.prayer.verset.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '"${widget.prayer.verset}"',
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                    // Ressources liées dynamiques
                    if (widget.prayer.ressourcesLiees.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: const Color(0xFFF5F5F5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              child: Text(
                                'Ressources liées',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...widget.prayer.ressourcesLiees.map((res) => Container(
                              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () async {
                                  final type = res.type.toLowerCase();
                                  final url = res.url;
                                  if (type == 'audio') {
                                    // Affiche le player audio intégré comme le bouton Écouter
                                    ref.read(showAudioPlayerProvider.notifier).state = true;
                                    // Change l'URL audio si besoin (ici, on suppose un seul player, sinon il faut gérer un player par ressource)
                                    // Tu peux adapter pour jouer l'audio de la ressource si besoin
                                    // Ex: ref.read(audioUrlProvider.notifier).state = url;
                                  } else if (type == 'texte') {
                                    // Affiche un dialog avec le texte
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(res.titre),
                                        content: Text(res.note),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Fermer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (type == 'pdf') {
                                    // Ouvre le PDF dans le navigateur
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Impossible d\'ouvrir le PDF.')),
                                      );
                                    }
                                  } else if (type == 'video') {
                                    // Ouvre la vidéo dans le navigateur ou player vidéo (à adapter si tu veux un player intégré)
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Impossible d\'ouvrir la vidéo.')),
                                      );
                                    }
                                  } else if (type == 'lien') {
                                    // Vérifie si c'est un lien interne (book/chapter dans l'URL)
                                    final uri = Uri.tryParse(url);
                                    if (uri != null && uri.queryParameters.containsKey('book') && uri.queryParameters.containsKey('chapter')) {
                                      final book = uri.queryParameters['book'];
                                      final chapter = int.tryParse(uri.queryParameters['chapter'] ?? '1') ?? 1;
                                      if (book != null) {
                                        context.go('/bible?book=$book&chapter=$chapter');
                                        return;
                                      }
                                    }
                                    // Sinon, ouvre dans le navigateur
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Impossible d\'ouvrir le lien.')),
                                      );
                                    }
                                  } else {
                                    // Par défaut, tente d'ouvrir dans le navigateur
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Type de ressource non supporté.')),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: res.type == 'audio' ? const Color(0xFFF3E5F5) : const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          res.type == 'audio' ? Icons.music_note : Icons.book_outlined,
                                          color: res.type == 'audio' ? Colors.purple : Colors.green,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              res.titre,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              res.note,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                    // Transcription dynamique
                    if (widget.prayer.transcription.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Transcription',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                  TextButton(
                                  onPressed: (widget.prayer.fichierTranscription.isNotEmpty) ? () async {
                                      final raw = widget.prayer.fichierTranscription.trim();
                                      print('Lien de téléchargement : ' + raw);
                                      try {
                                        Uri? uri = Uri.tryParse(raw);
                                        if (uri == null) {
                                          throw Exception('URL invalide');
                                        }
                                        if (!uri.hasScheme) {
                                          uri = Uri.parse('https://$raw');
                                        }
                                        // Ouvrir dans une webview intégrée si possible pour ne pas quitter l'app
                                        bool ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
                                        if (!ok) {
                                          ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                        if (!ok) {
                                          throw Exception('launchUrl a renvoyé false');
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Impossible d\'ouvrir le lien de téléchargement.')),
                                        );
                                      }
                                  } : null,
                                  child: Text(
                                      'Télécharger',
                                      style: TextStyle(
                                  color: (widget.prayer.fichierTranscription.isNotEmpty) 
                                          ? const Color(0xFF4CB6FF) 
                                          : Colors.grey.shade400,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showFullTranscription)
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 300, // Limite la hauteur maximale
                                      ),
                                      child: SingleChildScrollView(
                                        child: Text(
                                          '"${widget.prayer.transcription}"',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '"${widget.prayer.transcription.length > 120 ? widget.prayer.transcription.substring(0, 120) + '...' : widget.prayer.transcription}"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 6, // Limite à 6 lignes maximum
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (widget.prayer.transcription.length > 120)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          showFullTranscription = !showFullTranscription;
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        showFullTranscription ? 'Réduire' : 'Lire la suite',
                                         style: const TextStyle(
                 color: Color(0xFF4CB6FF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BottomActionBar(
          prayer: widget.prayer,
          onPlay: () {
            ref.read(showAudioPlayerProvider.notifier).state = true;
          },
          isPlaying: showAudioPlayer,
          isFavorite: isFavorite,
          onToggleFavorite: _toggleFavorite,
        ),
      ],
    );
  }

  String _getElapsedTime(String date, String heure) {
    try {
      final dateTime = DateTime.parse('$date $heure');
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inSeconds < 60) {
        return 'il y a quelques secondes';
      } else if (diff.inMinutes < 60) {
        return 'il y a ${diff.inMinutes} minutes';
      } else if (diff.inHours < 24) {
        return 'il y a ${diff.inHours} heures';
      } else {
        return 'il y a ${diff.inDays} jours';
      }
    } catch (e) {
      return '';
    }
  }
}

// Helpers
String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Barre d'action en bas de l'écran
class BottomActionBar extends StatelessWidget {
  final PrayerDetail prayer;
  final VoidCallback? onPlay;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  
  const BottomActionBar({
    super.key,
    required this.prayer,
    this.onPlay,
    this.isPlaying = false,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    // Vérifier si l'URL audio existe et n'est pas vide
    final hasAudio = prayer.audioUrl != null && prayer.audioUrl!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bouton Écouter - toujours affiché mais grisé si pas d'audio
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: hasAudio && !isPlaying ? onPlay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasAudio ? const Color(0xFF4CB6FF) : Colors.grey.shade300,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow, 
                      color: hasAudio ? Colors.white : Colors.grey.shade600, 
                      size: 24
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Écouter', 
                      style: TextStyle(
                        color: hasAudio ? Colors.white : Colors.grey.shade600, 
                        fontSize: 12
                      )
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bouton Télécharger - toujours affiché mais grisé si pas d'audio
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: hasAudio ? () async {
                  final raw = prayer.audioUrl!.trim();
                  print('Lien audio : $raw');
                  try {
                    Uri? uri = Uri.tryParse(raw);
                    if (uri == null) {
                      throw Exception('URL invalide');
                    }
                    if (!uri.hasScheme) {
                      uri = Uri.parse('https://$raw');
                    }
                    // Ouvrir d'abord dans l'app (webview), sinon en externe
                    bool ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
                    if (!ok) {
                      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    if (!ok) {
                      throw Exception('launchUrl a renvoyé false');
                    }
                  } catch (e) {
                    await Clipboard.setData(ClipboardData(text: raw));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                        'Aucune application trouvée pour ouvrir ce fichier audio. Le lien a été copié dans le presse-papier :\n$raw',
                      )),
                    );
                  }
                } : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: hasAudio ? Colors.grey.shade300 : Colors.grey.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined, 
                      color: hasAudio ? Colors.black54 : Colors.grey.shade400, 
                      size: 24
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Télécharger', 
                      style: TextStyle(
                        color: hasAudio ? Colors.black54 : Colors.grey.shade400, 
                        fontSize: 12
                      )
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bouton Favoris
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: onToggleFavorite,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.black54,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    const Text('Favoris', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
