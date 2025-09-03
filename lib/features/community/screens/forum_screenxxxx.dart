import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final forumDetailProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final forumId = params['forumId'];
  final userId = params['userId'];
  print('API detail_msgforum: forumId=\x1B[32m$forumId\x1B[0m, userId=\x1B[32m$userId\x1B[0m');
  final url = Uri.parse('https://embmission.com/mobileappebm/api/detail_msgforum');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'id_msgforums': forumId,
      'id_user': userId,
    }),
  );
  print('Réponse API: \x1B[36m${response.body}\x1B[0m');
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['status'] == 'true' && data['alldataforums'] != null && data['alldataforums'].isNotEmpty) {
      return data['alldataforums'][0];
    } else {
      throw Exception('Forum non trouvé');
    }
  } else if (response.statusCode == 429) {
    throw Exception('Trop de requêtes : le serveur vous bloque temporairement. Veuillez patienter quelques minutes.');
  } else {
    throw Exception('Erreur serveur');
  }
});

/// Écran de forum pour les discussions communautaires
class ForumScreen extends ConsumerStatefulWidget {
  final int forumId;
  final String userId;
  const ForumScreen({super.key, required this.forumId, required this.userId});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  bool _isWriting = false;
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    print('ForumScreen build: forumId= [32m${widget.forumId} [0m, userId= [32m${widget.userId} [0m');
    final forumAsync = ref.watch(forumDetailProvider({
      'forumId': widget.forumId,
      'userId': widget.userId,
    }));
    return forumAsync.when(
      data: (forum) {
        try {
          print('ForumScreen DATA: forum=\x1B[35m$forum\x1B[0m');
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((forum['avatar'] != null && forum['avatar'] is List && forum['avatar'].isNotEmpty) ? (forum['avatar'][0]['nameavatar'] ?? 'Forum') : 'Forum'),
                  Text(
                    'Discussion communautaire',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              leading: const BackButton(),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post principal dynamique
                        Card(
                          margin: const EdgeInsets.all(16),
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
                                  backgroundColor: Colors.blue.shade300,
                                  backgroundImage: (forum['avatar'] != null && forum['avatar'] is List && forum['avatar'].isNotEmpty && forum['avatar'][0]['urlavatar'] != null)
                                      ? NetworkImage(forum['avatar'][0]['urlavatar'])
                                      : null,
                                  child: (forum['avatar'] == null || !(forum['avatar'] is List) || forum['avatar'].isEmpty || forum['avatar'][0]['urlavatar'] == null)
                                      ? const Icon(Icons.person)
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
                                              (forum['avatar'] != null && forum['avatar'] is List && forum['avatar'].isNotEmpty) ? (forum['avatar'][0]['nameavatar'] ?? '') : '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            forum['date_post'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        forum['content'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Réponses dynamiques
                        if (forum['reponses'] != null && forum['reponses'] is List && forum['reponses'].isNotEmpty)
                          ...List.generate(forum['reponses'].length, (i) {
                            final rep = forum['reponses'][i] ?? {};
                            final repAvatar = (rep['reponseavatar'] != null && rep['reponseavatar'] is Map<String, dynamic>) ? rep['reponseavatar'] : {};
                            final nameAvatar = repAvatar['nameavatar'] ?? '?';
                            final firstLetter = (nameAvatar is String && nameAvatar.isNotEmpty) ? nameAvatar.substring(0, 1) : '?';
                            final content = rep['content'] ?? '';
                            final dateReponse = rep['date_reponse'] ?? '';
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text(firstLetter),
                                ),
                                title: Text(nameAvatar),
                                subtitle: Text(content),
                                trailing: Text(dateReponse),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                // Champ de réponse, actions, etc. à ajouter ici si besoin
              ],
            ),
          );
        } catch (e, stack) {
          print('ForumScreen DATA ERROR: $e\n$stack');
          return Scaffold(
            body: Center(
              child: Text(
                'Erreur inattendue dans le build :\n$e',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      },
      loading: () {
        print('ForumScreen LOADING...');
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        print('ForumScreen ERROR: ' + error.toString());
        return Scaffold(
          body: Center(
            child: Text(
              'Erreur de chargement :\n$error',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  // Section du post principal
  Widget _buildMainPost() {
    return Card(
      margin: const EdgeInsets.all(16),
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
              backgroundColor: Colors.blue.shade300,
              backgroundImage: const NetworkImage(
                'https://randomuser.me/api/portraits/men/32.jpg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Jean-Pierre M.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        'Il y a 2h',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Titre du post
                  const Text(
                    'Comment rester fort dans la foi pendant les épreuves ?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Contenu du post
                  const Text(
                    'Je traverse une période difficile et j\'aimerais avoir vos conseils et prières. Comment gardez-vous votre foi vivante quand tout semble aller mal ?',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Actions du post
                  Row(
                    children: [
                      _buildActionButtonSvg(
                        svgPath: 'assets/images/coeur.svg',
                        count: '12',
                        color: Colors.red,
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 16),
                      _buildActionButtonSvg(
                        svgPath: 'assets/images/prières.svg',
                        count: '8',
                        color: Colors.blue,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 16),
                      _buildActionButtonSvg(
                        svgPath: 'assets/images/partager.svg',
                        count: '3',
                        color: Colors.green,
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
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
                  // Statistiques du post
                  Text(
                    '15 réponses • 23 vues',
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
  }

  // En-tête des réponses
  Widget _buildResponsesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Réponses (15)',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  // Liste des réponses
  Widget _buildResponses() {
    return Column(
      children: [
        _buildResponseItem(
          name: 'Marie C.',
          time: 'Il y a 1h',
          content:
              'Courage frère ! Romains 8:28 nous rappelle que toutes choses concourent au bien de ceux qui aiment Dieu. Je prie pour toi 🙏',
          likes: '5',
          avatarUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
        ),
        _buildResponseItem(
          name: 'Pastor David',
          time: 'Il y a 45min',
          content: 'Mon cher frère, les épreuves sont...',
          likes: '',
          avatarUrl: 'https://randomuser.me/api/portraits/men/52.jpg',
          isModerator: true,
        ),
      ],
    );
  }

  // Item de réponse individuel
  Widget _buildResponseItem({
    required String name,
    required String time,
    required String content,
    required String likes,
    required String avatarUrl,
    bool isModerator = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              radius: 18,
              backgroundImage: NetworkImage(avatarUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isModerator)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Modérateur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (likes.isNotEmpty) ...[
                        Icon(
                          Icons.favorite,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likes,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        'Répondre',
                        style: TextStyle(
                          color: Colors.blue.shade400,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Zone de saisie de commentaire
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(
              'https://randomuser.me/api/portraits/women/44.jpg',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: !_isWriting
                ? GestureDetector(
                    onTap: () => setState(() => _isWriting = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Partager votre réflexion...',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Votre message ici...',
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
                                // TODO: Envoyer le message
                                setState(() {
                                  _isWriting = false;
                                  _controller.clear();
                                });
                              },
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  // Bouton d'action pour les posts avec SVG
  Widget _buildActionButtonSvg({
    required String svgPath,
    required String count,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
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
          Text(
            count,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
