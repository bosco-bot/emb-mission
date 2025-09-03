import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:emb_mission/features/community/screens/forum_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_fr;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:emb_mission/features/community/screens/group_viewmsg_detail_screen.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

class ForumMessage {
  final int id;
  final String idUser;
  final String? content;
  final String? audioUrl;
  final String datePost;
  final String? avatarUrl;
  final String? authorName;
  final int likes;
  final int prayers;
  final int shares;
  final int responses;
  final int views;
  final bool isLiked;
  final bool isPrayed;
  final bool isShared;

  ForumMessage({
    required this.id,
    required this.idUser,
    required this.content,
    required this.audioUrl,
    required this.datePost,
    required this.avatarUrl,
    required this.authorName,
    required this.likes,
    required this.prayers,
    required this.shares,
    required this.responses,
    required this.views,
    required this.isLiked,
    required this.isPrayed,
    required this.isShared,
  });

  factory ForumMessage.fromJson(Map<String, dynamic> json) {
    return ForumMessage(
      id: json['id'],
      idUser: json['id_user']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString(),
      datePost: json['date_post']?.toString() ?? json['date_publication']?.toString() ?? '',
      avatarUrl: (json['avatar'] is List && (json['avatar'] as List).isNotEmpty && json['avatar'][0]['urlavatar'] != null)
          ? json['avatar'][0]['urlavatar'].toString()
          : null,
      authorName: (json['avatar'] is List && (json['avatar'] as List).isNotEmpty && json['avatar'][0]['nameavatar'] != null)
          ? json['avatar'][0]['nameavatar'].toString()
          : null,
      likes: (json['nbrlikeforums'] is List && (json['nbrlikeforums'] as List).isNotEmpty)
          ? (json['nbrlikeforums'][0]['likeforums'] ?? 0) as int
          : (json['nbrlikegroup'] is List && (json['nbrlikegroup'] as List).isNotEmpty)
              ? (json['nbrlikegroup'][0]['likegroupe'] ?? 0) as int
              : 0,
      prayers: (json['nbrsoutienpriere'] is List && (json['nbrsoutienpriere'] as List).isNotEmpty)
          ? (json['nbrsoutienpriere'][0]['soutienpriere'] ?? 0) as int
          : 0,
      shares: (json['nbrpartageforums'] is List && (json['nbrpartageforums'] as List).isNotEmpty)
          ? (json['nbrpartageforums'][0]['partageforums'] ?? 0) as int
          : 0,
      responses: (json['nbrreponses'] is List && (json['nbrreponses'] as List).isNotEmpty)
          ? (json['nbrreponses'][0]['reponsesforums'] ?? 0) as int
          : 0,
      views: json['nbrvues'] ?? 0,
      isLiked: json['isLikedByCurrentUser'] ?? false,
      isPrayed: json['isPrayedByCurrentUser'] ?? false,
      isShared: json['isSharedByCurrentUser'] ?? false,
    );
  }
}

// Locale abrégée personnalisée pour timeago (toujours 'il y a 1h', 'il y a 2min', etc.)
class FrVeryShortMessages implements timeago_fr.LookupMessages {
  @override String prefixAgo() => 'il y a';
  @override String prefixFromNow() => 'dans';
  @override String suffixAgo() => '';
  @override String suffixFromNow() => '';
  @override String lessThanOneMinute(int seconds) => '1min';
  @override String aboutAMinute(int minutes) => '1min';
  @override String minutes(int minutes) => '${minutes}min';
  @override String aboutAnHour(int minutes) => '1h';
  @override String hours(int hours) => '${hours}h';
  @override String aDay(int hours) => '1j';
  @override String days(int days) => '${days}j';
  @override String aboutAMonth(int days) => '1mo';
  @override String months(int months) => '${months}mo';
  @override String aboutAYear(int year) => '1an';
  @override String years(int years) => '${years}an';
  @override String wordSeparator() => ' ';
}

class GroupViewMsgScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupViewMsgScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupViewMsgScreen> createState() => _GroupViewMsgScreenState();
}

class _GroupViewMsgScreenState extends ConsumerState<GroupViewMsgScreen> {
  bool _isWriting = false;
  final TextEditingController _controller = TextEditingController();
  List<ForumMessage> _groupMessages = [];
  bool _loading = true;
  AudioPlayer? _audioPlayer;
  int? _playingIndex;
  bool _isPlaying = false;
  bool _isSearchingForum = false;
  String _searchQueryForum = '';

  // 🚨 FONCTION ULTRA-SIMPLIFIÉE pour arrêter la radio live (MÊME LOGIQUE QUE CONTENTS_SCREEN)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[GROUP_VIEW_MSG] 🎯 _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[GROUP_VIEW_MSG] 🚨 ARRÊT DIRECT ET FORCÉ de la radio live avant lecture audio de groupe');
      
