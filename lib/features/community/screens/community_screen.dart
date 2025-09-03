import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:emb_mission/features/community/screens/forum_screen.dart';
import 'package:emb_mission/core/widgets/home_back_button.dart';
import 'group_detail_screen.dart';
import 'package:emb_mission/features/testimonies/screens/testimonies_screen.dart';
import 'package:emb_mission/features/community/screens/forums_list_screen.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:emb_mission/features/community/screens/group_viewmsg_screen.dart';
import 'dart:async'; // Added for Timer

/// Écran de la communauté
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final List<String> _tabs = ['Forums', 'Groupes', 'Témoignages'];
  
  // Ajout : liste dynamique des discussions récentes
  List<RecentForumMessage> _recentMessages = [];
  bool _loadingRecentMessages = false;

  // Groupes de prière dynamiques
  List<PrayerGroup> _prayerGroups = [];
  bool _loadingPrayerGroups = false;

  // Chargement global de la page
  bool _loadingPage = true;
  Timer? _statsRefreshTimer; // Added for Timer

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    
    // ✅ Rafraîchir les statistiques toutes les 30 secondes
    _statsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          // Forcer le rafraîchissement des statistiques
        });
      }
    });
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    super.dispose();
  }

  void _fetchAllData() async {
    setState(() { _loadingPage = true; });
    await Future.wait([
      _fetchRecentMessages(wait: true),
      _fetchPrayerGroups(wait: true),
    ]);
    setState(() { _loadingPage = false; });
  }

  Future<void> _fetchRecentMessages({bool wait = false}) async {
    if (!wait) setState(() { _loadingRecentMessages = true; });
    try {
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/toptendiscutionforum'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['status'] == true || data['status'] == 'true') && data['alldataforums'] != null) {
          setState(() {
            _recentMessages = (data['alldataforums'] as List)
                .map((e) => RecentForumMessage.fromJson(e))
                .toList();
            _loadingRecentMessages = false;
          });
        } else {
          setState(() { _recentMessages = []; _loadingRecentMessages = false; });
        }
      } else {
        setState(() { _recentMessages = []; _loadingRecentMessages = false; });
      }
    } catch (e) {
      setState(() { _recentMessages = []; _loadingRecentMessages = false; });
    }
  }

  Future<void> _fetchPrayerGroups({bool wait = false}) async {
    if (!wait) setState(() { _loadingPrayerGroups = true; });
    try {
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/viewsgrougetype'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['status'] == true || data['status'] == 'true') && data['alldatatypegroupe'] != null) {
          setState(() {
            _prayerGroups = (data['alldatatypegroupe'] as List)
                .map((e) => PrayerGroup.fromJson(e))
                .toList();
            _loadingPrayerGroups = false;
          });
        } else {
          setState(() { _prayerGroups = []; _loadingPrayerGroups = false; });
        }
      } else {
        setState(() { _prayerGroups = []; _loadingPrayerGroups = false; });
      }
    } catch (e) {
      setState(() { _prayerGroups = []; _loadingPrayerGroups = false; });
    }
  }

  Future<Map<String, int>> fetchCommunityStats() async {
    try {
      // ✅ Signaler que l'utilisateur est en ligne
      final userId = ref.read(userIdProvider);
      if (userId != null) {
        // Appel pour signaler la présence en ligne
        await http.post(
          Uri.parse('https://embmission.com/mobileappebm/api/user_online'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId}),
        );
      }
      
      // Récupérer les statistiques mises à jour
      final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/viewstatforum'));
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        return {
          'members': data['members'] ?? 0,
          'online': data['online'] ?? 0,
          'active_prayers': data['active_prayers'] ?? 0,
        };
      } else {
        return {'members': 0, 'online': 0, 'active_prayers': 0};
      }
    } catch (e) {
      print('Erreur lors de la récupération des statistiques: $e');
      return {'members': 0, 'online': 0, 'active_prayers': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF64B5F6),
        leading: const HomeBackButton(color: Colors.white),
        title: const Text('Communauté', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              final userId = ref.read(userIdProvider);
              if (userId == null) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const WelcomeScreen(),
                );
              } else {
                context.pushNamed('new_testimony');
              }
            },
          ),
        ],
      ),
      body: _loadingPage
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 24),
                _buildStatsSection(),
                
                // Sélecteur de catégories
                _buildCategorySelector(),
                
                // Contenu principal
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Discussions récentes
                        _buildRecentDiscussions(),
                        
                        // Groupes de prière
                        _buildPrayerGroups(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  // Section des statistiques
  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, int>>(
      future: fetchCommunityStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final stats = snapshot.data!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard('${stats['members']}', 'Membres'),
            _buildStatCard('${stats['online']}', 'En ligne'),
            _buildStatCard('${stats['active_prayers']}', 'Prières actives'),
          ],
        );
      },
    );
  }
  
  Widget _buildStatCard(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centrage horizontal
      children: [
        Text(
          value,
          textAlign: TextAlign.center, // ✅ Centrage du texte
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center, // ✅ Centrage du texte
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
  
  // Sélecteur de catégories
  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: _tabs.map((tab) => _buildCategoryButton(tab)).toList(),
      ),
    );
  }
  
  // Bouton de catégorie
  Widget _buildCategoryButton(String category) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    switch (category) {
      case 'Forums':
        backgroundColor = const Color(0xFFE3F2FD); // Fond bleu clair
        textColor = const Color(0xFF1976D2); // Bleu
        icon = Icons.chat_bubble_outline;
        break;
      case 'Groupes':
        backgroundColor = const Color(0xFFF3E5F5); // Fond violet clair
        textColor = const Color(0xFF9C27B0); // Violet
        icon = Icons.people_outline;
        break;
      case 'Témoignages':
        backgroundColor = const Color(0xFFE8F5E9); // Fond vert clair
        textColor = const Color(0xFF4CAF50); // Vert
        icon = Icons.favorite_outline;
        break;
      default:
        backgroundColor = Colors.white;
        textColor = Colors.grey;
        icon = Icons.circle;
    }
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () {
            if (category == 'Forums') {
              final userId = ref.read(userIdProvider);
              if (userId != null) {
                context.go('/community/forums');
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                );
              }
            } else if (category == 'Groupes') {
              final userId = ref.read(userIdProvider);
              if (userId == null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                );
                return;
              }
              // Navigation vers GroupDetailScreen avec le premier groupe (à adapter selon la logique métier)
              if (_prayerGroups.isNotEmpty) {
                final groupId = _prayerGroups.first.id.toString();
                context.go('/community/group-detail/$groupId');
              }
            } else if (category == 'Témoignages') {
              context.pushNamed('testimonies');
            }
            // Pour les autres catégories, à implémenter plus tard
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.transparent),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 24),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Section des discussions récentes (dynamique, design strictement d'origine)
  Widget _buildRecentDiscussions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discussions récentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(
                onPressed: () {
                  final userId = ref.read(userIdProvider);
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForumsListScreen(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(color: Color(0xFF64B5F6)),
                ),
              ),
            ],
          ),
        ),
        if (_loadingRecentMessages)
          const Center(child: CircularProgressIndicator()),
        if (!_loadingRecentMessages && _recentMessages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Aucune discussion récente.'),
          ),
        if (!_loadingRecentMessages && _recentMessages.isNotEmpty)
          ..._recentMessages.map((msg) => _buildDiscussionItem(
            msg.content ?? 'Message',
            msg.authorName,
            _formatDate(msg.datePost),
            '${msg.nbrReponses} réponses',
            '${msg.nbrVues} vues',
            msg.avatarUrl,
          )).toList(),
      ],
    );
  }

  // Item de discussion (design d'origine, avatar dynamique)
  Widget _buildDiscussionItem(String title, String author, String time, String replies, String views, String? avatarUrl) {
    // Utiliser la première lettre du prénom pour l'avatar (toujours, même si image)
    String avatarLetter = '?';
    if (author.isNotEmpty) {
      final prenom = author.split(' ').first;
      if (prenom.isNotEmpty) {
        avatarLetter = prenom[0].toUpperCase();
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade400,
            child: Text(
              avatarLetter,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$author • $time',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(replies, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(width: 16),
                    Icon(Icons.visibility_outlined, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(views, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours} h';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} j';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
  
  // Section des groupes de prière
  Widget _buildPrayerGroups() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.only(bottom: 16.0),
          ),
          const Text(
            'Groupes de prière',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_prayerGroups.isEmpty)
            const Text('Aucun groupe de prière trouvé.'),
          if (_prayerGroups.isNotEmpty)
            ..._prayerGroups.map((groupe) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        groupe.titregroupe,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: groupe.actif.toLowerCase() == 'actif' ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          groupe.actif,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${groupe.nbrmenbre} membres • Prochaine session à ${groupe.prochainesession}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final userId = ref.read(userIdProvider);
                      if (userId == null) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const WelcomeScreen(),
                        );
                        return;
                      }
                      // Appel API rejoindre groupe
                      try {
                        final response = await http.post(
                          Uri.parse('https://embmission.com/mobileappebm/api/rejoindregroupe'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'iduser': userId,
                            'id_groupe': groupe.id,
                          }),
                        );
                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          if (data['success'] == 'true' && (data['action']?.toString().contains('succès') ?? false)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vous avez rejoint le groupe avec succès !')),
                            );
                            // Rafraîchir la liste des groupes après avoir rejoint
                            await _fetchPrayerGroups();
                          } else if (data['action']?.toString().toLowerCase().contains('déjà') ?? false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vous êtes déjà membre de ce groupe.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur : ${data['action'] ?? 'Impossible de rejoindre le groupe.'}')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur réseau : ${response.statusCode}')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Rejoindre'),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
  

}

// Ajout du modèle pour les messages récents
class RecentForumMessage {
  final int id;
  final String? content;
  final String datePost;
  final String authorName;
  final String? avatarUrl;
  final int nbrSoutienPriere;
  final int nbrReponses;
  final int nbrVues;

  RecentForumMessage({
    required this.id,
    required this.content,
    required this.datePost,
    required this.authorName,
    required this.avatarUrl,
    required this.nbrSoutienPriere,
    required this.nbrReponses,
    required this.nbrVues,
  });

  factory RecentForumMessage.fromJson(Map<String, dynamic> json) {
    final avatarList = json['avatar'] as List?;
    return RecentForumMessage(
      id: json['id'],
      content: json['content'],
      datePost: json['date_post'],
      authorName: (avatarList != null && avatarList.isNotEmpty) ? avatarList[0]['nameavatar'] ?? '' : '',
      avatarUrl: (avatarList != null && avatarList.isNotEmpty) ? avatarList[0]['urlavatar'] : null,
      nbrSoutienPriere: (json['nbrsoutienpriere'] as List).isNotEmpty ? json['nbrsoutienpriere'][0]['soutienpriere'] ?? 0 : 0,
      nbrReponses: (json['nbrreponses'] as List).isNotEmpty ? json['nbrreponses'][0]['reponsesforums'] ?? 0 : 0,
      nbrVues: json['nbrvues'] ?? 0,
    );
  }
}

// Modèle pour un groupe de prière (API)
class PrayerGroup {
  final int id;
  final String titregroupe;
  final String prochainesession;
  final String typegroupe;
  final String actif;
  final int nbrmenbre;

  PrayerGroup({
    required this.id,
    required this.titregroupe,
    required this.prochainesession,
    required this.typegroupe,
    required this.actif,
    required this.nbrmenbre,
  });

  factory PrayerGroup.fromJson(Map<String, dynamic> json) {
    return PrayerGroup(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      titregroupe: json['titregroupe'] ?? '',
      prochainesession: json['prochainesession'] ?? '',
      typegroupe: json['typegroupe'] ?? '',
      actif: json['actif'] ?? '',
      nbrmenbre: json['nbrmenbre'] is int ? json['nbrmenbre'] : int.tryParse(json['nbrmenbre'].toString()) ?? 0,
    );
  }
}
