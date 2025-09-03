import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:emb_mission/features/radio/screens/radio_screen.dart';
import 'package:emb_mission/features/tv/screens/tv_live_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:emb_mission/features/home/presentation/providers/home_providers.dart';
import 'package:emb_mission/features/home/domain/entities/content_item_entity.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/models/content_item.dart';
import 'package:emb_mission/core/widgets/content_card.dart';
import 'package:flutter/services.dart'; // Added for MethodChannel

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final AudioPlayer player;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    player = ref.read(radioPlayerProvider);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = _searchQuery.isNotEmpty ? ref.watch(searchResultsProvider(_searchQuery)) : null;
    final todayContent = ref.watch(todayContentProvider);
    final popularStats = ref.watch(popularStatsProvider);

    final isLoading =
      (_searchQuery.isNotEmpty && searchResults != null && searchResults.isLoading) ||
      todayContent.isLoading ||
      popularStats.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5DADE2),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE74C3C),
              radius: 16,
              child: const Text(
                'emb',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'EMB Mission',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final avatarUrl = ref.watch(userAvatarProvider);
              final isConnected = avatarUrl != null && avatarUrl.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(right: 0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withAlpha(51),
                  radius: 18,
                  backgroundImage: isConnected ? NetworkImage(avatarUrl!) : null,
                  child: !isConnected
                      ? const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre de recherche
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF5DADE2),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    autofocus: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (searchResults == null) return const SizedBox();
                      if (searchResults.hasError) {
                        return Center(child: Text('Erreur de recherche'));
                      }
                      final results = searchResults.value ?? [];
                      if (results.isEmpty) {
                        return const Center(child: Text('Aucun résultat'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return ContentCard(
                            item: item,
                            onTap: () {
                              // TODO: Naviguer vers le détail selon le type de contenu
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              if (_searchQuery.isEmpty)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Section Radio et TV Live
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Radio Live
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, _) => InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    context.go('/radio');
                                  },
                                  child: Container(
                                    height: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE74C3C),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/radio.svg',
                                          height: 24,
                                          width: 24,
                                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Radio Live',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // TV Live
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TVLiveScreen(
                                        tvName: 'EMB TV Live',
                                        streamUrl: 'https://stream.berosat.live:19360/emb-mission-stream/emb-mission-stream.m3u8',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  height: 80,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.tv,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'TV Live',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Séparateur avec bordure
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                      ),
                      // Contenus du jour
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contenus du jour',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                if (todayContent.hasError) {
                                  return Center(child: Text('Erreur de chargement'));
                                }
                                final todayContentList = todayContent.value ?? [];
                                if (todayContentList.isEmpty) {
                                  return const Text('Aucun contenu pour aujourd\'hui');
                                }
                                return Column(
                                  children: todayContentList.map<Widget>((item) {
                                    final isPrayer = (item.category == 'prière' || item.category == 'prayer');
                                    return _buildSimpleContentItem(
                                      backgroundColor: isPrayer ? const Color(0xFF5DADE2) : const Color(0xFF2ECC71),
                                      icon: isPrayer ? Icons.play_arrow : Icons.menu_book,
                                      title: item.title ?? '',
                                      time: item.description ?? '',
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Séparateur avec bordure
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                      ),
                      // Populaires cette semaine
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Populaires cette semaine',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                if (popularStats.hasError) {
                                  return Center(child: Text('Erreur de chargement'));
                                }
                                final stats = List.of(popularStats.value ?? [])
                                  ..sort((a, b) => b.nombreVues.compareTo(a.nombreVues));
                                if (stats.isEmpty) {
                                  return const Text('Aucun contenu populaire cette semaine');
                                }
                                // On attend 4 catégories : Témoignages, Prières, Forums, Groupes
                                final icons = [
                                  Icons.favorite, // Témoignages
                                  Icons.volunteer_activism, // Prières
                                  Icons.forum, // Forums
                                  Icons.group, // Groupes
                                ];
                                final colors = [
                                  const Color(0xFF5DADE2),
                                  const Color(0xFF2ECC71),
                                  Colors.orange,
                                  Colors.purple,
                                ];
                                // Disposition : 2 cartes par ligne, sur 2 lignes si besoin
                                List<Widget> rows = [];
                                for (int i = 0; i < stats.length; i += 2) {
                                  rows.add(Row(
                                    children: List.generate(2, (j) {
                                      final index = i + j;
                                      if (index >= stats.length) return const Expanded(child: SizedBox());
                                      final stat = stats[index];
                                      return Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(right: j == 0 ? 12 : 0),
                                          child: _buildPopularCard(
                                            color: colors[index % colors.length],
                                            icon: icons[index % icons.length],
                                            title: stat.titre,
                                            views: '${stat.nombreVues} vues',
                                          ),
                                        ),
                                      );
                                    }),
                                  ));
                                  rows.add(const SizedBox(height: 12));
                                }
                                if (rows.isNotEmpty) rows.removeLast(); // retire le dernier SizedBox
                                return Column(children: rows);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }
  
  
  Widget _buildPopularCard({
    required Color color,
    required IconData icon,
    required String title,
    required String views,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          views,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  /// Construit un élément de contenu simple avec une icône colorée à gauche
  /// et un fond gris léger avec des bordures légères
  Widget _buildSimpleContentItem({
    required Color backgroundColor,
    required IconData icon,
    required String title,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2), // Petit espace entre les éléments
      decoration: BoxDecoration(
        color: Colors.grey[100], // Fond gris très léger
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!, // Bordure légère
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icône avec fond coloré
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.grey[600],
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }
}
