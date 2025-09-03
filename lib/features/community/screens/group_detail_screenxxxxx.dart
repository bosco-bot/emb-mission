import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:emb_mission/features/community/screens/forums_list_screen.dart';
import 'package:emb_mission/features/testimonies/screens/testimonies_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/community/screens/group_viewmsg_screen.dart';
import 'package:emb_mission/core/theme/app_colors.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

final groupDetailProvider = FutureProvider.family<Map<String, dynamic>?, Map<String, dynamic>>((ref, params) async {
  final groupId = params['groupId'];
  final userId = params['userId'];
  final url = Uri.parse('https://embmission.com/mobileappebm/api/detail_msg_group');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'id_groupepost': groupId,
      'id_user': userId,
    }),
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['status'] == 'true' && data['alldetailgroup'] is List && data['alldetailgroup'].isNotEmpty) {
      return data['alldetailgroup'][0];
    }
  }
  return null;
});

/// Écran de détail d'un groupe spécifique
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  final String userId;
  const GroupDetailScreen({Key? key, required this.groupId, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupDetailAsync = ref.watch(groupDetailProvider({'groupId': groupId, 'userId': userId}));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du groupe'),
      ),
      body: groupDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur: $err')),
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Aucun détail trouvé pour ce groupe.'));
          }
          final avatarUrl = (group['avatar'] is List && group['avatar'].isNotEmpty) ? group['avatar'][0]['urlavatar'] : null;
          final avatarName = (group['avatar'] is List && group['avatar'].isNotEmpty) ? group['avatar'][0]['nameavatar'] : '';
          final content = group['content'] ?? '';
          final datePost = group['date_post'] ?? '';
          final likes = (group['nbrlikeforums'] is List && group['nbrlikeforums'].isNotEmpty) ? group['nbrlikeforums'][0]['likeforums'] ?? 0 : 0;
          final vues = group['nbrvues'] ?? 0;
          final reponses = (group['nbrreponses'] is List && group['nbrreponses'].isNotEmpty) ? group['nbrreponses'][0]['reponsesforums'] ?? 0 : 0;
          final isLiked = group['isLikedByCurrentUser'] ?? false;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? Text(avatarName.isNotEmpty ? avatarName[0] : '?') : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(avatarName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(datePost, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(content, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.thumb_up, color: isLiked ? Colors.blue : Colors.grey, size: 20),
                        const SizedBox(width: 4),
                        Text('$likes'),
                        const SizedBox(width: 16),
                        Icon(Icons.remove_red_eye, color: Colors.grey, size: 20),
                        const SizedBox(width: 4),
                        Text('$vues'),
                        const SizedBox(width: 16),
                        Icon(Icons.forum, color: Colors.grey, size: 20),
                        const SizedBox(width: 4),
                        Text('$reponses'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