      try {
        // 🎯 MÉTHODE ULTRA-SIMPLE: Arrêter TOUT de force comme dans contents_screen.dart
        
        // 1. Arrêter le player principal de force
        final radioPlayer = ref.read(radioPlayerProvider);
        await radioPlayer.stop();
        print('[GROUP_VIEW_MSG] ✅ Player principal arrêté de force');
        
        // 2. Forcer l'état à false IMMÉDIATEMENT (comme dans contents_screen.dart)
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[GROUP_VIEW_MSG] ✅ État forcé à false immédiatement');
        
        // 3. Arrêter AudioService de force (comme dans contents_screen.dart)
        try {
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          print('[GROUP_VIEW_MSG] ✅ AudioService arrêté via stopRadio()');
        } catch (e) {
          print('[GROUP_VIEW_MSG] ⚠️ stopRadio() échoué: $e');
        }
        
        print('[GROUP_VIEW_MSG] 🎯 Radio live arrêtée avec succès (méthode ultra-simplifiée)');
        
      } catch (e) {
        print('[GROUP_VIEW_MSG] ❌ Erreur lors de l\'arrêt: $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[GROUP_VIEW_MSG] 🚨 État forcé à false (dernière tentative)');
      }
    } else {
      print('[GROUP_VIEW_MSG] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  @override
  void initState() {
    // Initialiser la locale française très abrégée pour timeago
    timeago_fr.setLocaleMessages('fr', FrVeryShortMessages());
    super.initState();
    print('DEBUG: GroupViewMsgScreen initState, groupId=${widget.groupId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(userIdProvider);
      fetchGroupMessages(widget.groupId, userId);
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> fetchGroupMessages(String groupId, String? userId) async {
    setState(() { _loading = true; });
    if (userId == null || groupId.isEmpty) {
      print('DEBUG: userId ou groupId manquant');
      setState(() { _loading = false; });
      return;
    }
    final url = Uri.parse('https://embmission.com/mobileappebm/api/groupeallmsg?id_groupe=$groupId&id_user=$userId');
    print('DEBUG: Appel URL $url');
    final response = await http.get(url);
    print('DEBUG: Réponse brute: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('DEBUG: data = $data');
      if (data['status'] == 'true' && data['allbigdatagroup'] != null) {
        final List messagesJson = data['allbigdatagroup'];
        setState(() {
          _groupMessages = messagesJson.map((e) => ForumMessage.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        setState(() { _groupMessages = []; _loading = false; });
      }
    } else {
      setState(() { _groupMessages = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: GroupViewMsgScreen build');
    final search = _searchQueryForum.trim().toLowerCase();
    final filteredMessages = search.isEmpty
        ? _groupMessages
        : _groupMessages.where((f) {
            final author = f.authorName?.toLowerCase() ?? '';
            final content = f.content?.toLowerCase() ?? '';
            return author.contains(search) || content.contains(search);
          }).toList();
    return Column(
      children: [
        // Remplacement de l'appBar par un Container custom
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(top: 32, left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isSearchingForum
                    ? TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Rechercher un message…',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQueryForum = value);
                        },
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Messages du groupe', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'Messages et discussions du groupe',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
              ),
              IconButton(
                icon: Icon(_isSearchingForum ? Icons.close : Icons.search, color: Colors.black),
                onPressed: () {
                  setState(() => _isSearchingForum = !_isSearchingForum);
                  if (!_isSearchingForum) _searchQueryForum = '';
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final msg = filteredMessages[index];
                    return _buildForumCard(msg, index);
                  },
                ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final userAvatarUrl = ref.watch(userAvatarProvider);
            final userName = ref.watch(userNameProvider) ?? '';
            final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
            return Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              color: Colors.white,
              child: Row(
                children: [
                  userAvatarUrl != null && userAvatarUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(userAvatarUrl),
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade300,
                          child: Text(
                            userInitial,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Partager votre réflexion...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () async {
                        final text = _controller.text.trim();
                        final userId = ref.read(userIdProvider);
                        print('DEBUG SEND: groupId=${widget.groupId}, userId=$userId, text=$text');
                        if (text.isNotEmpty && userId != null && widget.groupId.isNotEmpty) {
                          FocusScope.of(context).unfocus();
                          final success = await _sendGroupMessage(widget.groupId, userId, text);
                          if (success) {
                            _controller.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message envoyé !')),
                            );
                            fetchGroupMessages(widget.groupId, userId); // Rafraîchir la liste
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Erreur lors de l\'envoi du message')), 
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildForumCard(ForumMessage forum, int index) {
    final date = DateTime.tryParse(forum.datePost);
    String relativeTime = '';
    if (date != null) {
      try {
        relativeTime = timeago.format(date, locale: 'fr');
      } catch (e) {
        relativeTime = timeago.format(date);
      }
    }

    return InkWell(
      onTap: () {
        final userId = ref.read(userIdProvider) ?? '';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupViewMsgDetailScreen(
              messageId: forum.id,
              userId: userId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
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
                backgroundImage: forum.avatarUrl != null && forum.avatarUrl!.isNotEmpty
                    ? NetworkImage(forum.avatarUrl!)
                    : null,
                child: (forum.avatarUrl == null || forum.avatarUrl!.isEmpty)
                    ? Text(
                        forum.authorName != null && forum.authorName!.isNotEmpty
                            ? forum.authorName![0].toUpperCase()
                            : '?',
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
                            forum.authorName ?? '',
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
                    if (forum.content != null && forum.content!.isNotEmpty)
                      Text(
                        forum.content!,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    if (forum.audioUrl != null && forum.audioUrl!.isNotEmpty &&
                        (forum.audioUrl!.endsWith('.mp3') || forum.audioUrl!.endsWith('.wav') || forum.audioUrl!.endsWith('.aac')))
                      _buildAudioPlayer(forum.audioUrl!, index),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final userId = ref.watch(userIdProvider);
                            return GestureDetector(
                              onTap: userId == null ? null : () => _toggleLike(forum, index, userId),
                              child: _buildActionButtonSvg(
                                svgPath: 'assets/images/coeur.svg',
                                count: forum.likes.toString(),
                                color: forum.isLiked ? Colors.red : Colors.grey,
                                backgroundColor: forum.isLiked ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () async {
                            final content = forum.content ?? '';
                            if (content.isNotEmpty) {
                              await Share.share(content);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: forum.isShared ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
                            if (forum.content != null && forum.content!.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: forum.content!));
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String url, int index) {
    final isThisPlaying = _playingIndex == index && _isPlaying;
    return Row(
      children: [
        IconButton(
          icon: Icon(isThisPlaying ? Icons.pause : Icons.play_arrow, color: Colors.blue),
          onPressed: () async {
            if (isThisPlaying) {
              await _audioPlayer!.pause();
              setState(() {
                _isPlaying = false;
              });
            } else {
              // Arrêter la radio live si elle joue
              await _stopRadioIfPlaying();
              
              if (_audioPlayer == null) {
                _audioPlayer = AudioPlayer();
                _audioPlayer!.onPlayerComplete.listen((event) {
                  setState(() {
                    _isPlaying = false;
                    _playingIndex = null;
                  });
                });
              }
              if (_playingIndex != null && _playingIndex != index) {
                await _audioPlayer!.stop();
              }
              await _audioPlayer!.play(UrlSource(url));
              setState(() {
                _isPlaying = true;
                _playingIndex = index;
              });
            }
          },
        ),
        const Text('Audio'),
      ],
    );
  }

  Widget _buildActionButtonSvg({
    required String svgPath,
    required String count,
    required Color color,
    required Color backgroundColor,
  }) {
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

  void _toggleLike(ForumMessage msg, int index, String userId) async {
    final groupId = widget.groupId;
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
        print('LIKE API RESPONSE: $data');
        setState(() {
          if (data['action'] == 'added') {
            _groupMessages[index] = ForumMessage(
              id: msg.id,
              idUser: msg.idUser,
              content: msg.content,
              audioUrl: msg.audioUrl,
              datePost: msg.datePost,
              avatarUrl: msg.avatarUrl,
              authorName: msg.authorName,
              likes: msg.likes + 1,
              prayers: msg.prayers,
              shares: msg.shares,
              responses: msg.responses,
              views: msg.views,
              isLiked: true,
              isPrayed: msg.isPrayed,
              isShared: msg.isShared,
            );
          } else if (data['action'] == 'removed') {
            _groupMessages[index] = ForumMessage(
              id: msg.id,
              idUser: msg.idUser,
              content: msg.content,
              audioUrl: msg.audioUrl,
              datePost: msg.datePost,
              avatarUrl: msg.avatarUrl,
              authorName: msg.authorName,
              likes: (msg.likes > 0 ? msg.likes - 1 : 0),
              prayers: msg.prayers,
              shares: msg.shares,
              responses: msg.responses,
              views: msg.views,
              isLiked: false,
              isPrayed: msg.isPrayed,
              isShared: msg.isShared,
            );
          }
        });
      }
    } catch (e) {
      print('LIKE API ERROR: $e');
    }
  }

  Future<bool> _sendGroupMessage(String groupId, String userId, String content) async {
    print('API CALL: id_groupe=$groupId, id_user=$userId, content=$content');
    try {
      final url = Uri.parse('https://embmission.com/mobileappebm/api/postgroupmsg');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_groupe': int.tryParse(groupId) ?? groupId,
          'id_user': userId,
          'content': content,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('API ERROR: $e');
      // ignore
    }
    return false;
  }
} 