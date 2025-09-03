import 'package:emb_mission/core/data/mock_data.dart';
import 'package:emb_mission/core/models/bible_verse.dart';
import 'package:emb_mission/core/models/content_item.dart';
import 'package:emb_mission/core/models/prayer.dart';
import 'package:emb_mission/core/models/prayer_category.dart';
import 'package:emb_mission/core/models/testimony.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:emb_mission/core/services/auth_service.dart';

class PopularStat {
  final int id;
  final String titre;
  final int nombreVues;

  PopularStat({required this.id, required this.titre, required this.nombreVues});

  factory PopularStat.fromJson(Map<String, dynamic> json) {
    return PopularStat(
      id: json['id'] as int,
      titre: json['titre'] as String,
      nombreVues: json['nombrevues'] as int,
    );
  }
}

/// Service pour gérer les contenus de l'application
class ContentService {
  /// Récupère les éléments de la page d'accueil
  Future<List<ContentItem>> getHomeItems() async {
    // Simulation d'un délai réseau
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.homeItems;
  }

  /// Récupère les contenus populaires
  Future<List<ContentItem>> getPopularItems() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.popularItems;
  }

  /// Récupère les résultats de recherche
  Future<List<ContentItem>> searchContent(String query) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (query.isEmpty) {
      return MockData.searchResults;
    }
    
    // Filtre les résultats en fonction de la requête
    return MockData.searchResults
        .where((item) => 
            item.title.toLowerCase().contains(query.toLowerCase()) ||
            (item.subtitle?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
  }

  /// Récupère les témoignages
  Future<List<Testimony>> getTestimonies() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return MockData.testimonies;
  }
  
  /// Récupère les catégories de prières depuis l'API
  Future<List<PrayerCategoryModel>> getPrayerCategories() async {
    try {
      final url = 'https://embmission.com/mobileappebm/api/categorie_prayers';
      print('Appel API catégories prières: $url');
      
      final response = await http.get(Uri.parse(url));
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == 'true' && data['prayercategories'] != null) {
          final List<dynamic> categoriesJson = data['prayercategories'];
          return categoriesJson
              .map((json) => PrayerCategoryModel.fromJson(json))
              .where((category) => category.isActive) // Filtrer seulement les catégories actives
              .toList();
        } else {
          throw Exception('Format de réponse invalide');
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des catégories: $e');
      // En cas d'erreur, retourner des catégories par défaut
      return [
        PrayerCategoryModel(
          id: 1,
          name: 'Toutes',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PrayerCategoryModel(
          id: 2,
          name: 'Louange',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PrayerCategoryModel(
          id: 3,
          name: 'Intercession',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PrayerCategoryModel(
          id: 4,
          name: 'Remerciement',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PrayerCategoryModel(
          id: 5,
          name: 'Délivrance',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  /// Récupère les prières depuis l'API distante
  Future<List<Prayer>> getPrayers() async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/all_prayers');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'true' && data['alldataprayers'] != null) {
          final List<dynamic> prayersJson = data['alldataprayers'];
          return prayersJson.map((json) => Prayer(
            id: json['id'].toString(),
            title: json['title'] ?? '',
            content: json['content'] ?? '',
            category: json['categorie'] ?? '',
            createdAt: DateTime.now(), // L'API ne fournit pas la date, on met la date actuelle
            audioUrl: json['audio_url'],
            duration: json['audio_duration'],
            isLiked: false, // À adapter si l'API fournit l'info
          )).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des prières: $e');
      return [];
    }
  }
  
  /// Récupère une prière par son ID
  Future<Prayer> getPrayerById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prayers = await getPrayers();
    final prayer = prayers.firstWhere(
      (prayer) => prayer.id == id,
      orElse: () => throw Exception('Prière non trouvée'),
    );
    return prayer;
  }

  /// Ajoute un nouveau témoignage
  Future<Testimony> addTestimony({
    required String authorName,
    required String content,
    required TestimonyCategory category,
    required InputMode inputMode,
    String? audioBase64,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    // Création d'un nouveau témoignage avec les données fournies
    final testimony = Testimony(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorName: authorName,
      content: content,
      category: category,
      createdAt: DateTime.now(),
      inputMode: inputMode,
      likeCount: 0,
      isLiked: false,
      // Ajoute ici la logique pour stocker ou utiliser audioBase64 si besoin
    );
    // Dans une vraie application, on enverrait les données au serveur
    return testimony;
  }
  
  /// Ajoute ou supprime un like sur un témoignage
  Future<Testimony> toggleTestimonyLike(Testimony testimony) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Incrémente le nombre de likes et inverse l'état de like
    return testimony.copyWith(
      likeCount: testimony.likeCount + (testimony.isLiked ? -1 : 1),
      isLiked: !testimony.isLiked,
    );
  }

  /// Récupère un chapitre biblique
  Future<BibleChapter> getBibleChapter(String book, int chapter) async {
    await Future.delayed(const Duration(milliseconds: 700));
    
    // Pour l'instant, on ne retourne que Matthieu 5
    if (book.toLowerCase() == 'matthieu' && chapter == 5) {
      return MockData.matthieu5;
    }
    
    throw Exception('Chapitre non disponible');
  }

  /// Marque un verset comme favori
  Future<BibleVerse> toggleVerseFavorite(BibleVerse verse) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return verse.copyWith(isFavorite: !verse.isFavorite);
  }

  /// Marque un verset comme surligné
  Future<BibleVerse> toggleVerseHighlight(BibleVerse verse) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return verse.copyWith(isHighlighted: !verse.isHighlighted);
  }

  /// Ajoute une note à un verset
  Future<BibleVerse> addNoteToVerse(BibleVerse verse, String note) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return verse.copyWith(note: note);
  }

  /// Récupère le détail d'une prière par son ID depuis l'API
  Future<PrayerDetail> getPrayerDetailById(int id) async {
    final url = 'https://embmission.com/mobileappebm/api/today_detail_events';
    print('Appel API: $url');
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id': id}),
    );
    print('Status: \\${response.statusCode}');
    print('Body: \\${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return PrayerDetail.fromJson(data);
    } else {
      throw Exception('Erreur lors du chargement du détail de la prière');
    }
  }

  /// Récupère les stats populaires (forums, groupes, etc.) depuis l'API
  Future<List<PopularStat>> getPopularStats() async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/contenuspopulaire');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['statcontentpopular'] == 'success' && data['datacontentpopular'] != null) {
        final List<dynamic> statsJson = data['datacontentpopular'];
        return statsJson.map((json) => PopularStat.fromJson(json)).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Erreur lors du chargement des stats populaires');
    }
  }
}

