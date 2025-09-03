import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';

import 'package:emb_mission/core/models/testimony.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:emb_mission/core/widgets/category_button.dart';
import 'package:emb_mission/core/widgets/testimony_card.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

/// Provider pour la catégorie de témoignage sélectionnée (enum)
final selectedTestimonyCategoryProvider = StateProvider<TestimonyCategory?>((ref) => null);

final testimonyCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/categorie_testimony'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['success'] == 'true' && data['prayercategories'] != null) {
      return List<String>.from(data['prayercategories'].map((c) => c['name']));
    }
  }
  // fallback statique si l'API échoue
  return ['Guérison', 'Prière', 'Famille', 'Travail'];
});

/// Écran des témoignages
class TestimoniesScreen extends ConsumerStatefulWidget {
  const TestimoniesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TestimoniesScreen> createState() => _TestimoniesScreenState();
}

class _TestimoniesScreenState extends ConsumerState<TestimoniesScreen> {
  bool _isSearching = false;
  String _searchQuery = '';

  // Fonction helper pour arrêter la radio live
  Future<void> _stopRadioIfPlaying() async {
    final radioPlayer = ref.read(radioPlayerProvider);
    final radioPlaying = ref.read(radioPlayingProvider);
    
    if (radioPlaying) {
      print('[TESTIMONIES] Arrêt complet de la radio live avant lecture audio');
      try {
        // Arrêter le player audio
        await radioPlayer.stop();
        // Mettre à jour l'état du provider
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        // Forcer l'arrêt complet via la méthode stopRadio
        await ref.read(radioPlayingProvider.notifier).stopRadio();
        print('[TESTIMONIES] Radio live arrêtée avec succès');
      } catch (e) {
        print('[TESTIMONIES] Erreur lors de l\'arrêt de la radio: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final testimoniesAsync = ref.watch(testimoniesProvider);
    final selectedCategory = ref.watch(selectedTestimonyCategoryProvider);
    final categoriesAsync = ref.watch(testimonyCategoriesProvider);

    // Harmonisation du preloader : un seul spinner global
    final bool _loadingPage = testimoniesAsync.isLoading || categoriesAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un témoignage…',
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
              backgroundColor: AppTheme.testimonyColor,
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Témoignages'),
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
        ],
      ),
      body: _loadingPage
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Catégories de témoignages
                _buildCategorySelector(ref),
                // Liste des témoignages
                Expanded(
                  child: testimoniesAsync.when(
                    data: (testimonies) {
                      // Filtrage par catégorie
                      final filteredByCategory = selectedCategory == null
                          ? testimonies
                          : testimonies.where((t) => t.category == selectedCategory).toList();
                      // Filtrage par recherche (auteur + contenu, insensible à la casse)
                      final filtered = _searchQuery.isEmpty
                          ? filteredByCategory
                          : filteredByCategory.where((t) =>
                              t.authorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              t.content.toLowerCase().contains(_searchQuery.toLowerCase())
                            ).toList();
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('Aucun témoignage trouvé'),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          final _ = await ref.refresh(testimoniesProvider.future);
                          return;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final testimony = filtered[index];
                            return TestimonyCard(
                              testimony: testimony,
                              onTap: () async => await _openTestimonyDetails(context, testimony),
                              onLike: () => _toggleLike(ref, testimony),
                              onFavoriteChanged: () => ref.invalidate(testimoniesProvider),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
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
        backgroundColor: AppTheme.testimonyColor,
        child: const Icon(Icons.add),
        onPressed: () {
          final userId = ref.read(userIdProvider);
          if (userId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veuillez vous connecter pour ajouter un témoignage.')),
            );
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const WelcomeScreen(),
            );
          } else {
            _showAddTestimonyDialog(context, ref, scaffoldContext: context);
          }
        },
      ),
    );
  }

  /// Construit le sélecteur de catégorie
  Widget _buildCategorySelector(WidgetRef ref) {
    final selectedCategory = ref.watch(selectedTestimonyCategoryProvider);
    final categoriesAsync = ref.watch(testimonyCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        return SizedBox(
          height: 60,
          child: ClipRect(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Bouton "Tous"
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 80,
                    height: 56,
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedTestimonyCategoryProvider.notifier).state = null;
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: selectedCategory == null
                              ? AppTheme.testimonyColor.withOpacity(0.2)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: selectedCategory == null
                              ? Border.all(color: AppTheme.testimonyColor, width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.all_inclusive,
                              color: selectedCategory == null
                                  ? AppTheme.testimonyColor
                                  : Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tous',
                              style: TextStyle(
                                color: selectedCategory == null
                                    ? AppTheme.testimonyColor
                                    : Colors.grey[800],
                                fontSize: 11,
                                fontWeight: selectedCategory == null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Boutons dynamiques pour chaque catégorie (mapping sur enum)
                for (final name in categories)
                  if (_enumFromName(name) != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 80,
                        height: 56,
                        child: CategoryButton.testimonyCategory(
                          category: _enumFromName(name)!,
                          isSelected: selectedCategory == _enumFromName(name),
                          onTap: () {
                            final enumCat = _enumFromName(name);
                            ref.read(selectedTestimonyCategoryProvider.notifier).state =
                              selectedCategory == enumCat ? null : enumCat;
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  TestimonyCategory? _enumFromName(String name) {
    switch (name.toLowerCase()) {
      case 'guérison':
        return TestimonyCategory.healing;
      case 'prière':
        return TestimonyCategory.prayer;
      case 'famille':
        return TestimonyCategory.family;
      case 'travail':
        return TestimonyCategory.work;
      default:
        return null;
    }
  }

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'guérison':
        return Icons.favorite;
      case 'prière':
        return Icons.volunteer_activism;
      case 'famille':
        return Icons.family_restroom;
      case 'travail':
        return Icons.work;
      default:
        return Icons.category;
    }
  }

  /// Ouvre les détails d'un témoignage
  Future<void> _openTestimonyDetails(BuildContext context, Testimony testimony) async {
    // Arrêter la radio live si elle joue
    await _stopRadioIfPlaying();
    
    // Navigation vers les détails du témoignage
    context.pushNamed('testimony-details', extra: testimony);
  }

  /// Ajoute ou supprime un like sur un témoignage
  void _toggleLike(WidgetRef ref, Testimony testimony) async {
    final contentService = ref.read(contentServiceProvider);
    await contentService.toggleTestimonyLike(testimony);
    final _ = await ref.refresh(testimoniesProvider.future);
    return;
  }

  /// Affiche le dialogue d'ajout de témoignage
  void _showAddTestimonyDialog(BuildContext context, WidgetRef ref, {required BuildContext scaffoldContext}) {
    String _generateRandomId() {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final random = Random();
      return List.generate(
        10,
        (index) => chars[random.nextInt(chars.length)],
        growable: false,
      ).join();
    }
    final TextEditingController nameController = TextEditingController();
    final TextEditingController contentController = TextEditingController();
    TestimonyCategory selectedCategory = TestimonyCategory.healing;
    InputMode selectedMode = InputMode.text;
    final AudioRecorder audioRecorder = AudioRecorder();
    bool isRecording = false;
    String? audioPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? errorMessage;
            Future<void> startRecording() async {
              if (await audioRecorder.hasPermission()) {
                String filePath = await getApplicationDocumentsDirectory()
                    .then((value) => '${value.path}/${_generateRandomId()}.m4a');
                await audioRecorder.start(
                  const RecordConfig(encoder: AudioEncoder.aacLc),
                  path: filePath,
                );
                setState(() {
                  isRecording = true;
                  audioPath = filePath;
                });
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    const SnackBar(content: Text('Permission micro refusée. Activez-la dans les paramètres du téléphone.')),
                  );
                }
              }
            }
            Future<void> stopRecording() async {
              await audioRecorder.stop();
              setState(() {
                isRecording = false;
              });
            }
            void toggleRecording() async {
              if (isRecording) {
                await stopRecording();
              } else {
                await startRecording();
              }
            }
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Message d'erreur en haut du formulaire
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // En-tête
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.testimonyColor,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Partager un témoignage',
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
                          // Nom
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Votre nom',
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
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final category in TestimonyCategory.values)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: CategoryButton.testimonyCategory(
                                      category: category,
                                      isSelected: selectedCategory == category,
                                      onTap: () {
                                        setState(() {
                                          selectedCategory = category;
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Mode de saisie
                          Text(
                            'Mode de saisie',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedMode = InputMode.text;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: selectedMode == InputMode.text
                                          ? AppTheme.testimonyColor.withOpacity(0.2)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border: selectedMode == InputMode.text
                                          ? Border.all(
                                              color: AppTheme.testimonyColor,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.text_fields,
                                          color: selectedMode == InputMode.text
                                              ? AppTheme.testimonyColor
                                              : Colors.grey[600],
                                          size: 24,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Texte',
                                          style: TextStyle(
                                            color: selectedMode == InputMode.text
                                                ? AppTheme.testimonyColor
                                                : Colors.grey[800],
                                            fontWeight: selectedMode == InputMode.text
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedMode = InputMode.audio;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: selectedMode == InputMode.audio
                                          ? AppTheme.testimonyColor.withOpacity(0.2)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border: selectedMode == InputMode.audio
                                          ? Border.all(
                                              color: AppTheme.testimonyColor,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.mic,
                                          color: selectedMode == InputMode.audio
                                              ? AppTheme.testimonyColor
                                              : Colors.grey[600],
                                          size: 24,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Audio',
                                          style: TextStyle(
                                            color: selectedMode == InputMode.audio
                                                ? AppTheme.testimonyColor
                                                : Colors.grey[800],
                                            fontWeight: selectedMode == InputMode.audio
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Contenu
                          if (selectedMode == InputMode.text)
                            TextField(
                              controller: contentController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                labelText: 'Votre témoignage',
                                hintText: 'Partagez votre expérience...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 160,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: toggleRecording,
                                      child: CircleAvatar(
                                        radius: 32,
                                        backgroundColor: isRecording ? Colors.red : AppTheme.testimonyColor,
                                        child: Icon(
                                          isRecording ? Icons.stop : Icons.mic,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isRecording
                                          ? 'Enregistrement en cours...'
                                          : (audioPath != null ? 'Enregistrement prêt !' : 'Appuyez pour enregistrer'),
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    if (audioPath != null && !isRecording)
                                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                  ],
                                ),
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
                              onPressed: () async {
                                print('Bouton Partager cliqué');
                                final userId = ref.read(userIdProvider);
                                print('userId: $userId');
                                if (userId == null) {
                                  print('userId est null');
                                  setState(() => errorMessage = 'Veuillez vous connecter.');
                                  return;
                                }
                                if (nameController.text.trim().isEmpty) {
                                  print('nom vide');
                                  setState(() => errorMessage = 'Veuillez saisir votre nom.');
                                  return;
                                }
                                if (selectedCategory == null) {
                                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                    const SnackBar(content: Text('Veuillez choisir une catégorie.')),
                                  );
                                  return;
                                }
                                print('Mode sélectionné: $selectedMode');
                                print('Nom: ${nameController.text}');
                                print('Contenu texte: ${contentController.text}');
                                print('Audio path: $audioPath');
                                if (selectedMode == InputMode.text && contentController.text.trim().isEmpty) {
                                  print('Mode texte mais contenu vide');
                                  setState(() => errorMessage = 'Veuillez saisir un témoignage texte.');
                                  return;
                                }
                                if (selectedMode == InputMode.audio && (audioPath == null || !File(audioPath!).existsSync())) {
                                  print('Mode audio mais pas de fichier audio');
                                  setState(() => errorMessage = 'Veuillez enregistrer un audio.');
                                  return;
                                }
                                if (selectedMode == InputMode.audio && isRecording) {
                                  print('Enregistrement en cours, partage impossible');
                                  setState(() => errorMessage = 'Veuillez terminer l\'enregistrement avant de partager.');
                                  return;
                                }
                                setState(() => errorMessage = null);
                                print('Toutes les validations passées, début de l\'envoi API');
                                try {
                                  final uri = Uri.parse('https://embmission.com/mobileappebm/api/storetemoignages');
                                  print('URI: $uri');
                                  
                                  // Validation des données avant envoi
                                  if (nameController.text.trim().isEmpty) {
                                    setState(() => errorMessage = 'Le nom est requis.');
                                    return;
                                  }
                                  
                                  if (selectedMode == InputMode.text && contentController.text.trim().isEmpty) {
                                    setState(() => errorMessage = 'Le contenu est requis.');
                                    return;
                                  }
                                  
                                  if (selectedMode == InputMode.audio && (audioPath == null || !File(audioPath!).existsSync())) {
                                    setState(() => errorMessage = 'L\'enregistrement audio est requis.');
                                    return;
                                  }
                                  
                                  // Préparation des données avec la structure correcte attendue par l'API
                                  Map<String, dynamic> requestData = {
                                    'id_user': userId.toString(),
                                    'category_id': _categoryIdFromEnum(selectedCategory).toString(),
                                    'nom': nameController.text.trim(),
                                    'content': selectedMode == InputMode.text ? contentController.text.trim() : '',
                                    'audio': '',
                                  };
                                  
                                  // Conversion audio en base64 si présent
                                  if (selectedMode == InputMode.audio && audioPath != null && File(audioPath!).existsSync()) {
                                    print('Conversion du fichier audio en base64: $audioPath');
                                    try {
                                      final audioFile = File(audioPath!);
                                      final audioBytes = await audioFile.readAsBytes();
                                      final audioBase64 = base64Encode(audioBytes);
                                      requestData['audio'] = 'data:audio/mpeg;base64,$audioBase64';
                                      print('Audio converti en base64 (${audioBase64.length} caractères)');
                                    } catch (e) {
                                      print('Erreur lors de la conversion audio: $e');
                                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                        const SnackBar(
                                          content: Text('Erreur lors de la conversion audio'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                  
                                  print('Données à envoyer: ${requestData.keys}');
                                  print('Contenu des données: $requestData');
                                  
                                  // Envoi en JSON avec timeout
                                  final response = await http.post(
                                    uri,
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'Accept': 'application/json',
                                    },
                                    body: jsonEncode(requestData),
                                  ).timeout(const Duration(seconds: 30));
                                  
                                  print('Réponse reçue, status: ${response.statusCode}');
                                  print('Corps de la réponse: ${response.body}');
                                  
                                  if (response.statusCode == 200) {
                                    try {
                                      final data = jsonDecode(response.body);
                                      print('Données décodées: $data');
                                      if (data['success'] == true || data['success'] == 'true' || data['status'] == 'true') {
                                        print('Succès de l\'API');
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                            const SnackBar(
                                              content: Text('Témoignage partagé avec succès!'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          ref.refresh(testimoniesProvider);
                                        }
                                      } else {
                                        print('Échec de l\'API: ${data['message'] ?? data['error']}');
                                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                          SnackBar(
                                            content: Text('Erreur: ${data['message'] ?? data['error'] ?? 'Échec de l\'envoi.'}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      print('Erreur lors du décodage de la réponse: $e');
                                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                        const SnackBar(
                                          content: Text('Erreur lors du traitement de la réponse'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } else if (response.statusCode == 500) {
                                    print('Erreur serveur 500');
                                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('Erreur serveur. Veuillez réessayer plus tard.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } else {
                                    print('Erreur HTTP: ${response.statusCode}');
                                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur réseau: ${response.statusCode}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('Exception: $e');
                                  String errorMessage = 'Erreur inattendue';
                                  if (e.toString().contains('TimeoutException')) {
                                    errorMessage = 'Délai d\'attente dépassé. Veuillez réessayer.';
                                  } else if (e.toString().contains('SocketException')) {
                                    errorMessage = 'Problème de connexion réseau.';
                                  }
                                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMessage),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (selectedMode == InputMode.audio && isRecording) 
                                    ? Colors.grey[400] 
                                    : AppTheme.testimonyColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Partager',
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

  int _categoryIdFromEnum(TestimonyCategory cat) {
    switch (cat) {
      case TestimonyCategory.healing:
        return 1;
      case TestimonyCategory.prayer:
        return 2;
      case TestimonyCategory.family:
        return 3;
      case TestimonyCategory.work:
        return 4;
    }
  }
}
