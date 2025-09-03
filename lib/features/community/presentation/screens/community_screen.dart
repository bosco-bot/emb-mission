import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:emb_mission/core/widgets/category_button.dart';

/// Écran de la communauté
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _selectedCategory = 'Tous';
  final List<String> _categories = ['Tous', 'Événements', 'Groupes', 'Messages'];
  
  // Ajout : liste dynamique des messages récents
  List<RecentForumMessage> _recentMessages = [];
  bool _loadingRecentMessages = false;

  @override
  void initState() {
    super.initState();
    _fetchRecentMessages();
  }

  Future<void> _fetchRecentMessages() async {
    setState(() { _loadingRecentMessages = true; });
    try {
      print('Appel API toptendiscutionforum');
      final response = await http.post(
        Uri.parse('https://embmission.com/mobileappebm/api/toptendiscutionforum'),
        headers: {'Content-Type': 'application/json'},
      );
      print('Status code: \\${response.statusCode}');
      print('Body: \\${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'true' && data['alldataforums'] != null) {
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
      print('Erreur lors de l\'appel API: \\$e');
      setState(() { _recentMessages = []; _loadingRecentMessages = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('CommunityScreen build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communauté'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implémenter les notifications
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications à venir')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de catégorie
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: CategoryButton.withLabel(
                      label: category,
                      isSelected: _selectedCategory == category,
                      color: AppTheme.communityColor,
                      icon: _getCategoryIcon(category),
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Contenu principal
          Expanded(
            child: _selectedCategory == 'Tous' 
                ? _buildAllContent() 
                : _buildCategoryContent(_selectedCategory),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implémenter la création de message ou événement
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Création de message à venir')),
          );
        },
        backgroundColor: AppTheme.communityColor,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildAllContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Événements à venir'),
        _buildEventCard(
          'Culte d\'adoration', 
          'Dimanche 30 Juin 2025, 10:00',
          'Église EMB Centre',
          Icons.church,
        ),
        _buildEventCard(
          'Étude biblique', 
          'Mercredi 3 Juillet 2025, 19:00',
          'Salle communautaire',
          Icons.menu_book,
        ),
        
        const SizedBox(height: 24),
        _buildSectionTitle('Groupes actifs'),
        _buildGroupCard(
          'Groupe de prière',
          '15 membres',
          'Actif maintenant',
          Icons.people,
        ),
        _buildGroupCard(
          'Jeunesse EMB',
          '32 membres',
          'Dernier message il y a 2h',
          Icons.emoji_people,
        ),
        
        const SizedBox(height: 24),
        _buildSectionTitle('Messages récents'),
        if (_loadingRecentMessages)
          const Center(child: CircularProgressIndicator()),
        if (!_loadingRecentMessages && _recentMessages.isEmpty)
          const Text('Aucun message récent.'),
        if (!_loadingRecentMessages && _recentMessages.isNotEmpty)
          ..._recentMessages.map((msg) => _buildRecentForumMessageCard(msg)).toList(),
      ],
    );
  }
  
  Widget _buildCategoryContent(String category) {
    switch (category) {
      case 'Événements':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildEventCard(
              'Culte d\'adoration', 
              'Dimanche 30 Juin 2025, 10:00',
              'Église EMB Centre',
              Icons.church,
            ),
            _buildEventCard(
              'Étude biblique', 
              'Mercredi 3 Juillet 2025, 19:00',
              'Salle communautaire',
              Icons.menu_book,
            ),
            _buildEventCard(
              'Réunion de prière', 
              'Vendredi 5 Juillet 2025, 18:30',
              'Salle de prière',
              Icons.nights_stay,
            ),
          ],
        );
      case 'Groupes':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGroupCard(
              'Groupe de prière',
              '15 membres',
              'Actif maintenant',
              Icons.people,
            ),
            _buildGroupCard(
              'Jeunesse EMB',
              '32 membres',
              'Dernier message il y a 2h',
              Icons.emoji_people,
            ),
            _buildGroupCard(
              'Étude biblique',
              '24 membres',
              'Dernier message hier',
              Icons.book,
            ),
            _buildGroupCard(
              'Chorale',
              '18 membres',
              'Dernier message il y a 3j',
              Icons.music_note,
            ),
          ],
        );
      case 'Messages':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMessageCard(
              'Annonce importante',
              'Pasteur Jean',
              'Chers frères et sœurs, nous vous rappelons que...',
              DateTime.now().subtract(const Duration(hours: 3)),
            ),
            _buildMessageCard(
              'Témoignage de guérison',
              'Marie L.',
              'Je souhaite partager avec vous comment Dieu a...',
              DateTime.now().subtract(const Duration(days: 1)),
            ),
            _buildMessageCard(
              'Besoin de prière',
              'Thomas B.',
              'Bonjour à tous, je traverse une période difficile et...',
              DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        );
      default:
        return const Center(child: Text('Contenu à venir'));
    }
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildEventCard(String title, String date, String location, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.communityColor.withOpacity(0.2),
          child: Icon(icon, color: AppTheme.communityColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date),
            Text(location),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () {
            // TODO: Ajouter au calendrier
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ajouté au calendrier')),
            );
          },
        ),
        isThreeLine: true,
        onTap: () {
          // TODO: Afficher les détails de l'événement
        },
      ),
    );
  }
  
  Widget _buildGroupCard(String name, String members, String status, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.communityColor.withOpacity(0.2),
          child: Icon(icon, color: AppTheme.communityColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(members),
            Text(status, style: TextStyle(color: Colors.green[700])),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        isThreeLine: true,
        onTap: () {
          // TODO: Ouvrir le groupe
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ouverture du groupe $name')),
          );
        },
      ),
    );
  }
  
  Widget _buildMessageCard(String title, String author, String content, DateTime time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatDate(time.toIso8601String()),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Par $author',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: Lire la suite
                  },
                  child: const Text('Lire la suite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentForumMessageCard(RecentForumMessage msg) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    msg.content != null && msg.content!.isNotEmpty
                        ? (msg.content!.length > 40 ? msg.content!.substring(0, 40) + '...' : msg.content!)
                        : 'Message',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _formatDate(msg.datePost),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Par ${msg.authorName}',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (msg.content != null && msg.content!.isNotEmpty)
              Text(
                msg.content!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${msg.nbrReponses} réponses • ${msg.nbrVues} vues', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // TODO: Naviguer vers le détail du message forum
                  },
                  child: const Text('Lire la suite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
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
      return dateString; // Retourner la chaîne originale si le parsing échoue
    }
  }
  
  /// Retourne l'icône correspondant à la catégorie
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Événements':
        return Icons.event;
      case 'Groupes':
        return Icons.group;
      case 'Messages':
        return Icons.message;
      case 'Tous':
      default:
        return Icons.category;
    }
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
