import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:just_audio/just_audio.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

/// Écran de forum pour les discussions communautaires
class ForumScreen extends ConsumerStatefulWidget {
  final int forumId;
  final String userId;
  const ForumScreen({super.key, required this.forumId, required this.userId});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  bool _loading = true;
  Map<String, dynamic>? _forumData;
  String? _error;
  bool _isWriting = false;
  final TextEditingController _controller = TextEditingController();
  bool isLiked = false;
  bool isPrayed = false;
  bool isShared = false;

  // 🚨 FONCTION ULTRA-SIMPLIFIÉE pour arrêter la radio live (MÊME LOGIQUE QUE CONTENTS_SCREEN)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[FORUM] 🎯 _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[FORUM] 🚨 ARRÊT DIRECT ET FORCÉ de la radio live avant lecture audio de forum');
      
      try {
        // 🎯 MÉTHODE ULTRA-SIMPLE: Arrêter TOUT de force comme dans contents_screen.dart
        
        // 1. Arrêter le player principal de force
        final radioPlayer = ref.read(radioPlayerProvider);
        await radioPlayer.stop();
        print('[FORUM] ✅ Player principal arrêté de force');
        
        // 2. Forcer l'état à false IMMÉDIATEMENT (comme dans contents_screen.dart)
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[FORUM] ✅ État forcé à false immédiatement');
        
        // 3. Arrêter AudioService de force (comme dans contents_screen.dart)
        try {
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          print('[FORUM] ✅ AudioService arrêté via stopRadio()');
        } catch (e) {
          print('[FORUM] ⚠️ stopRadio() échoué: $e');
        }
        
        print('[FORUM] 🎯 Radio live arrêtée avec succès (méthode ultra-simplifiée)');
        
      } catch (e) {
        print('[FORUM] ❌ Erreur lors de l\'arrêt: $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[FORUM] 🚨 État forcé à false (dernière tentative)');
      }
    } else {
      print('[FORUM] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(userIdProvider);
      _fetchForumDetail(userId);
    });
  }

  Future<void> _fetchForumDetail(String? userId) async {
    setState(() { _loading = true; _error = null; });
    final url = Uri.parse('https://embmission.com/mobileappebm/api/detail_msgforum');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_msgforums': widget.forumId, 'id_user': userId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'true' && data['alldataforums'] != null && data['alldataforums'].isNotEmpty) {
          final forum = data['alldataforums'][0];
          setState(() {
            _forumData = forum;
            isLiked = forum['isLikedByCurrentUser'] ?? false;
            isPrayed = forum['isPrayedByCurrentUser'] ?? false;
            isShared = forum['isSharedByCurrentUser'] ?? false;
            _loading = false;
          });
        } else {
          setState(() { _error = "Aucune donnée trouvée"; _loading = false; });
        }
      } else {
        setState(() { _error = "Erreur serveur: ${response.statusCode}"; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Détail du message'),
        leading: const BackButton(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _forumData == null
                  ? const Center(child: Text('Aucune donnée'))
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMainPost(_forumData!),
                                  const SizedBox(height: 24),
                                  Text('Réponses (${(_forumData!['nbrreponses'] as List).isNotEmpty ? _forumData!['nbrreponses'][0]['reponsesforums'] ?? 0 : 0})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  if ((_forumData!['reponses'] as List).isEmpty)
                                    const Text('Aucune réponse pour ce message.')
                                  else
                                    ...(_forumData!['reponses'] as List).map((r) => _buildResponseItem(r)).toList(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildCommentInput(),
                      ],
                    ),
    );
  }

  Widget _buildMainPost(Map<String, dynamic> forum) {
    final avatar = (forum['avatar'] as List).isNotEmpty ? forum['avatar'][0] : null;
    final authorName = avatar != null ? avatar['nameavatar'] ?? '' : '';
    final avatarUrl = avatar != null ? avatar['urlavatar'] : null;
    final date = forum['date_post'] ?? '';
    final content = forum['content'] ?? '';
    final audioUrl = forum['audio_url'] ?? '';
    final likes = (forum['nbrlikeforums'] as List).isNotEmpty ? forum['nbrlikeforums'][0]['likeforums'] ?? 0 : 0;
    final prayers = (forum['nbrsoutienpriere'] as List).isNotEmpty ? forum['nbrsoutienpriere'][0]['soutienpriere'] ?? 0 : 0;
    final shares = (forum['nbrpartageforums'] as List).isNotEmpty ? forum['nbrpartageforums'][0]['partageforums'] ?? 0 : 0;
    final responses = (forum['nbrreponses'] as List).isNotEmpty ? forum['nbrreponses'][0]['reponsesforums'] ?? 0 : 0;
    final views = forum['nbrvues'] ?? 0;
    // Date relative
    String relativeTime = '';
    if (date.isNotEmpty) {
      final parsedDate = DateTime.tryParse(date);
      if (parsedDate != null) {
        relativeTime = timeago.format(parsedDate, locale: 'fr');
      }
    }
    return Consumer(
      builder: (context, ref, _) {
        final userId = ref.watch(userIdProvider);
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(
                          authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            relativeTime,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (content.isNotEmpty)
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      if (audioUrl != null && audioUrl.isNotEmpty &&
                          (audioUrl.endsWith('.mp3') || audioUrl.endsWith('.wav') || audioUrl.endsWith('.aac')))
                        _buildAudioPlayer(audioUrl, 0),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: userId == null ? null : () => _toggleLike(forum, userId),
                            child: _buildActionButtonSvg(
                              svgPath: 'assets/images/coeur.svg',
                              count: likes.toString(),
                              color: isLiked ? Colors.red : Colors.grey,
                              backgroundColor: isLiked ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: userId == null ? null : () => _togglePrayer(forum, userId),
                            child: _buildActionButtonSvg(
                              svgPath: 'assets/images/prières.svg',
                              count: prayers.toString(),
                              color: isPrayed ? Colors.blue : Colors.grey,
                              backgroundColor: isPrayed ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: userId == null ? null : () => _shareForumMessage(forum, userId),
                            child: _buildActionButtonSvg(
                              svgPath: 'assets/images/partager.svg',
                              count: shares.toString(),
                              color: isShared ? Colors.green : Colors.grey,
                              backgroundColor: isShared ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.flag_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$responses réponses • $views vues",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponseItem(Map<String, dynamic> r) {
    final avatar = r['reponseavatar'] ?? {};
    final authorName = avatar['nameavatar'] ?? '';
    final avatarUrl = avatar['urlavatar'];
    final date = r['date_reponse'] ?? '';
    final content = r['content'] ?? '';
    final likeCount = r['likeCount'] ?? 0;
    final isLiked = r['isLikedByCurrentUser'] ?? false;
    final idReponse = r['id_reponse'] ?? r['id'] ?? r['id_post'] ?? r.hashCode;
    // Calcul date relative
    String relativeTime = '';
    if (date.isNotEmpty) {
      final parsedDate = DateTime.tryParse(date);
      if (parsedDate != null) {
        relativeTime = timeago.format(parsedDate, locale: 'fr');
      }
    }
    return Consumer(
      builder: (context, ref, _) {
        final userId = ref.watch(userIdProvider);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.transparent,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              Text(relativeTime, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(content, style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: userId == null ? null : () => _toggleLikeResponse(r, userId, idReponse),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLiked ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/images/coeur.svg',
                              colorFilter: ColorFilter.mode(isLiked ? Colors.red : Colors.grey, BlendMode.srcIn),
                              height: 18,
                              width: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(likeCount.toString(), style: TextStyle(color: isLiked ? Colors.red : Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtonSvg({required String svgPath, required String count, required Color color, required Color backgroundColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            svgPath,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            height: 18,
            width: 18,
          ),
          const SizedBox(width: 4),
          Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final userAvatar = ref.watch(userAvatarProvider); // À adapter selon ton provider d'avatar
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
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Partager votre réflexion...',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: _controller.text.trim().isEmpty ? Colors.grey : Colors.blue),
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () {
                    _sendResponse();
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _sendResponse() async {
    final userId = ref.read(userIdProvider);
    final text = _controller.text.trim();
    if (userId == null || text.isEmpty) return;
    final forumId = widget.forumId;
    final url = Uri.parse('https://embmission.com/mobileappebm/api/savereponsepostforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_user': userId,
        'id_post': forumId,
        'content': text,
      }),
    );
    print('Status code: \\${response.statusCode}');
    print('Réponse API: \\${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true || data['success'] == 'true') {
        setState(() {
          _controller.clear();
        });
        // Rafraîchir la liste des réponses
        final userIdRefresh = ref.read(userIdProvider);
        await _fetchForumDetail(userIdRefresh);
        // Afficher un SnackBar de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Votre réponse a été envoyée avec succès !'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Afficher un SnackBar d'erreur
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors de l'envoi. Veuillez réessayer."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Afficher un SnackBar d'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'envoi. Veuillez réessayer."),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> forum, String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favorieforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_msgforums': forum['id'],
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        setState(() {
          final likeList = forum['nbrlikeforums'] as List;
          int currentLikes = likeList.isNotEmpty ? likeList[0]['likeforums'] ?? 0 : 0;
          if (data['action'] == 'added') {
            if (likeList.isNotEmpty) {
              likeList[0]['likeforums'] = currentLikes + 1;
            }
            isLiked = true;
          } else {
            if (likeList.isNotEmpty && currentLikes > 0) {
              likeList[0]['likeforums'] = currentLikes - 1;
            }
            isLiked = false;
          }
        });
      }
    }
  }

  Future<void> _togglePrayer(Map<String, dynamic> forum, String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_stient_priereforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_msgforums': forum['id'],
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        setState(() {
          final prayerList = forum['nbrsoutienpriere'] as List;
          int currentPrayers = prayerList.isNotEmpty ? prayerList[0]['soutienpriere'] ?? 0 : 0;
          if (data['action'] == 'added') {
            if (prayerList.isNotEmpty) {
              prayerList[0]['soutienpriere'] = currentPrayers + 1;
            }
            isPrayed = true;
          } else {
            if (prayerList.isNotEmpty && currentPrayers > 0) {
              prayerList[0]['soutienpriere'] = currentPrayers - 1;
            }
            isPrayed = false;
          }
        });
      }
    }
  }

  Future<void> _shareForumMessage(Map<String, dynamic> forum, String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_partage_priereforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_msgforums': forum['id'],
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        setState(() {
          final shareList = forum['nbrpartageforums'] as List;
          int currentShares = shareList.isNotEmpty ? shareList[0]['partageforums'] ?? 0 : 0;
          if (data['action'] == 'added') {
            if (shareList.isNotEmpty) {
              shareList[0]['partageforums'] = currentShares + 1;
            }
            isShared = true;
          } else {
            if (shareList.isNotEmpty && currentShares > 0) {
              shareList[0]['partageforums'] = currentShares - 1;
            }
            isShared = false;
          }
        });
        // Ouvre le menu de partage natif
        final text = [
          if (forum['avatar'] != null && (forum['avatar'] as List).isNotEmpty && forum['avatar'][0]['nameavatar'] != null) forum['avatar'][0]['nameavatar'],
          if (forum['content'] != null && (forum['content'] as String).isNotEmpty) forum['content'],
          if (forum['audio_url'] != null && (forum['audio_url'] as String?)?.isNotEmpty == true) '\nAudio : ${forum['audio_url']}',
          '\nPartagé via EMB Mission App'
        ].join('\n');
        await Share.share(text);
      }
    }
  }

  Future<void> _toggleLikeResponse(Map<String, dynamic> response, String userId, dynamic idReponse) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favorieforums_reponse');
    final responseApi = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_reponses': idReponse,
      }),
    );
    if (responseApi.statusCode == 200) {
      final data = jsonDecode(responseApi.body);
      if (data['success'] == 'true') {
        setState(() {
          int currentLikes = response['likeCount'] ?? 0;
          if (data['action'] == 'added') {
            response['likeCount'] = currentLikes + 1;
            response['isLikedByCurrentUser'] = true;
          } else {
            response['likeCount'] = currentLikes > 0 ? currentLikes - 1 : 0;
            response['isLikedByCurrentUser'] = false;
          }
        });
      }
    }
  }

  Widget _buildAudioPlayer(String url, int index) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.blue),
          onPressed: () async {
            // Arrêter la radio live si elle joue
            await _stopRadioIfPlaying();
            
            final player = AudioPlayer();
            await player.setUrl(url);
            await player.play();
          },
        ),
        const Text('Audio'),
      ],
    );
  }
}
