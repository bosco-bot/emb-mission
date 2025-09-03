import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:emb_mission/core/models/content_item.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/widgets/content_card.dart';
import 'package:emb_mission/core/theme/app_theme.dart';

/// Provider pour la requête de recherche
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider pour le filtre de recherche
final searchFilterProvider = StateProvider<String>((ref) => 'Tous');

/// Écran de recherche de l'application
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = ['Tous', 'Audio', 'Vidéo', 'Articles'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(searchQueryProvider.notifier).state = _searchController.text;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchFilterProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.primaryColor,
              child: const Text(
                'emb',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Recherche'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher du contenu...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Filtres
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final isSelected = _filters[index] == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref.read(searchFilterProvider.notifier).state = _filters[index];
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 51), // 0.2 * 255 = 51
                    checkmarkColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          // Résultats de recherche
          Expanded(
            child: searchResultsAsync.when(
              data: (results) {
                if (results.isEmpty) {
                  return const Center(
                    child: Text('Aucun résultat trouvé'),
                  );
                }

                // Filtrer les résultats selon le filtre sélectionné
                final filteredResults = filter == 'Tous'
                    ? results
                    : results.where((item) {
                        switch (filter) {
                          case 'Audio':
                            return item.type == ContentType.audio;
                          case 'Vidéo':
                            return item.type == ContentType.video;
                          case 'Articles':
                            return item.type == ContentType.article;
                          default:
                            return true;
                        }
                      }).toList();

                // Grouper les résultats par type
                final audioResults = filteredResults
                    .where((item) => item.type == ContentType.audio)
                    .toList();
                final videoResults = filteredResults
                    .where((item) => item.type == ContentType.video)
                    .toList();
                final articleResults = filteredResults
                    .where((item) => item.type == ContentType.article)
                    .toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Audio
                      if (audioResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, top: 16, bottom: 8),
                          child: Row(
                            children: [
                              const Text(
                                'Audio',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${audioResults.length} résultats',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: audioResults.length,
                          itemBuilder: (context, index) {
                            return ContentCard(
                              item: audioResults[index],
                              isHorizontal: true,
                              onTap: () {},
                            );
                          },
                        ),
                      ],

                      // Section Vidéo
                      if (videoResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, top: 16, bottom: 8),
                          child: Row(
                            children: [
                              const Text(
                                'Vidéo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${videoResults.length} résultats',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: videoResults.length,
                          itemBuilder: (context, index) {
                            return ContentCard(
                              item: videoResults[index],
                              isHorizontal: true,
                              onTap: () {},
                            );
                          },
                        ),
                      ],

                      // Section Articles
                      if (articleResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, top: 16, bottom: 8),
                          child: Row(
                            children: [
                              const Text(
                                'Articles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${articleResults.length} résultats',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: articleResults.length,
                          itemBuilder: (context, index) {
                            return ContentCard(
                              item: articleResults[index],
                              isHorizontal: true,
                              onTap: () {},
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Erreur de chargement: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
