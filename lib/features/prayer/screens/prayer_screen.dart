import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import 'package:emb_mission/core/models/prayer.dart';
import 'package:emb_mission/core/models/prayer_category.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/services/preferences_service.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:emb_mission/core/widgets/audio_player_widget.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:just_audio/just_audio.dart';

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
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  
  // Variables pour le lecteur audio
  Map<String, AudioPlayer> _audioPlayers = {};
  Map<String, bool> _isPlaying = {};
  Map<String, Duration> _positions = {};
  Map<String, Duration> _durations = {};

  // 🚨 FONCTION ULTRA-SIMPLIFIÉE pour arrêter la radio live (MÊME LOGIQUE QUE CONTENTS_SCREEN)
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    print('[PRAYERS] 🎯 _stopRadioIfPlaying() appelé, radioPlaying: $radioPlaying');
    
    if (radioPlaying) {
      print('[PRAYERS] 🚨 ARRÊT DIRECT ET FORCÉ de la radio live avant lecture audio de prière');
      
      try {
        // 🎯 MÉTHODE ULTRA-SIMPLE: Arrêter TOUT de force comme dans contents_screen.dart
        
        // 1. Arrêter le player principal de force
        final radioPlayer = ref.read(radioPlayerProvider);
        await radioPlayer.stop();
        print('[PRAYERS] ✅ Player principal arrêté de force');
        
        // 2. Forcer l'état à false IMMÉDIATEMENT (comme dans contents_screen.dart)
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[PRAYERS] ✅ État forcé à false immédiatement');
        
        // 3. Arrêter AudioService de force (comme dans contents_screen.dart)
        try {
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          print('[PRAYERS] ✅ AudioService arrêté via stopRadio()');
        } catch (e) {
          print('[PRAYERS] ⚠️ stopRadio() échoué: $e');
        }
        
        print('[PRAYERS] 🎯 Radio live arrêtée avec succès (méthode ultra-simplifiée)');
        
      } catch (e) {
        print('[PRAYERS] ❌ Erreur lors de l\'arrêt: $e');
        
        // 🚨 DERNIÈRE TENTATIVE: Forcer l'état quoi qu'il arrive
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        print('[PRAYERS] 🚨 État forcé à false (dernière tentative)');
      }
    } else {
      print('[PRAYERS] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  /// Initialise le lecteur audio pour une prière
  void _initAudioPlayer(String prayerId, String audioUrl) {
    if (!_audioPlayers.containsKey(prayerId)) {
      final player = AudioPlayer();
      _audioPlayers[prayerId] = player;
      _isPlaying[prayerId] = false;
      _positions[prayerId] = Duration.zero;
      _durations[prayerId] = Duration.zero;

      // Écouter les changements de position
      player.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _positions[prayerId] = position;
          });
        }
      });

      // Écouter les changements de durée
      player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _durations[prayerId] = duration;
          });
        }
      });

      // Écouter les changements d'état
      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying[prayerId] = state.playing;
          });
        }
      });
    }
  }

  /// Gère la lecture/pause d'un audio
  Future<void> _handleAudioPlayPause(String prayerId, String audioUrl) async {
    // Arrêter la radio live si elle joue
    await _stopRadioIfPlaying();
    
    // Arrêter tous les autres lecteurs
    for (String id in _audioPlayers.keys) {
      if (id != prayerId && _isPlaying[id] == true) {
        await _audioPlayers[id]!.stop();
      }
    }

    final player = _audioPlayers[prayerId]!;
    
    if (_isPlaying[prayerId] == true) {
      // Mettre en pause
      await player.pause();
    } else {
      // Jouer
      if (player.processingState == ProcessingState.idle) {
        await player.setUrl(audioUrl);
      }
      await player.play();
    }
  }

  /// Libère les ressources du lecteur audio
  void _disposeAudioPlayer(String prayerId) {
    _audioPlayers[prayerId]?.dispose();
    _audioPlayers.remove(prayerId);
    _isPlaying.remove(prayerId);
    _positions.remove(prayerId);
    _durations.remove(prayerId);
  }

  @override
  void dispose() {
    // Libérer tous les lecteurs audio
    for (String prayerId in _audioPlayers.keys) {
      _disposeAudioPlayer(prayerId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayersAsync = ref.watch(prayersProvider);
    final categoriesAsync = ref.watch(prayerCategoriesProvider);
    final filter = ref.watch(filteredPrayersProvider);
    final favorites = ref.watch(favoritePrayersProvider);
    final userId = ref.watch(userIdProvider);

    final isLoading = prayersAsync.isLoading || categoriesAsync.isLoading;
    final hasError = prayersAsync.hasError || categoriesAsync.hasError;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasError) {
      return const Scaffold(
        body: Center(child: Text('Erreur de chargement')), 
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher une prière…',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : Row(
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
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => _showFavorites(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          categoriesAsync.when(
            data: (categories) => _buildFilters(context, ref, categories),
            loading: () => const SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const SizedBox(
              height: 50,
              child: Center(child: Text('Erreur de chargement des catégories')),
            ),
          ),
          
          // Liste des prières
          Expanded(
            child: prayersAsync.when(
              data: (prayers) {
                // Filtrage par recherche (titre + contenu)
                final filteredBySearch = _searchQuery.trim().isEmpty
                    ? prayers
                    : prayers.where((p) =>
                        p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        p.content.toLowerCase().contains(_searchQuery.toLowerCase())
                      ).toList();
                // Filtrer les prières selon le filtre sélectionné
                final filteredPrayers = filter == 'Toutes'
                    ? filteredBySearch
                    : filter == 'Favorites'
                        ? filteredBySearch.where((p) => favorites.contains(p.id)).toList()
                        : filteredBySearch.where((p) => p.category == filter).toList();

                if (filteredPrayers.isEmpty) {
                  return const Center(
                    child: Text('Aucune prière trouvée'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final _ = await ref.refresh(prayersProvider.future);
                    return;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPrayers.length,
                    itemBuilder: (context, index) {
                      final prayer = filteredPrayers[index];
                      final isFavorite = favorites.contains(prayer.id);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Navigation vers l'écran de détail de prière
                            context.pushNamed('prayer_detail', pathParameters: {'id': prayer.id});
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // En-tête avec titre et bouton favori
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
                            
                            // Contenu de la prière
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
                            
                            // Lecteur audio si disponible
                            if (prayer.audioUrl != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: _buildPrayerAudioPlayer(prayer),
                              ),
                            
                            // Boutons d'action
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Bouton Partager
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      final text = '${prayer.title}\n\n${prayer.content}';
                                      Share.share(text, subject: prayer.title);
                                    },
                                  ),
                                  // Bouton Copier
                                  IconButton(
                                    icon: const Icon(
                                      Icons.content_copy,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () async {
                                      final text = '${prayer.title}\n\n${prayer.content}';
                                      await Clipboard.setData(ClipboardData(text: text));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Prière copiée dans le presse-papiers')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      );
                    },
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.prayerColor,
        child: const Icon(Icons.add),
        onPressed: () {
          if (userId == null || userId.isEmpty) {
            // Rediriger vers la page de connexion/accueil
            context.pushNamed('welcome');
            return;
          }
          _showAddPrayerDialog(context, ref);
        },
      ),
    );
  }

  /// Construit les filtres de catégories
  Widget _buildFilters(BuildContext context, WidgetRef ref, List<PrayerCategoryModel> categories) {
    final filter = ref.watch(filteredPrayersProvider);
    
    // Créer la liste des filtres avec "Toutes" et "Favorites" en premier
    final List<String> filters = ['Toutes', 'Favorites'];
    filters.addAll(categories.map((cat) => cat.name));
    
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
    final _formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();
    String selectedCategory = 'Louange';
    bool isLoading = false;
    
    // Récupérer les catégories depuis le provider
    final categoriesAsync = ref.read(prayerCategoriesProvider);
    final categories = categoriesAsync.when(
      data: (cats) => cats.map((cat) => cat.name).toList(),
      loading: () => ['Louange', 'Intercession', 'Remerciement', 'Délivrance'],
      error: (_, __) => ['Louange', 'Intercession', 'Remerciement', 'Délivrance'],
    );
    final categoriesData = categoriesAsync.when(
      data: (cats) => cats,
      loading: () => [],
      error: (_, __) => [],
    );

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
                return Form(
                  key: _formKey,
                  child: Column(
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
                            TextFormField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: 'Titre de la prière',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Le titre est requis';
                                }
                                return null;
                              },
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
                            TextFormField(
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
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Le contenu est requis';
                                }
                                return null;
                              },
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
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (_formKey.currentState?.validate() ?? false) {
                                          final userId = ref.read(userIdProvider);
                                          if (userId == null || userId.isEmpty) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Vous devez être connecté pour ajouter une prière.')),
                                              );
                                            }
                                            return;
                                          }
                                          final selectedCatObj = categoriesData.where((cat) => cat.name == selectedCategory).toList();
                                          if (selectedCatObj.isEmpty) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Veuillez sélectionner une catégorie valide.')),
                                              );
                                            }
                                            return;
                                          }
                                          final categoryId = selectedCatObj.first.id;
                                          setState(() => isLoading = true);
                                          final url = Uri.parse('https://embmission.com/mobileappebm/api/save_prayers');
                                          final body = jsonEncode({
                                            'id_user': userId,
                                            'category_id': categoryId,
                                            'title': titleController.text.trim(),
                                            'content': contentController.text.trim(),
                                          });
                                          try {
                                            final response = await http.post(
                                              url,
                                              headers: {'Content-Type': 'application/json'},
                                              body: body,
                                            );
                                            print('Réponse API save_prayers: status=${response.statusCode}, body=${response.body}');
                                            final data = jsonDecode(response.body);
                                            if (response.statusCode == 200 && data['success'] == true) {
                                              if (context.mounted) {
                                                await ref.refresh(prayersProvider.future);
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Prière ajoutée avec succès !')),
                                                );
                                              }
                                            } else {
                                              if (context.mounted) {
                                                final errorMsg = data['message'] ?? 'Erreur lors de l\'ajout de la prière.';
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(errorMsg)),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Erreur réseau : $e')),
                                              );
                                            }
                                          } finally {
                                            if (context.mounted) setState(() => isLoading = false);
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.prayerColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text(
                                        'Ajouter',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Construit le lecteur audio pour une prière
  Widget _buildPrayerAudioPlayer(Prayer prayer) {
    final prayerId = prayer.id.toString();
    final audioUrl = prayer.audioUrl!;
    
    // Initialiser le lecteur si nécessaire
    _initAudioPlayer(prayerId, audioUrl);
    
    final isPlaying = _isPlaying[prayerId] ?? false;
    final position = _positions[prayerId] ?? Duration.zero;
    final duration = _durations[prayerId] ?? Duration.zero;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.prayerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Text(
            prayer.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          
          // Contrôles du lecteur
          Row(
            children: [
              // Bouton de lecture/pause
              InkWell(
                onTap: () => _handleAudioPlayPause(prayerId, audioUrl),
                borderRadius: BorderRadius.circular(30),
                                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  child: Center(
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Barre de progression
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: duration.inMilliseconds > 0 
                            ? position.inMilliseconds / duration.inMilliseconds 
                            : 0.0,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.prayerColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Durée
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formate la durée au format mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
