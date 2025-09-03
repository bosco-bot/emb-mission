import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

/// Détail d'un message de groupe (structure similaire à ForumScreen)
class GroupViewMsgDetailScreen extends ConsumerStatefulWidget {
  final int messageId;
  final String userId;
  const GroupViewMsgDetailScreen({super.key, required this.messageId, required this.userId});

  @override
  ConsumerState<GroupViewMsgDetailScreen> createState() => _GroupViewMsgDetailScreenState();
}

class _GroupViewMsgDetailScreenState extends ConsumerState<GroupViewMsgDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _messageData;
  String? _error;
  bool _isWriting = false;
  final TextEditingController _controller = TextEditingController();
  bool isLiked = false;
  bool isPrayed = false;
  bool isShared = false;

  // 🚨 FONCTION ULTRA-SIMPLIFIÉE pour arrêter la radio live (MÊME LOGIQUE QUE CONTENTS_SCREEN)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[GROUP_VIEW_MSG_DETAIL] 🎯 _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[GROUP_VIEW_MSG_DETAIL] 🚨 ARRÊT DIRECT ET FORCÉ de la radio live avant lecture audio de groupe');
      
      try {
        // 🎯 MÉTHODE ULTRA-SIMPLE: Arrêter TOUT de force comme dans contents_screen.dart
        
        // 1. Arrêter le player principal de force
        final radioPlayer = ref.read(radioPlayerProvider);
        await radioPlayer.stop();
        print('[GROUP_VIEW_MSG_DETAIL] ✅ Player principal arrêté de force');
        
        // 2. Forcer l'état à false IMMÉDIATEMENT (comme dans contents_screen.dart)
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[GROUP_VIEW_MSG_DETAIL] ✅ État forcé à false immédiatement');
        
        // 3. Arrêter AudioService de force (comme dans contents_screen.dart)
        try {
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          print('[GROUP_VIEW_MSG_DETAIL] ✅ AudioService arrêté via stopRadio()');
        } catch (e) {
          print('[GROUP_VIEW_MSG_DETAIL] ⚠️ stopRadio() échoué: $e');
        }
        
        print('[GROUP_VIEW_MSG_DETAIL] 🎯 Radio live arrêtée avec succès (méthode ultra-simplifiée)');
        
      } catch (e) {
        print('[GROUP_VIEW_MSG_DETAIL] ❌ Erreur lors de l\'arrêt: $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[GROUP_VIEW_MSG_DETAIL] 🚨 État forcé à false (dernière tentative)');
      }
    } else {
      print('[GROUP_VIEW_MSG_DETAIL] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(userIdProvider);
      _fetchMessageDetail(userId);
    });
  }

  Future<void> _fetchMessageDetail(String? userId) async {
    setState(() { _loading = true; _error = null; });
    final url = Uri.parse('https://embmission.com/mobileappebm/api/detail_msg_group');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_groupepost': widget.messageId, 'id_user': userId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'true' && data['alldetailgroup'] != null && data['alldetailgroup'].isNotEmpty) {
          final msg = data['alldetailgroup'][0];
          setState(() {
            _messageData = msg;
            isLiked = msg['isLikedByCurrentUser'] ?? false;
            _loading = false;
          });
        } else {
          setState(() { _error = "Aucune donnée trouvée"; _loading = false; });
        }
      } else {
        setState(() { _error = "Erreur serveur: \\${response.statusCode}"; _loading = false; });
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
        title: const Text('Détail du message de groupe'),
        leading: const BackButton(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _messageData == null
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
                                  _buildMainPost(_messageData!),
                                  const SizedBox(height: 24),
                                  // Afficher le titre avec le nombre de réponses
                                  Builder(
                                    builder: (context) {
                                      final responseList = _messageData!['nbrreponses'] as List? ?? [];
                                      final responses = responseList.isNotEmpty ? responseList[0]['reponsesforums'] ?? 0 : 0;
                                      return Text('Réponses ($responses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  ...((_messageData!['reponses'] as List?) ?? []).isEmpty
                                    ? [const Text('Aucune réponse pour ce message.')]
                                    : ((_messageData!['reponses'] as List?) ?? []).map((r) => _buildResponseItem(r)).toList(),
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

  Widget _buildMainPost(Map<String, dynamic> msg) {
    final avatarList = msg['avatar'] as List? ?? [];
    final avatar = avatarList.isNotEmpty ? avatarList[0] : null;
    final authorName = avatar != null ? avatar['nameavatar'] ?? '' : '';
    final avatarUrl = avatar != null ? avatar['urlavatar'] : null;
    final date = msg['date_post'] ?? '';
    final content = msg['content'] ?? '';
    final audioUrl = msg['audio_url'] ?? '';
    final likeList = msg['nbrlikegroup'] as List? ?? [];
    final likes = likeList.isNotEmpty ? likeList[0]['likegroupe'] ?? 0 : 0;
    final prayerList = msg['nbrsoutienpriere'] as List? ?? [];
    final prayers = prayerList.isNotEmpty ? prayerList[0]['soutienpriere'] ?? 0 : 0;
    final shareList = msg['nbrpartagegroup'] as List? ?? [];
    final shares = shareList.isNotEmpty ? shareList[0]['partagegroup'] ?? 0 : 0;
    final responseList = msg['nbrreponses'] as List? ?? [];
    final responses = responseList.isNotEmpty ? responseList[0]['reponsesforums'] ?? 0 : 0;
    final views = msg['nbrvues'] ?? 0;
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
                          Consumer(
                            builder: (context, ref, _) {
                              final userId = ref.watch(userIdProvider);
                              return GestureDetector(
                                onTap: userId == null ? null : () => _toggleLike(userId),
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
                                      Text(getLikeCount().toString(), style: TextStyle(color: isLiked ? Colors.red : Colors.grey, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () async {
                              if (content.isNotEmpty) {
                                await Share.share(content);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.share,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              if (content.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: content));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Message copié dans le presse-papier')),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.content_copy, size: 18, color: Colors.grey),
                            ),
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
                    Consumer(
                      builder: (context, ref, _) {
                        final userId = ref.watch(userIdProvider);
                        return GestureDetector(
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
                        );
                      },
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
    final messageId = widget.messageId;
    final url = Uri.parse('https://embmission.com/mobileappebm/api/savereponsepostgroupe');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_groupepost': messageId,
        'id_user': userId,
        'content': text,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true || data['success'] == 'true') {
        setState(() {
          _controller.clear();
        });
        // Rafraîchir la liste des réponses et forcer la mise à jour du header
        final userIdRefresh = ref.read(userIdProvider);
        await _fetchMessageDetail(userIdRefresh);
        setState(() {}); // Force la reconstruction pour mettre à jour le nombre de réponses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Votre réponse a été envoyée avec succès !'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
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

  Future<void> _toggleLike(String userId) async {
    final groupId = widget.messageId;
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favoriegroup');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'id_groupe': groupId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data['action'] == 'added') {
            isLiked = true;
            // Incrémente le compteur localement
            _messageData?['nbrlikeforums'] = [
              {'likeforums': (getLikeCount() + 1)}
            ];
          } else if (data['action'] == 'removed') {
            isLiked = false;
            // Décrémente le compteur localement
            _messageData?['nbrlikeforums'] = [
              {'likeforums': (getLikeCount() > 0 ? getLikeCount() - 1 : 0)}
            ];
          }
        });
      }
    } catch (e) {
      print('LIKE API ERROR: $e');
    }
  }

  Future<void> _toggleLikeResponse(Map<String, dynamic> response, String userId, dynamic idReponse) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favoriegroup_reponse');
    try {
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
    } catch (e) {
      print('LIKE RESPONSE API ERROR: $e');
    }
  }

  int getLikeCount() {
    final likeList = _messageData?['nbrlikeforums'] as List? ?? [];
    return likeList.isNotEmpty ? likeList[0]['likeforums'] ?? 0 : 0;
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