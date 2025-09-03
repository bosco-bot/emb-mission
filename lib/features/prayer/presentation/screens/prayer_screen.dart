import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:emb_mission/core/models/prayer.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/services/preferences_service.dart';
import 'package:emb_mission/core/theme/app_theme.dart';

/// Provider pour les prières favorites
final favoritePrayersProvider = StateProvider<List<String>>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return preferencesService.getFavoritePrayers();
});

/// Provider pour les prières filtrées par catégorie
final filteredPrayersProvider = StateProvider<String>((ref) => 'Toutes');

/// Provider pour la liste des prières
final prayersProvider = FutureProvider<List<Prayer>>((ref) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getPrayers();
});

/// Écran des prières
class PrayerScreen extends ConsumerWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayersAsync = ref.watch(prayersProvider);
    final filter = ref.watch(filteredPrayersProvider);
    final favorites = ref.watch(favoritePrayersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.prayerColor,
              child: const Icon(
                Icons.volunteer_activism,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Prières'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => _showFavorites(context, ref),
          ),
        ],
      ),
      body: prayersAsync.when(
        data: (prayers) {
          return Column(
            children: [
              _buildFilters(context, ref),
              Expanded(
                child: prayers.isEmpty
                  ? const Center(child: Text('Aucune prière trouvée'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        final _ = await ref.refresh(prayersProvider.future);
                        return;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: prayers.length,
                        itemBuilder: (context, index) {
                          final prayer = prayers[index];
                          final isFavorite = favorites.contains(prayer.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(
                                    prayer.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    prayer.category ?? 'Prière',
                                    style: TextStyle(
                                      color: AppTheme.prayerColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.bookmark
                                          : Icons.bookmark_outline,
                                      color: isFavorite
                                          ? AppTheme.prayerColor
                                          : Colors.grey,
                                    ),
                                    onPressed: () => _toggleFavorite(ref, prayer.id),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    prayer.content,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.share,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.content_copy,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Erreur de chargement: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.prayerColor,
        child: const Icon(Icons.add),
        onPressed: () => _showAddPrayerDialog(context, ref),
      ),
    );
  }

  /// Construit les filtres de catégories
  Widget _buildFilters(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filteredPrayersProvider);
    final filters = ['Toutes', 'Favorites', 'Louange', 'Intercession', 'Remerciement', 'Délivrance'];
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final isSelected = filters[index] == filter;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filters[index]),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(filteredPrayersProvider.notifier).state = filters[index];
              },
              backgroundColor: Colors.grey[200],
              selectedColor: AppTheme.prayerColor.withOpacity(0.2),
              checkmarkColor: AppTheme.prayerColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.prayerColor : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Ajoute ou supprime une prière des favoris
  void _toggleFavorite(WidgetRef ref, String prayerId) {
    final preferencesService = ref.read(preferencesServiceProvider);
    final favorites = List<String>.from(ref.read(favoritePrayersProvider));
    
    if (favorites.contains(prayerId)) {
      favorites.remove(prayerId);
    } else {
      favorites.add(prayerId);
    }
    
    preferencesService.saveFavoritePrayers(favorites);
    ref.read(favoritePrayersProvider.notifier).state = favorites;
  }

  /// Affiche les prières favorites
  void _showFavorites(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(favoritePrayersProvider);
    
    if (favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas encore de prières favorites'),
        ),
      );
      return;
    }
    
    // Définir le filtre sur "Favorites"
    ref.read(filteredPrayersProvider.notifier).state = 'Favorites';
  }

  /// Affiche le dialogue d'ajout de prière
  void _showAddPrayerDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();
    String selectedCategory = 'Louange';
    
    final categories = ['Louange', 'Intercession', 'Remerciement', 'Délivrance'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // En-tête
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.prayerColor,
                            child: const Icon(
                              Icons.volunteer_activism,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Ajouter une prière',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Formulaire
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Titre
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: 'Titre de la prière',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Catégorie
                          Text(
                            'Catégorie',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: categories.map((category) {
                              final isSelected = category == selectedCategory;
                              
                              return ChoiceChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    selectedCategory = category;
                                  });
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: AppTheme.prayerColor.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.prayerColor : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          
                          // Contenu
                          TextField(
                            controller: contentController,
                            maxLines: 10,
                            decoration: InputDecoration(
                              labelText: 'Contenu de la prière',
                              hintText: 'Écrivez votre prière ici...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Boutons d'action
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (titleController.text.isNotEmpty &&
                                    contentController.text.isNotEmpty) {
                                  _submitPrayer(
                                    ref,
                                    titleController.text,
                                    contentController.text,
                                    selectedCategory,
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.prayerColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Ajouter',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Soumet une nouvelle prière
  void _submitPrayer(
    WidgetRef ref,
    String title,
    String content,
    String category,
  ) {
    // Simuler l'ajout d'une prière
    // Dans une vraie application, cela serait géré par le ContentService
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(
        content: Text('Prière ajoutée avec succès'),
      ),
    );
  }
}
