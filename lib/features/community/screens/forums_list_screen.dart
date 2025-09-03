import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:emb_mission/features/community/screens/forum_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
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
      idUser: json['id_user'],
      content: json['content'],
      audioUrl: json['audio_url'],
      datePost: json['date_post'],
      avatarUrl: (json['avatar'] as List).isNotEmpty ? json['avatar'][0]['urlavatar'] : null,
      authorName: (json['avatar'] as List).isNotEmpty ? json['avatar'][0]['nameavatar'] : null,
      likes: (json['nbrlikeforums'] as List).isNotEmpty ? json['nbrlikeforums'][0]['likeforums'] ?? 0 : 0,
      prayers: (json['nbrsoutienpriere'] as List).isNotEmpty ? json['nbrsoutienpriere'][0]['soutienpriere'] ?? 0 : 0,
      shares: (json['nbrpartageforums'] as List).isNotEmpty ? json['nbrpartageforums'][0]['partageforums'] ?? 0 : 0,
      responses: (json['nbrreponses'] as List).isNotEmpty ? json['nbrreponses'][0]['reponsesforums'] ?? 0 : 0,
      views: json['nbrvues'] ?? 0,
      isLiked: json['isLikedByCurrentUser'] ?? false,
      isPrayed: json['isPrayedByCurrentUser'] ?? false,
      isShared: json['isSharedByCurrentUser'] ?? false,
    );
  }
}

class ForumsListScreen extends ConsumerStatefulWidget {
  const ForumsListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ForumsListScreen> createState() => _ForumsListScreenState();
}

class _ForumsListScreenState extends ConsumerState<ForumsListScreen> {
  bool _isWriting = false;
  final TextEditingController _controller = TextEditingController();
  List<ForumMessage> _forums = [];
  bool _loading = true;
  AudioPlayer? _audioPlayer;
  int? _playingIndex;
  bool _isPlaying = false;
  bool _isSearchingForum = false;
  String _searchQueryForum = '';

  // 🚨 FONCTION ULTRA-SIMPLIFIÉE pour arrêter la radio live (MÊME LOGIQUE QUE CONTENTS_SCREEN)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[FORUMS_LIST] 🎯 _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[FORUMS_LIST] 🚨 ARRÊT DIRECT ET FORCÉ de la radio live avant lecture audio de forum');
      