/// Provider pour le service de contenu
final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService();
});

/// Provider pour les éléments de la page d'accueil
final homeItemsProvider = FutureProvider<List<ContentItem>>((ref) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getHomeItems();
});

/// Provider pour les contenus populaires
final popularItemsProvider = FutureProvider<List<ContentItem>>((ref) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getPopularItems();
});

/// Provider pour les catégories de prières
final prayerCategoriesProvider = FutureProvider<List<PrayerCategoryModel>>((ref) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getPrayerCategories();
});

/// Provider pour les témoignages
final testimoniesProvider = FutureProvider<List<Testimony>>((ref) async {
  try {
    final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/all_testimony'));
    print('API all_testimony - Status: ${response.statusCode}');
    print('API all_testimony - Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'true' && data['alldataprayers'] != null) {
        final List<dynamic> testimoniesData = data['alldataprayers'];
        return testimoniesData.map((testimonyJson) {
          // Mapping de la réponse API vers le modèle Testimony
          final currentUserId = ref.read(userIdProvider);
          final favorites = testimonyJson['favories'] as List<dynamic>? ?? [];
          final isLiked = favorites.any((fav) => fav['iduser'] == currentUserId);
          
          return Testimony(
            id: testimonyJson['id'].toString(),
            authorName: testimonyJson['name'] ?? '',
            content: testimonyJson['content'] ?? '',
            category: _mapCategoryFromApi(testimonyJson['categorie'] ?? ''),
            createdAt: DateTime.tryParse(testimonyJson['created_at'] ?? '') ?? DateTime.now(),
            inputMode: testimonyJson['audio_url'] != null && testimonyJson['audio_url'].isNotEmpty 
                ? InputMode.audio 
                : InputMode.text,
            audioUrl: testimonyJson['audio_url'],
            likeCount: favorites.length,
            isLiked: isLiked,
          );
        }).toList();
      } else {
        print('API all_testimony - Status false ou données manquantes');
        return [];
      }
    } else {
      print('API all_testimony - Erreur HTTP: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    print('API all_testimony - Exception: $e');
    return [];
  }
});

/// Fonction utilitaire pour mapper les catégories de l'API vers l'enum
TestimonyCategory _mapCategoryFromApi(String categoryName) {
  switch (categoryName.toLowerCase()) {
    case 'guérison':
      return TestimonyCategory.healing;
    case 'prière':
      return TestimonyCategory.prayer;
    case 'famille':
      return TestimonyCategory.family;
    case 'travail':
      return TestimonyCategory.work;
    default:
      return TestimonyCategory.healing; // Valeur par défaut
  }
}

/// Provider pour les prières
final prayersProvider = FutureProvider<List<Prayer>>((ref) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getPrayers();
});

/// Provider pour la recherche de contenu
final searchResultsProvider = FutureProvider.family<List<ContentItem>, String>((ref, query) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.searchContent(query);
});

/// Provider pour un chapitre biblique
final bibleChapterProvider = FutureProvider.family<BibleChapter, ({String book, int chapter})>((ref, params) {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getBibleChapter(params.book, params.chapter);
});

/// Provider pour les stats populaires (forums, groupes, etc.)
final popularStatsProvider = FutureProvider<List<PopularStat>>((ref) async {
  final contentService = ref.watch(contentServiceProvider);
  return contentService.getPopularStats();
});
