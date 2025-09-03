import 'package:flutter/material.dart';
import '../../../core/widgets/home_back_button.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/player/screens/player_screen.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:emb_mission/features/home/screens/home_screen.dart';
import 'package:audio_service/audio_service.dart';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:emb_mission/features/video_player/screens/video_player_screen.dart';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:emb_mission/core/data/local_models.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Fonction pour détecter le type de contenu basé sur l'URL
bool isVideoContent(String? fileUrl) {
  if (fileUrl == null || fileUrl.isEmpty) {
    print('[DEBUG] isVideoContent: URL null ou vide');
    return false;
  }
  
  print('[DEBUG] isVideoContent: Vérification de l\'URL: $fileUrl');
  
  // Détecter YouTube
  if (fileUrl.contains('youtube.com') || fileUrl.contains('youtu.be')) {
    print('[DEBUG] isVideoContent: URL YouTube détectée');
    return true;
  }
  
  // Détecter par extension
  final url = fileUrl.toLowerCase();
  final videoExtensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv', '.m4v', '.3gp', '.ts', '.mts'];
  final audioExtensions = ['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a', '.wma', '.aiff', '.au'];
  
  // Vérifier les extensions vidéo
  for (final ext in videoExtensions) {
    if (url.contains(ext)) {
      print('[DEBUG] isVideoContent: Extension vidéo détectée: $ext dans URL: $url');
      return true;
    }
  }
  
  // Vérifier les extensions audio
  for (final ext in audioExtensions) {
    if (url.contains(ext)) {
      print('[DEBUG] isVideoContent: Extension audio détectée: $ext dans URL: $url');
      return false;
    }
  }
  
  // Détecter par mots-clés dans l'URL
  final videoKeywords = ['video', 'videos', 'stream', 'live', 'broadcast', 'tv'];
  final audioKeywords = ['audio', 'podcast', 'music', 'sound', 'radio'];
  
  for (final keyword in videoKeywords) {
    if (url.contains(keyword)) {
      print('[DEBUG] isVideoContent: Mot-clé vidéo détecté: $keyword dans URL: $url');
      return true;
    }
  }
  
  for (final keyword in audioKeywords) {
    if (url.contains(keyword)) {
      print('[DEBUG] isVideoContent: Mot-clé audio détecté: $keyword dans URL: $url');
      return false;
    }
  }
  
  print('[DEBUG] isVideoContent: Aucun type détecté, considéré comme audio par défaut pour URL: $url');
  // Par défaut, considérer comme audio si ce n'est pas clairement vidéo
  return false;
}

String formatDurationFromSeconds(int? seconds) {
  if (seconds == null || seconds == 0) return '';
  final mins = (seconds / 60).round();
  return '$mins min';
}

// Fonction pour charger la position depuis Hive
int _loadPositionFromHive(int? contentId) {
  if (contentId == null) return 0;
  
  try {
    final box = Hive.box('progress');
    final existing = box.values.cast<LocalProgress?>().firstWhere(
      (p) => p?.contentId == contentId,
      orElse: () => null,
    );
    
    if (existing != null && existing.position > 0) {
      print('[CONTENTS] Position trouvée dans Hive pour $contentId: ${existing.position} secondes');
      return existing.position;
    }
  } catch (e) {
    print('[CONTENTS] Erreur lors du chargement de la position depuis Hive: $e');
  }
  
  return 0;
}

class ContentsScreen extends ConsumerStatefulWidget {
  const ContentsScreen({super.key});

  @override
  ConsumerState<ContentsScreen> createState() => _ContentsScreenState();
}

class _ContentsScreenState extends ConsumerState<ContentsScreen> {
  String selectedCategory = 'Enseignements';
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;
  bool hasErrorCategories = false;
  // ValueNotifier global pour l'état des favoris (id -> bool)
  final ValueNotifier<Map<int, bool>> favoriteStatusNotifier = ValueNotifier({});

  // Ajout pour la recherche
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  // Nouvelle variable pour stocker les contenus récents
  List<dynamic> allRecents = [];
  bool isLoadingRecents = false;
  bool hasErrorRecents = false;



  List<dynamic> listeningContents = [];
  bool isLoadingListening = false;
  bool hasErrorListening = false;