      try {
        // 🎯 MÉTHODE ULTRA-SIMPLE: Arrêter TOUT de force comme dans contents_screen.dart
        
        // 1. Arrêter le player principal de force
        final radioPlayer = ref.read(radioPlayerProvider);
        await radioPlayer.stop();
        print('[FORUMS_LIST] ✅ Player principal arrêté de force');
        
        // 2. Forcer l'état à false IMMÉDIATEMENT (comme dans contents_screen.dart)
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[FORUMS_LIST] ✅ État forcé à false immédiatement');
        
        // 3. Arrêter AudioService de force (comme dans contents_screen.dart)
        try {
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          print('[FORUMS_LIST] ✅ AudioService arrêté via stopRadio()');
        } catch (e) {
          print('[FORUMS_LIST] ⚠️ stopRadio() échoué: $e');
        }
        
        print('[FORUMS_LIST] 🎯 Radio live arrêtée avec succès (méthode ultra-simplifiée)');
        
      } catch (e) {
        print('[FORUMS_LIST] ❌ Erreur lors de l\'arrêt: $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[FORUMS_LIST] 🚨 État forcé à false (dernière tentative)');
      }
    } else {
      print('[FORUMS_LIST] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(userIdProvider);
      fetchForums(userId);
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> fetchForums(String? userId) async {
    setState(() { _loading = true; });
    final url = Uri.parse('https://embmission.com/mobileappebm/api/allmsgforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_user': userId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'true') {
        final List forumsJson = data['alldataforums'];
        setState(() {
          _forums = forumsJson.map((e) => ForumMessage.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        setState(() { _loading = false; });
      }
    } else {
      setState(() { _loading = false; });
    }
  }

  Future<void> _toggleLike(ForumMessage forum, int index, String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favorieforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_msgforums': forum.id,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        setState(() {
          if (data['action'] == 'added') {
            _forums[index] = ForumMessage(
              id: forum.id,
              idUser: forum.idUser,
              content: forum.content,
              audioUrl: forum.audioUrl,
              datePost: forum.datePost,
              avatarUrl: forum.avatarUrl,
              authorName: forum.authorName,
              likes: forum.likes + 1,
              prayers: forum.prayers,
              shares: forum.shares,
              responses: forum.responses,
              views: forum.views,
              isLiked: true,
              isPrayed: forum.isPrayed,
              isShared: forum.isShared,
            );
          } else {
            _forums[index] = ForumMessage(
              id: forum.id,
              idUser: forum.idUser,
              content: forum.content,
              audioUrl: forum.audioUrl,
              datePost: forum.datePost,
              avatarUrl: forum.avatarUrl,
              authorName: forum.authorName,
              likes: forum.likes > 0 ? forum.likes - 1 : 0,
              prayers: forum.prayers,
              shares: forum.shares,
              responses: forum.responses,
              views: forum.views,
              isLiked: false,
              isPrayed: forum.isPrayed,
              isShared: forum.isShared,
            );
          }
        });
      }
    }
  }

  Future<void> _togglePrayer(ForumMessage forum, int index, String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_stient_priereforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_msgforums': forum.id,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        setState(() {
          if (data['action'] == 'added') {
            _forums[index] = ForumMessage(
              id: forum.id,
              idUser: forum.idUser,
              content: forum.content,
              audioUrl: forum.audioUrl,
              datePost: forum.datePost,
              avatarUrl: forum.avatarUrl,
              authorName: forum.authorName,
              likes: forum.likes,
              prayers: forum.prayers + 1,
              shares: forum.shares,
              responses: forum.responses,
              views: forum.views,
              isLiked: forum.isLiked,
              isPrayed: true,
              isShared: forum.isShared,
            );
          } else {
            _forums[index] = ForumMessage(
              id: forum.id,
              idUser: forum.idUser,
              content: forum.content,
              audioUrl: forum.audioUrl,
              datePost: forum.datePost,
              avatarUrl: forum.avatarUrl,
              authorName: forum.authorName,
              likes: forum.likes,
              prayers: forum.prayers > 0 ? forum.prayers - 1 : 0,
              shares: forum.shares,
              responses: forum.responses,
              views: forum.views,
              isLiked: forum.isLiked,
              isPrayed: false,
              isShared: forum.isShared,
            );
          }
        });
      }
    }
  }

  Future<void> _shareForumMessage(ForumMessage forum, int index, String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_partage_priereforums');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'id_msgforums': forum.id,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        setState(() {
          if (data['action'] == 'added') {
            _forums[index] = ForumMessage(
              id: forum.id,
              idUser: forum.idUser,
              content: forum.content,
              audioUrl: forum.audioUrl,
              datePost: forum.datePost,
              avatarUrl: forum.avatarUrl,
              authorName: forum.authorName,
              likes: forum.likes,
              prayers: forum.prayers,
              shares: forum.shares + 1,
              responses: forum.responses,
              views: forum.views,
              isLiked: forum.isLiked,
              isPrayed: forum.isPrayed,
              isShared: true,
            );
          } else {
            _forums[index] = ForumMessage(
              id: forum.id,
              idUser: forum.idUser,
              content: forum.content,
              audioUrl: forum.audioUrl,
              datePost: forum.datePost,
              avatarUrl: forum.avatarUrl,
              authorName: forum.authorName,
              likes: forum.likes,
              prayers: forum.prayers,
              shares: forum.shares > 0 ? forum.shares - 1 : 0,
              responses: forum.responses,
              views: forum.views,
              isLiked: forum.isLiked,
              isPrayed: forum.isPrayed,
              isShared: false,
            );
          }
        });
        final text = [
          if (forum.authorName != null && forum.authorName!.isNotEmpty) forum.authorName!,
          if (forum.content != null && forum.content!.isNotEmpty) forum.content!,
          if (forum.audioUrl != null && forum.audioUrl!.isNotEmpty) '\nAudio : ${forum.audioUrl}',
          '\nPartagé via EMB Mission App'
        ].join('\n');
        await Share.share(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredForums = _searchQueryForum.isEmpty
        ? _forums
        : _forums.where((f) =>
            (f.authorName?.toLowerCase().contains(_searchQueryForum.toLowerCase()) ?? false) ||
            (f.content?.toLowerCase().contains(_searchQueryForum.toLowerCase()) ?? false)
          ).toList();
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        leading: const BackButton(),
        title: _isSearchingForum
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
                  Text('Forum', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Discussion communautaire',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_isSearchingForum)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearchingForum = false;
                  _searchQueryForum = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearchingForum = true);
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredForums.length,
                    itemBuilder: (context, index) {
                      final forum = filteredForums[index];
                      return _buildForumCard(forum, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildForumCard(ForumMessage forum, int index) {
    final date = DateTime.tryParse(forum.datePost);
    final relativeTime = date != null ? timeago.format(date, locale: 'fr') : '';

    return InkWell(
      onTap: () {
        final userId = ref.read(userIdProvider) ?? '';
        context.pushNamed('forum_detail', pathParameters: {'id': forum.id.toString()}, extra: {'userId': userId});
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
                        Consumer(
                          builder: (context, ref, _) {
                            final userId = ref.watch(userIdProvider);
                            return GestureDetector(
                              onTap: userId == null ? null : () => _togglePrayer(forum, index, userId),
                              child: _buildActionButtonSvg(
                                svgPath: 'assets/images/prières.svg',
                                count: forum.prayers.toString(),
                                color: forum.isPrayed ? Colors.blue : Colors.grey,
                                backgroundColor: forum.isPrayed ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Consumer(
                          builder: (context, ref, _) {
                            final userId = ref.watch(userIdProvider);
                            return GestureDetector(
                              onTap: userId == null ? null : () => _shareForumMessage(forum, index, userId),
                              child: _buildActionButtonSvg(
                                svgPath: 'assets/images/partager.svg',
                                count: forum.shares.toString(),
                                color: forum.isShared ? Colors.green : Colors.grey,
                                backgroundColor: forum.isShared ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              ),
                            );
                          },
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
                      "${forum.responses} réponses • ${forum.views} vues",
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
}

class _CustomFrMessages extends timeago.FrMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String aboutAMinute(_) => 'il y a une minute';
  @override
  String aboutAnHour(_) => 'il y a une heure';
  @override
  String aboutAMonth(_) => 'il y a un mois';
  @override
  String aboutAYear(_) => 'il y a un an';
  @override
  String minutes(int minutes) => 'il y a $minutes min';
  @override
  String hours(int hours) => 'il y a $hours h';
  @override
  String days(int days) => 'il y a $days j';
  @override
  String months(int months) => 'il y a $months mois';
  @override
  String years(int years) => 'il y a $years ans';
} 