  // 🎧 NOUVELLES FONCTIONS SPOTIFY : Détection des URLs Spotify
  bool _isSpotifyUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    final urlLower = url.toLowerCase();
    return urlLower.contains('spotify.com') || 
           urlLower.contains('open.spotify.com') || 
           urlLower.contains('play.spotify.com') ||
           urlLower.startsWith('spotify:');
  }

  // 🎧 NOUVELLES FONCTIONS SPOTIFY : Vérification de l'installation de l'app Spotify
  Future<bool> _isSpotifyAppInstalled() async {
    try {
      // Vérifier si l'app Spotify est installée sur Android
      if (Platform.isAndroid) {
        final result = await PackageInfo.fromPlatform();
        // Vérifier si l'app Spotify est installée via package name
        final isInstalled = await _checkIfAppInstalled('com.spotify.music');
        print('[CONTENTS SPOTIFY] App Spotify installée sur Android: $isInstalled');
        return isInstalled;
      }
      // Sur iOS, on suppose que l'app est installée (limitation technique)
      else if (Platform.isIOS) {
        print('[CONTENTS SPOTIFY] iOS détecté - Supposition que Spotify est installé');
        return true;
      }
      return false;
    } catch (e) {
      print('[CONTENTS SPOTIFY] Erreur lors de la vérification Spotify: $e');
      return false;
    }
  }

  // 🎧 NOUVELLES FONCTIONS SPOTIFY : Vérification de l'installation d'une app Android
  Future<bool> _checkIfAppInstalled(String packageName) async {
    try {
      // Utiliser une approche simple : essayer d'ouvrir l'app
      final uri = Uri.parse('spotify:');
      final canLaunch = await canLaunchUrl(uri);
      print('[CONTENTS SPOTIFY] Test de lancement Spotify: $canLaunch');
      return canLaunch;
    } catch (e) {
      print('[CONTENTS SPOTIFY] Erreur test lancement Spotify: $e');
      return false;
    }
  }

  // 🎧 NOUVELLES FONCTIONS SPOTIFY : Gestion intelligente des liens Spotify
  Future<void> _handleSpotifyContent(String spotifyUrl, String title) async {
    try {
      print('[CONTENTS SPOTIFY] Gestion du contenu Spotify: $spotifyUrl');
      
      // Vérifier si l'app Spotify est installée
      final isSpotifyInstalled = await _isSpotifyAppInstalled();
      
      if (isSpotifyInstalled) {
        print('[CONTENTS SPOTIFY] App Spotify installée - Ouverture dans l\'app native');
        
        // Convertir l'URL web en deep link Spotify si nécessaire
        String deepLinkUrl = spotifyUrl;
        if (spotifyUrl.contains('open.spotify.com')) {
          deepLinkUrl = spotifyUrl.replaceFirst('https://open.spotify.com', 'spotify');
        } else if (spotifyUrl.contains('spotify.com') && !spotifyUrl.startsWith('spotify:')) {
          deepLinkUrl = spotifyUrl.replaceFirst('https://', 'spotify://');
        }
        
        print('[CONTENTS SPOTIFY] Deep link généré: $deepLinkUrl');
        
        // Essayer d'ouvrir dans l'app Spotify
        final uri = Uri.parse(deepLinkUrl);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (launched) {
          print('[CONTENTS SPOTIFY] ✅ Contenu ouvert dans l\'app Spotify');
        } else {
          print('[CONTENTS SPOTIFY] ⚠️ Échec ouverture app - Fallback vers web');
          _openSpotifyWeb(spotifyUrl);
        }
      } else {
        print('[CONTENTS SPOTIFY] App Spotify non installée - Fallback vers web');
        _openSpotifyWeb(spotifyUrl);
      }
    } catch (e) {
      print('[CONTENTS SPOTIFY] ❌ Erreur gestion Spotify: $e');
      // Fallback vers web en cas d'erreur
      _openSpotifyWeb(spotifyUrl);
    }
  }

  // 🎧 NOUVELLES FONCTIONS SPOTIFY : Fallback vers Spotify Web
  Future<void> _openSpotifyWeb(String spotifyUrl) async {
    try {
      print('[CONTENTS SPOTIFY] Ouverture via Spotify Web: $spotifyUrl');
      
      // S'assurer que l'URL est au format web
      String webUrl = spotifyUrl;
      if (spotifyUrl.startsWith('spotify:')) {
        webUrl = spotifyUrl.replaceFirst('spotify:', 'https://open.spotify.com/');
      }
      
      final uri = Uri.parse(webUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (launched) {
        print('[CONTENTS SPOTIFY] ✅ Contenu ouvert via Spotify Web');
      } else {
        print('[CONTENTS SPOTIFY] ❌ Échec ouverture Spotify Web');
        // Afficher un message d'erreur à l'utilisateur
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Impossible d\'ouvrir le lien Spotify'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('[CONTENTS SPOTIFY] ❌ Erreur ouverture Spotify Web: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchRecents();
    // _fetchListening(); // Désactivé - section "En cours d'écoute" supprimée
    _loadFavoritesFromHive();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharger les favoris quand on revient sur la page
    _loadFavoritesFromHive();
    
    // 🚨 NOUVEAU: Réinitialiser l'état radio quand on revient sur l'écran
    _resetRadioState();
  }
  
  // 🚨 CORRIGÉ: Fonction pour réinitialiser l'état radio de manière plus intelligente
  void _resetRadioState() {
    try {
      final radioPlaying = ref.read(radioPlayingProvider);
      final radioPlayer = ref.read(radioPlayerProvider);
      
      print('[CONTENTS] 🔄 DIAGNOSTIC RÉINITIALISATION - Retour sur l\'écran');
      print('[CONTENTS] 📊 radioPlayingProvider: $radioPlaying');
      print('[CONTENTS] 📊 Player playing: ${radioPlayer.playing}');
      print('[CONTENTS] 📊 Player hasAudio: ${radioPlayer.audioSource != null}');
      
      // 🚨 CORRECTION: Ne réinitialiser que si l'état est incohérent
      // Si radioPlayingProvider dit true mais le player n'a pas d'audio, alors réinitialiser
      if (radioPlaying && radioPlayer.audioSource == null && !radioPlayer.playing) {
        print('[CONTENTS] 🔄 État incohérent détecté - Réinitialisation nécessaire');
        
        Future.microtask(() {
          try {
            ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
            print('[CONTENTS] ✅ État radio réinitialisé à false (incohérence corrigée)');
          } catch (e) {
            print('[CONTENTS] ❌ Erreur lors de la mise à jour différée: $e');
          }
        });
        
      } else if (radioPlaying && (radioPlayer.audioSource != null || radioPlayer.playing)) {
        print('[CONTENTS] ✅ État cohérent - Pas de réinitialisation nécessaire');
      } else {
        print('[CONTENTS] ✅ Pas de réinitialisation nécessaire');
      }
    } catch (e) {
      print('[CONTENTS] ⚠️ Erreur lors de la réinitialisation radio: $e');
    }
  }

  // Fonction pour charger les favoris depuis Hive
  void _loadFavoritesFromHive() {
    final box = Hive.box('favorites');
    final favorites = <int, bool>{};
    
    for (final fav in box.values) {
      if (fav is LocalFavorite) {
        favorites[fav.contentId] = fav.isFavorite;
      }
    }
    
    favoriteStatusNotifier.value = favorites;
  }

  void _fetchRecents() async {
    setState(() {
      isLoadingRecents = true;
      hasErrorRecents = false;
    });
    try {
      final categoryMap = _categoryNameToId();
      final catId = categoryMap[selectedCategory] ?? 1;
      final userId = ref.read(userIdProvider);
      final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/viewcontentscategorie?id_categorie=$catId&userId=$userId'));
      final body = response.body;
      if (body.isEmpty || (!body.trim().startsWith('{') && !body.trim().startsWith('['))) {
        allRecents = [];
      } else {
        final data = jsonDecode(body);
        if (data['statDatacontent'] == 'success' && data['datacontent'] != null) {
          allRecents = List<dynamic>.from(data['datacontent']);
        } else {
          allRecents = [];
        }
      }
    } catch (e) {
      hasErrorRecents = true;
      allRecents = [];
    }
    setState(() {
      isLoadingRecents = false;
    });
  }

  Future<void> _fetchListening() async {
    setState(() {
      isLoadingListening = true;
      hasErrorListening = false;
    });
    
    // Lire les données de progression depuis Hive
    final box = Hive.box('progress');
    final categoryMap = _categoryNameToId();
    final catId = categoryMap[selectedCategory] ?? 1;
    
    // Récupérer les contenus en cours d'écoute depuis Hive pour cette catégorie
    final hiveProgress = box.values.cast<LocalProgress>().where((progress) {
      // Filtrer par catégorie
      if (selectedCategory == 'Replays') {
        return progress.category == 'Replays';
      } else if (selectedCategory == 'Enseignements') {
        return progress.category == 'Enseignements';
      } else if (selectedCategory == 'Podcasts') {
        return progress.category == 'Podcasts';
      }
      return false;
    }).toList();
    
    // Convertir les données Hive au format attendu par l'interface
    final hiveListeningContents = hiveProgress.map((progress) => {
      'id': progress.contentId,
      'contentId': progress.contentId,
      'title': progress.title,
      'speaker_name': progress.author,
      'file_url': progress.fileUrl,
      'duration': progress.duration,
      'position': progress.position,
      'categoryId': catId,
    }).toList();
    
    try {
      final userId = ref.read(userIdProvider);
      final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/listening_contents?userId=$userId&categoryId=$catId'));
      final body = response.body;
      if (body.isEmpty || (!body.trim().startsWith('{') && !body.trim().startsWith('['))) {
        // Si l'API échoue, utiliser seulement les données Hive
        listeningContents = hiveListeningContents;
      } else {
        final data = jsonDecode(body);
        if (data['statDatalistening'] == 'success' && data['datalistening'] != null) {
          final apiListeningContents = List<dynamic>.from(data['datalistening']);
          // Combiner les données API et Hive, en priorisant l'API
          final combinedContents = <Map<String, dynamic>>[];
          
          // Ajouter d'abord les données API
          for (final apiItem in apiListeningContents) {
            combinedContents.add(Map<String, dynamic>.from(apiItem));
          }
          
          // Ajouter les données Hive qui ne sont pas déjà dans l'API
          for (final hiveItem in hiveListeningContents) {
            final existsInApi = apiListeningContents.any((apiItem) => 
              apiItem['contentId'] == hiveItem['contentId'] || 
              apiItem['id'] == hiveItem['contentId']
            );
            if (!existsInApi) {
              combinedContents.add(hiveItem);
            }
          }
          
          listeningContents = combinedContents;
        } else {
          // Si l'API ne retourne pas de données, utiliser seulement Hive
          listeningContents = hiveListeningContents;
        }
      }
    } catch (e) {
      // En cas d'erreur, utiliser seulement les données Hive
      listeningContents = hiveListeningContents;
    }
    
    setState(() {
      isLoadingListening = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
      hasErrorCategories = false;
    });
    try {
      final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/viewsectioncategorie'));
      final decoded = jsonDecode(response.body);
      if (decoded['statDatacontentcat'] == 'success') {
        categories = List<Map<String, dynamic>>.from(decoded['datacontentcat']);
        // Sélectionne Enseignements par défaut si présent
        if (categories.any((e) => e['name'] == 'Enseignements')) {
          selectedCategory = 'Enseignements';
        } else if (categories.isNotEmpty) {
          selectedCategory = categories.first['name'];
        }
      } else {
        hasErrorCategories = true;
      }
    } catch (e) {
      hasErrorCategories = true;
    }
    setState(() {
      isLoadingCategories = false;
    });
  }

  Map<String, int> _categoryNameToId() {
    final map = <String, int>{};
    for (final cat in categories) {
      if (cat['name'] != null && cat['id'] != null) {
        map[cat['name']] = cat['id'] is int ? cat['id'] : int.tryParse(cat['id'].toString()) ?? 0;
      }
    }
    return map;
  }

  void _showAllContentsModal(BuildContext context) {
    final categoryMap = _categoryNameToId();
    final catId = categoryMap[selectedCategory] ?? 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _AllContentsModal(
          catId: catId,
          selectedCategory: selectedCategory,
          userId: ref.read(userIdProvider.notifier).state ?? '', // 🚨 NOUVEAU: Ajout du userId
          buildRecentItem: _buildRecentItem,
          favoriteStatusNotifier: favoriteStatusNotifier,
        );
      },
    );
  }

  // 🚨 FONCTION UNIFORMISÉE : Logique différenciée selon la catégorie
  Future<void> _stopRadioIfPlaying() async {
    final radioPlaying = ref.read(radioPlayingProvider);
    
    if (radioPlaying) {
      print('[CONTENTS] Arrêt complet de la radio live avant lecture audio');
      print('[CONTENTS] 🔍 Catégorie sélectionnée: $selectedCategory');
      
      if (selectedCategory == 'Replays') {
        print('[CONTENTS] 🚨 REPLAY DÉTECTÉ - Utilisation nouvelle méthode simple');
        try {
          // 🚨 NOUVEAU: Activer la variable globale pour forcer la fermeture de la carte
          print('[CONTENTS] 🔍 État AVANT activation: HomeScreen.forceCloseRadioCard = ${HomeScreen.forceCloseRadioCard}');
          HomeScreen.setForceCloseRadioCard(true);
          print('[CONTENTS] ✅ Variable globale _forceCloseRadioCard activée à true');
          print('[CONTENTS] 🔍 État APRÈS activation: HomeScreen.forceCloseRadioCard = ${HomeScreen.forceCloseRadioCard}');
          
          // Utiliser la fonction publique de HomeScreen (même logique que le bouton de fermeture)
          await HomeScreen.stopRadioLive(ref);
          print('[CONTENTS] Radio live arrêtée avec succès via HomeScreen.stopRadioLive');
          
          // 🚨 NOUVEAU: Vérification finale de l'état de la variable
          print('[CONTENTS] 🔍 État FINAL: HomeScreen.forceCloseRadioCard = ${HomeScreen.forceCloseRadioCard}');
        } catch (e) {
          print('[CONTENTS] ❌ Erreur lors de l\'arrêt de la radio: $e');
        }
      } else {
        print('[CONTENTS] ✅ Enseignement/Podcast - Utilisation ancienne méthode complexe');
        try {
          // 🚨 ANCIENNE MÉTHODE COMPLEXE pour enseignements et podcasts
          final radioPlayer = ref.read(radioPlayerProvider);
          await radioPlayer.stop();
          
          // Mettre à jour l'état du provider
          ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
          
          // Forcer l'arrêt complet via la méthode stopRadio
          await ref.read(radioPlayingProvider.notifier).stopRadio();
          
          print('[CONTENTS] ✅ Radio live arrêtée avec succès via ancienne méthode complexe');
        } catch (e) {
          print('[CONTENTS] ❌ Erreur lors de l\'arrêt de la radio: $e');
        }
      }
    } else {
      print('[CONTENTS] ✅ Radio pas en cours de lecture, pas d\'arrêt nécessaire');
    }
  }

  Future<void> _showMiniPlayer(BuildContext context, {
    required String title,
    required String author,
    required String fileUrl,
    int? contentId,
    required ValueNotifier<Map<int, bool>> favoriteStatusNotifier,
    int? startPosition,
  }) async {
    debugPrint('[NAV] Appel PlayerScreen avec contentId=${contentId?.toString() ?? ''}');
    
    print('[CONTENTS] 🚨 _showMiniPlayer appelé - ARRÊT RADIO IMMINENT');
    
    // 🎧 NOUVELLE LOGIQUE SPOTIFY : Vérifier si c'est un contenu Spotify de la catégorie Podcasts
    if (selectedCategory == 'Podcasts' && _isSpotifyUrl(fileUrl)) {
      print('[CONTENTS SPOTIFY] 🎧 Contenu Spotify détecté dans la catégorie Podcasts');
      print('[CONTENTS SPOTIFY] Titre: $title');
      print('[CONTENTS SPOTIFY] URL: $fileUrl');
      
      // Gérer le contenu Spotify de manière intelligente
      await _handleSpotifyContent(fileUrl, title);
      return; // Sortir de la fonction - pas de navigation vers PlayerScreen
    }
    
    // ✅ COMPORTEMENT NORMAL pour tous les autres contenus (inchangé)
    print('[CONTENTS] ✅ Contenu normal - Utilisation du comportement standard');
    
    // Arrêter la radio live si elle joue
    print('[CONTENTS] 🚨 APPEL _stopRadioIfPlaying() depuis _showMiniPlayer');
    await _stopRadioIfPlaying();
    
    print('[CONTENTS] ✅ Radio arrêtée, navigation vers PlayerScreen');
    
    // Utiliser le router au lieu de MaterialPageRoute pour avoir l'AppBar principale
    final encodedTitle = Uri.encodeComponent(title);
    final encodedAuthor = Uri.encodeComponent(author);
    final encodedFileUrl = Uri.encodeComponent(fileUrl);
    final startPos = startPosition?.toString() ?? '0';
    
    context.go('/player/${contentId?.toString() ?? 'current'}?title=$encodedTitle&author=$encodedAuthor&fileUrl=$encodedFileUrl&startPosition=$startPos');
  }

  @override
  Widget build(BuildContext context) {
    final categoryMap = _categoryNameToId();
    return ValueListenableBuilder<Map<int, bool>>(
      valueListenable: favoriteStatusNotifier,
      builder: (context, favoriteMap, _) {
        // Gestion du chargement et des erreurs
        if (isLoadingCategories || isLoadingRecents || isLoadingListening) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (hasErrorCategories || hasErrorRecents || categories.isEmpty || hasErrorListening) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('Erreur de chargement')),
          );
        }
        // Filtrage selon la recherche
        List<dynamic> filteredRecents = allRecents;
        if (isSearching && searchQuery.isNotEmpty) {
          filteredRecents = allRecents.where((item) {
            final title = (item['title'] ?? '').toString().toLowerCase();
            final author = (item['speaker_name'] ?? '').toString().toLowerCase();
            return title.contains(searchQuery.toLowerCase()) || author.contains(searchQuery.toLowerCase());
          }).toList();
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const HomeBackButton(color: Colors.black87),
            title: isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher...',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contenus Audio',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Bibliothèque spirituelle',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
            actions: [
              if (!isSearching)
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      isSearching = true;
                    });
                  },
                ),
              if (isSearching)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      isSearching = false;
                      searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.black87),
                onPressed: () {},
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryCards(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // _buildListeningSection(), // Section désactivée
                      // const SizedBox(height: 24),
                      _buildRecentSectionWithData(filteredRecents, favoriteMap),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCards() {
    if (isLoadingCategories) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        decoration: const BoxDecoration(color: Color(0xFF4CB6FF)),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (hasErrorCategories || categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        decoration: const BoxDecoration(color: Color(0xFF4CB6FF)),
        child: const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.white))),
      );
    }
    // Ordre d'affichage : Enseignements, Podcasts, Replays
    final order = ['Enseignements', 'Podcasts', 'Replays'];
    final ordered = order
        .map((name) => categories.where((e) => e['name'] == name).isNotEmpty
            ? categories.firstWhere((e) => e['name'] == name)
            : null)
        .whereType<Map<String, dynamic>>()
        .toList();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: const BoxDecoration(color: Color(0xFF4CB6FF)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ordered.map((cat) {
            final name = cat['name'];
            final selected = selectedCategory == name;
            IconData icon;
            Color color;
            bool isWhite;
            String count;
            if (name == 'Enseignements') {
              icon = Icons.mic;
              color = selected ? const Color(0xFF64B5F6) : Colors.white;
              isWhite = !selected;
              count = '${cat['count']} contenus';
            } else if (name == 'Podcasts') {
              icon = Icons.headphones;
              color = selected ? const Color(0xFF64B5F6) : Colors.white;
              isWhite = !selected;
              count = '${cat['count']} épisodes';
            } else {
              icon = Icons.tv;
              color = selected ? const Color(0xFF64B5F6) : Colors.white;
              isWhite = !selected;
              count = '${cat['count']} vidéos';
            }
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategory = name;
                  _fetchRecents();
                  // _fetchListening(); // Désactivé - section "En cours d'écoute" supprimée
                  isSearching = false;
                  searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: selected ? Border.all(color: Colors.white, width: 3) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildCategoryCard(
                  color: color,
                  icon: icon,
                  title: name,
                  count: count,
                  isWhite: isWhite,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required Color color,
    required IconData icon,
    required String title,
    required String count,
    required bool isWhite,
  }) {
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: isWhite ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isWhite ? const Color(0xFF64B5F6) : Colors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isWhite ? Colors.black87 : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                count,
                style: TextStyle(
                  color: isWhite ? Colors.black54 : Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningSection() {
    if (isLoadingListening) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasErrorListening) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Erreur de chargement de la progression')), 
      );
    }
    final categoryMap = _categoryNameToId();
    final catId = categoryMap[selectedCategory] ?? 1;
    // Filtrage strict par catégorie
    final filteredListening = listeningContents.where((item) {
      final dynamic itemCatId = item['categoryId'] ?? item['categorie_id'] ?? item['catId'];
      return itemCatId != null && itemCatId.toString() == catId.toString();
    }).toList();
    if (filteredListening.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text("Aucun contenu en cours d'écoute pour cette catégorie")), 
      );
    }
    final item = filteredListening.first;
    final int? contentId = (item['contentId'] ?? item['id']) is int ? (item['contentId'] ?? item['id']) : int.tryParse((item['contentId'] ?? item['id']).toString());
    final int id = item['id'];
    final String title = item['title'] ?? '';
    final String author = item['speaker_name'] ?? '';
    final String fileUrl = item['file_url'] ?? '';
    final int duration = item['duration'] ?? 0;
    final int position = _loadPositionFromHive(contentId); // Utiliser la position depuis Hive
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "En cours d'écoute",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFF64B5F6),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  print('[DEBUG] Clic sur contenu en cours d\'écoute');
                  print('[DEBUG] fileUrl: $fileUrl');
                  print('[DEBUG] contentId: $contentId');
                  print('[DEBUG] title: $title');
                  
                  // 🚨 NOUVEAU: Arrêter la radio live SEULEMENT pour les Replays
                  final category = item['category'] ?? item['category_name'] ?? '';
                  print('[CONTENTS] 🔍 Catégorie du contenu en cours d\'écoute: $category');
                  
                  if (category == 'Replays') {
                    print('[CONTENTS] 🚨 REPLAY DÉTECTÉ - APPEL _stopRadioIfPlaying() depuis contenu en cours d\'écoute');
                    await _stopRadioIfPlaying();
                  } else {
                    print('[CONTENTS] ✅ Pas un replay - Pas d\'arrêt radio nécessaire (catégorie: $category)');
                  }
                  
                  // Détecter automatiquement le type de contenu
                  final isVideo = isVideoContent(fileUrl);
                  print('[DEBUG] isVideo détecté: $isVideo');
                  
                  if (isVideo) {
                    print('[DEBUG] Ouverture du lecteur vidéo');
                    // Ouvrir le lecteur vidéo en plein écran (masque la BottomNavBar)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          contentId: contentId?.toString() ?? '',
                          title: title,
                          author: author,
                          videoUrl: fileUrl,
                          favoriteStatusNotifier: favoriteStatusNotifier,
                          date: '',
                          description: '',
                          startPosition: position,
                        ),
                        fullscreenDialog: true, // Force l'affichage en plein écran
                      ),
                    );
                  } else {
                    print('[DEBUG] Ouverture du lecteur audio');
                    // Ouvrir le lecteur audio
                    await _showMiniPlayer(
                      context,
                      title: title,
                      author: author,
                      fileUrl: fileUrl,
                      contentId: contentId,
                      favoriteStatusNotifier: favoriteStatusNotifier,
                      startPosition: position,
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pause, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Ligne temps courant / durée totale
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(position),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          _formatTime(duration),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: duration > 0 ? position / duration : 0,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatShortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final day = date.day;
      final month = date.month;
      const months = [
        '', 'jan', 'fév', 'mar', 'avr', 'mai', 'jui',
        'jui', 'aoû', 'sep', 'oct', 'nov', 'déc'
      ];
      final monthStr = months[month];
      return '$day $monthStr';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildRecentSectionWithData(List<dynamic> recents, Map<int, bool> favoriteMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Récents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => _showAllContentsModal(context),
              child: const Text(
                'Voir tout',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64B5F6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recents.map((item) {
          final int? contentId = (item['contentId'] ?? item['id']) is int ? (item['contentId'] ?? item['id']) : int.tryParse((item['contentId'] ?? item['id']).toString());
          final int id = item['id'];
          final bool isFav = favoriteMap[id] ?? (item['isLikedByCurrentUser'] == true || item['isLikedByCurrentUser'] == 'true' || item['isLikedByCurrentUser'] == 1 || item['isLikedByCurrentUser'] == '1');
          
          // Charger la position depuis Hive
          final int position = _loadPositionFromHive(contentId);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecentItem(
              contentId: contentId,
              color: selectedCategory == 'Enseignements' ? Colors.green : selectedCategory == 'Podcasts' ? Colors.purple : Colors.blue,
              title: item['title'] ?? '',
              author: item['speaker_name'] ?? '',
              duration: item['duration'] != null ? formatDurationFromSeconds(item['duration']) : '',
              date: _formatShortDate(item['release_date']),
              fileUrl: item['file_url'] ?? '',
              isDownloadable: true,
              isFavorite: isFav,
              position: position,
              onFavoriteChanged: (newFav) {
                favoriteStatusNotifier.value = {
                  ...favoriteStatusNotifier.value,
                  id: newFav,
                };
                setState(() {
                  item['isLikedByCurrentUser'] = newFav;
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentItem({
    required int? contentId,
    required Color color,
    required String title,
    required String author,
    required String duration,
    required String date,
    String? fileUrl,
    required bool isDownloadable,
    required bool isFavorite,
    int? position,
    void Function(bool)? onFavoriteChanged,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final userId = ref.watch(userIdProvider);
        final ValueNotifier<bool> favoriteNotifier = ValueNotifier<bool>(isFavorite);
        return ValueListenableBuilder<bool>(
          valueListenable: favoriteNotifier,
          builder: (context, isFav, _) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        print('[DEBUG] Clic sur contenu récent');
                        print('[DEBUG] fileUrl: $fileUrl');
                        print('[DEBUG] contentId: $contentId');
                        print('[DEBUG] title: $title');
                        
                        if (fileUrl != null && fileUrl.isNotEmpty) {
                          // Vérification plus souple de l'URL
                          String finalFileUrl = fileUrl;
                          bool isValidUrl = false;
                          try {
                            final uri = Uri.parse(fileUrl);
                            // Accepter les URLs avec ou sans schéma
                            isValidUrl = uri.hasScheme || fileUrl.startsWith('http') || fileUrl.startsWith('https');
                          } catch (e) {
                            print('[DEBUG] Erreur parsing URL: $fileUrl, erreur: $e');
                            // Essayer de réparer l'URL si elle n'a pas de schéma
                            if (!fileUrl.startsWith('http')) {
                              final fixedUrl = 'https://$fileUrl';
                              try {
                                Uri.parse(fixedUrl);
                                isValidUrl = true;
                                finalFileUrl = fixedUrl; // Utiliser l'URL corrigée
                                print('[DEBUG] URL corrigée: $finalFileUrl');
                              } catch (e2) {
                                print('[DEBUG] Impossible de corriger l\'URL: $e2');
                              }
                            }
                          }
                          
                          if (!isValidUrl) {
                            print('[DEBUG] URL invalide: $fileUrl');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ URL invalide ou fichier corrompu'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }
                          
                          // Détecter automatiquement le type de contenu
                          final isVideo = isVideoContent(finalFileUrl);
                          print('[DEBUG] isVideo détecté: $isVideo');
                          
                          if (isVideo) {
                            print('[DEBUG] Ouverture du lecteur vidéo');
                            
                            // 🚨 NOUVEAU: Arrêter la radio live SEULEMENT pour les Replays
                            print('[CONTENTS] 🔍 Catégorie du replay vidéo: $selectedCategory');
                            
                            if (selectedCategory == 'Replays') {
                              print('[CONTENTS] 🚨 REPLAY VIDÉO DÉTECTÉ - Activation variable globale AVANT ouverture vidéo');
                              
                              // 🚨 FORCER l'activation de la variable globale pour TOUS les replays
                              HomeScreen.setForceCloseRadioCard(true);
                              print('[CONTENTS] ✅ Variable globale _forceCloseRadioCard activée à true pour replay vidéo');
                              
                              // Appeler _stopRadioIfPlaying() pour arrêter la radio si elle joue
                              await _stopRadioIfPlaying();
                            } else {
                              print('[CONTENTS] ✅ Pas un replay vidéo - Pas d\'arrêt radio nécessaire (catégorie: $selectedCategory)');
                            }
                            
                            // Ouvrir le lecteur vidéo en plein écran (masque la BottomNavBar)
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(
                                  contentId: contentId?.toString() ?? '',
                                  title: title,
                                  author: author,
                                  videoUrl: finalFileUrl,
                                  favoriteStatusNotifier: favoriteStatusNotifier,
                                  date: date,
                                  description: '',
                                  startPosition: position,
                                ),
                                fullscreenDialog: true, // Force l'affichage en plein écran
                              ),
                            );
                          } else {
                            print('[DEBUG] Ouverture du lecteur audio');
                            
                            // 🚨 NOUVEAU: Logique différenciée selon la catégorie
                            print('[CONTENTS] 🔍 Catégorie du contenu audio: $selectedCategory');
                            
                            if (selectedCategory == 'Replays') {
                              print('[CONTENTS] 🚨 REPLAY AUDIO DÉTECTÉ - Activation variable globale AVANT ouverture audio');
                              
                              // 🚨 NOUVELLE MÉTHODE SIMPLE pour les replays
                              HomeScreen.setForceCloseRadioCard(true);
                              print('[CONTENTS] ✅ Variable globale _forceCloseRadioCard activée à true pour replay audio');
                              
                              // Appeler _stopRadioIfPlaying() pour arrêter la radio si elle joue
                              await _stopRadioIfPlaying();
                            } else {
                              print('[CONTENTS] ✅ Enseignement/Podcast - Utilisation ancienne méthode complexe');
                              
                              // 🚨 ANCIENNE MÉTHODE COMPLEXE pour enseignements et podcasts
                              final radioPlaying = ref.read(radioPlayingProvider);
                              
                              if (radioPlaying) {
                                print('[CONTENTS] 🚨 ARRÊT RADIO NÉCESSAIRE - Player a une source audio ou état actif');
                                try {
                                  // Arrêter le player audio
                                  final radioPlayer = ref.read(radioPlayerProvider);
                                  await radioPlayer.stop();
                                  
                                  // Mettre à jour l'état du provider
                                  ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
                                  
                                  // Forcer l'arrêt complet via la méthode stopRadio
                                  await ref.read(radioPlayingProvider.notifier).stopRadio();
                                  
                                  print('[CONTENTS] ✅ Radio live arrêtée avec succès via ancienne méthode complexe');
                                } catch (e) {
                                  print('[CONTENTS] ❌ Erreur lors de l\'arrêt de la radio: $e');
                                }
                              } else {
                                print('[CONTENTS] ✅ Radio pas en cours de lecture, pas d\'arrêt radio nécessaire');
                              }
                            }
                            
                            // Ouvrir le lecteur audio
                            final int startPosition = position ?? 0;
                            await _showMiniPlayer(
                              context,
                              title: title,
                              author: author,
                              fileUrl: finalFileUrl,
                              contentId: contentId,
                              favoriteStatusNotifier: favoriteStatusNotifier,
                              startPosition: startPosition,
                            );
                          }
                        } else {
                          print('[DEBUG] fileUrl est null ou vide');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Aucun fichier disponible'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            author,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                duration,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (isDownloadable && fileUrl != null && fileUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              try {
                                // Pour Android 11+, utiliser le stockage interne de l'app (plus fiable)
                                final dir = await getApplicationDocumentsDirectory();
                                final downloadsDir = Directory('${dir.path}/downloads');
                                if (!await downloadsDir.exists()) {
                                  await downloadsDir.create(recursive: true);
                                }
                                
                                // Nettoyer le nom de fichier
                                final cleanTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                                final timestamp = DateTime.now().millisecondsSinceEpoch;
                                final extension = fileUrl.endsWith('.mp4') ? 'mp4' : 'mp3';
                                final fileName = '${cleanTitle}_$timestamp.$extension';
                                final savePath = '${downloadsDir.path}/$fileName';
                                
                                // Afficher un indicateur de téléchargement
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 16),
                                        Text('Téléchargement en cours...'),
                                      ],
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                
                                final dio = Dio();
                                await dio.download(fileUrl, savePath);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Fichier téléchargé: $fileName'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              } catch (e) {
                                print('[DOWNLOAD] Erreur: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('❌ Erreur lors du téléchargement'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.download,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            // Utiliser Hive pour les favoris (même logique que dans player_screen)
                            final box = Hive.box('favorites');
                            final id = contentId;
                            if (id == null) return;
                            
                            final existing = box.values.cast<LocalFavorite?>().firstWhere(
                              (fav) => fav?.contentId == id,
                              orElse: () => null,
                            );
                            
                            final newFav = !(isFav);
                            
                            if (existing != null) {
                              existing.isFavorite = newFav;
                              existing.needsSync = true;
                              await existing.save();
                            } else {
                              await box.add(LocalFavorite(
                                contentId: id,
                                isFavorite: newFav,
                                updatedAt: DateTime.now(),
                                needsSync: true,
                              ));
                            }
                            
                            favoriteNotifier.value = newFav;
                            if (onFavoriteChanged != null) onFavoriteChanged(newFav);
                            
                            String message = newFav ? 'Favori ajouté' : 'Favori supprimé';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: (isFav == true || isFav == 'true' || isFav == 1 || isFav == '1') ? Colors.red : Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AllContentsModal extends StatefulWidget {
  final int catId;
  final String selectedCategory;
  final String userId; // 🚨 NOUVEAU: Ajout du userId
  final Widget Function({
    required int? contentId,
    required Color color,
    required String title,
    required String author,
    required String duration,
    required String date,
    String? fileUrl,
    required bool isDownloadable,
    required bool isFavorite,
    int? position,
    void Function(bool)? onFavoriteChanged,
  }) buildRecentItem;
  final ValueNotifier<Map<int, bool>> favoriteStatusNotifier;

  const _AllContentsModal({
    required this.catId,
    required this.selectedCategory,
    required this.userId, // 🚨 NOUVEAU: Ajout du userId
    required this.buildRecentItem,
    required this.favoriteStatusNotifier,
  });

  @override
  State<_AllContentsModal> createState() => _AllContentsModalState();
}

class _AllContentsModalState extends State<_AllContentsModal> {
  String searchQuery = '';
  final TextEditingController _controller = TextEditingController();
  late final Future<List<dynamic>> _allContentsFuture = _fetchAllContents();

  Future<List<dynamic>> _fetchAllContents() async {
    final userId = widget.userId; // Utiliser le userId passé depuis l'extérieur
    final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/viewallcontents?id_categorie=${widget.catId}&userId=$userId'));
    final body = response.body;
    if (body.isEmpty || (!body.trim().startsWith('{') && !body.trim().startsWith('['))) {
      return [];
    }
    final data = jsonDecode(body);
    if (data['statallcontent'] != 'success' || data['alldatacontent'] == null) {
      return [];
    }
    return List<dynamic>.from(data['alldatacontent']);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<dynamic>>(
          future: _allContentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.hasError) {
              return const Center(child: Text('Erreur de chargement'));
            }
            final allContents = snapshot.data!;
            return ValueListenableBuilder<Map<int, bool>>(
              valueListenable: widget.favoriteStatusNotifier,
              builder: (context, favoriteMap, _) {
                List<dynamic> filteredContents = allContents;
                if (searchQuery.isNotEmpty) {
                  filteredContents = allContents.where((item) {
                    final title = (item['title'] ?? '').toString().toLowerCase();
                    final author = (item['speaker_name'] ?? '').toString().toLowerCase();
                    return title.contains(searchQuery.toLowerCase()) || author.contains(searchQuery.toLowerCase());
                  }).toList();
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredContents.isEmpty
                          ? const Center(child: Text('Aucun résultat'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredContents.length,
                              itemBuilder: (context, index) {
                                final item = filteredContents[index];
                                final int id = item['id'];
                                final int? contentId = (item['contentId'] ?? item['id']) is int ? (item['contentId'] ?? item['id']) : int.tryParse((item['contentId'] ?? item['id']).toString());
                                final bool isFav = favoriteMap[id] ?? (item['isLikedByCurrentUser'] == true || item['isLikedByCurrentUser'] == 'true' || item['isLikedByCurrentUser'] == 1 || item['isLikedByCurrentUser'] == '1');
                                
                                // Charger la position depuis Hive
                                final int position = _loadPositionFromHive(contentId);
                                
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: widget.buildRecentItem(
                                    contentId: contentId,
                                    color: widget.selectedCategory == 'Enseignements' ? Colors.green : widget.selectedCategory == 'Podcasts' ? Colors.purple : Colors.blue,
                                    title: item['title'] ?? '',
                                    author: item['speaker_name'] ?? '',
                                    duration: item['duration'] != null ? formatDurationFromSeconds(item['duration']) : '',
                                    date: item['release_date'] ?? '',
                                    fileUrl: item['file_url'] ?? '',
                                    isDownloadable: true,
                                    isFavorite: isFav,
                                    position: position,
                                    onFavoriteChanged: (newFav) {
                                      widget.favoriteStatusNotifier.value = {
                                        ...widget.favoriteStatusNotifier.value,
                                        id: newFav,
                                      };
                                      setState(() {
                                        item['isLikedByCurrentUser'] = newFav;
                                      });
                                    },
                                  ),
                                );
                              },
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
}
