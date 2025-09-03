import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emb_mission/core/models/bible_verse.dart';

/// Service pour gérer les préférences de l'utilisateur
class PreferencesService {
  SharedPreferences? _prefs;
  bool _initialized = false;
  
  /// Clés pour les préférences
  static const String _favoriteVersesKey = 'favorite_verses';
  static const String _highlightedVersesKey = 'highlighted_verses';
  static const String _verseNotesKey = 'verse_notes';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _fontSizeKey = 'font_size';
  static const String _favoritePrayersKey = 'favorite_prayers';
  
  /// Récupère les prières favorites
  List<String> getFavoritePrayers() {
    if (!_initialized) return [];
    final String? prayersJson = _prefs?.getString(_favoritePrayersKey);
    if (prayersJson == null) return [];
    
    final List<dynamic> prayersList = jsonDecode(prayersJson);
    return prayersList.cast<String>();
  }
  
  /// Sauvegarde les prières favorites
  Future<void> saveFavoritePrayers(List<String> prayers) async {
    if (!_initialized) await initialize();
    final String prayersJson = jsonEncode(prayers);
    await _prefs?.setString(_favoritePrayersKey, prayersJson);
  }
  
  /// Initialise le service
  Future<void> initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }
  
  /// Vérifie si le service est initialisé
  bool isInitialized() {
    return _initialized;
  }
  
  /// Vérifie si le mode sombre est activé
  bool isDarkMode() {
    if (!_initialized) return false;
    return _prefs?.getBool(_isDarkModeKey) ?? false;
  }
  
  /// Définit le mode sombre
  Future<void> setDarkMode(bool value) async {
    if (!_initialized) await initialize();
    await _prefs?.setBool(_isDarkModeKey, value);
  }
  
  /// Récupère la taille de police
  double getFontSize() {
    if (!_initialized) return 16.0;
    return _prefs?.getDouble(_fontSizeKey) ?? 16.0;
  }
  
  /// Définit la taille de police
  Future<void> setFontSize(double value) async {
    if (!_initialized) await initialize();
    await _prefs?.setDouble(_fontSizeKey, value);
  }
  
  /// Sauvegarde la taille de police (alias pour setFontSize)
  Future<void> saveFontSize(double value) async {
    await setFontSize(value);
  }
  
  /// Récupère les versets favoris
  List<BibleVerse> getFavoriteVersesObjects() {
    if (!_initialized) return [];
    final String? versesJson = _prefs?.getString(_favoriteVersesKey);
    if (versesJson == null) return [];
    
    final List<dynamic> versesList = jsonDecode(versesJson);
    return versesList.map((v) => BibleVerse.fromJson(v)).toList();
  }
  
  /// Récupère les références des versets favoris
  List<String> getFavoriteVerses() {
    if (!_initialized) return [];
    final String? versesJson = _prefs?.getString('${_favoriteVersesKey}_refs');
    if (versesJson == null) return [];
    
    final List<dynamic> versesList = jsonDecode(versesJson);
    return versesList.cast<String>();
  }
  
  /// Sauvegarde les références des versets favoris
  Future<void> saveFavoriteVerses(List<String> references) async {
    if (!_initialized) await initialize();
    final String versesJson = jsonEncode(references);
    await _prefs?.setString('${_favoriteVersesKey}_refs', versesJson);
  }
  
  /// Ajoute un verset aux favoris
  Future<void> addFavoriteVerse(BibleVerse verse) async {
    // Sauvegarde l'objet BibleVerse pour la compatibilité avec l'ancien code
    final List<BibleVerse> favorites = getFavoriteVersesObjects();
    
    // Vérifie si le verset est déjà dans les favoris
    final bool alreadyExists = favorites.any((v) => 
        v.book == verse.book && 
        v.chapter == verse.chapter && 
        v.verse == verse.verse);
    
    if (!alreadyExists) {
      favorites.add(verse.copyWith(isFavorite: true));
      final String versesJson = jsonEncode(
        favorites.map((v) => v.toJson()).toList()
      );
      await _prefs?.setString(_favoriteVersesKey, versesJson);
    }
    
    // Sauvegarde également la référence
    final String reference = '${verse.book} ${verse.chapter}:${verse.verse}';
    final List<String> refs = getFavoriteVerses();
    if (!refs.contains(reference)) {
      refs.add(reference);
      await saveFavoriteVerses(refs);
    }
  }
  
  /// Supprime un verset des favoris
  Future<void> removeFavoriteVerse(BibleVerse verse) async {
    // Supprime l'objet BibleVerse pour la compatibilité avec l'ancien code
    final List<BibleVerse> favorites = getFavoriteVersesObjects();
    
    favorites.removeWhere((v) => 
        v.book == verse.book && 
        v.chapter == verse.chapter && 
        v.verse == verse.verse);
    
    final String versesJson = jsonEncode(
      favorites.map((v) => v.toJson()).toList()
    );
    await _prefs?.setString(_favoriteVersesKey, versesJson);
    
    // Supprime également la référence
    final String reference = '${verse.book} ${verse.chapter}:${verse.verse}';
    final List<String> refs = getFavoriteVerses();
    refs.remove(reference);
    await saveFavoriteVerses(refs);
  }
  
  /// Récupère les versets surlignés
  List<BibleVerse> getHighlightedVerses() {
    if (!_initialized) return [];
    final String? versesJson = _prefs?.getString(_highlightedVersesKey);
    if (versesJson == null) return [];
    
    final List<dynamic> versesList = jsonDecode(versesJson);
    return versesList.map((v) => BibleVerse.fromJson(v)).toList();
  }
  
  /// Ajoute un verset aux surlignés
  Future<void> addHighlightedVerse(BibleVerse verse) async {
    final List<BibleVerse> highlighted = getHighlightedVerses();
    
    // Vérifie si le verset est déjà surligné
    final bool alreadyExists = highlighted.any((v) => 
        v.book == verse.book && 
        v.chapter == verse.chapter && 
        v.verse == verse.verse);
    
    if (!alreadyExists) {
      highlighted.add(verse.copyWith(isHighlighted: true));
      final String versesJson = jsonEncode(
        highlighted.map((v) => v.toJson()).toList()
      );
      await _prefs?.setString(_highlightedVersesKey, versesJson);
    }
  }
  
  /// Supprime un verset des surlignés
  Future<void> removeHighlightedVerse(BibleVerse verse) async {
    final List<BibleVerse> highlighted = getHighlightedVerses();
    
    highlighted.removeWhere((v) => 
        v.book == verse.book && 
        v.chapter == verse.chapter && 
        v.verse == verse.verse);
    
    final String versesJson = jsonEncode(
      highlighted.map((v) => v.toJson()).toList()
    );
    await _prefs?.setString(_highlightedVersesKey, versesJson);
  }
  
  /// Récupère les notes des versets
  Map<String, String> getVerseNotes() {
    if (!_initialized) return {};
    final String? notesJson = _prefs?.getString(_verseNotesKey);
    if (notesJson == null) return {};
    
    final Map<String, dynamic> notesMap = jsonDecode(notesJson);
    return notesMap.map((key, value) => MapEntry(key, value.toString()));
  }
  
  /// Ajoute une note à un verset
  Future<void> addVerseNote(BibleVerse verse, String note) async {
    final Map<String, String> notes = getVerseNotes();
    final String verseKey = '${verse.book}_${verse.chapter}_${verse.verse}';
    
    notes[verseKey] = note;
    
    final String notesJson = jsonEncode(notes);
    await _prefs?.setString(_verseNotesKey, notesJson);
  }
  
  /// Supprime une note d'un verset
  Future<void> removeVerseNote(BibleVerse verse) async {
    final Map<String, String> notes = getVerseNotes();
    final String verseKey = '${verse.book}_${verse.chapter}_${verse.verse}';
    
    notes.remove(verseKey);
    
    final String notesJson = jsonEncode(notes);
    await _prefs?.setString(_verseNotesKey, notesJson);
  }
}

/// Provider pour le service de préférences initialisé
final preferencesServiceInitProvider = FutureProvider<PreferencesService>((ref) async {
  final service = PreferencesService();
  await service.initialize();
  return service;
});

/// Provider pour le service de préférences
/// Utiliser ce provider uniquement après avoir attendu que preferencesServiceInitProvider soit complété
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final asyncValue = ref.watch(preferencesServiceInitProvider);
  return asyncValue.when(
    data: (service) => service,
    loading: () => PreferencesService(),
    error: (_, __) => PreferencesService(),
  );
});

/// Provider pour le mode sombre
final isDarkModeProvider = StateProvider<bool>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return prefsService.isDarkMode();
});

/// Provider pour la taille de police
final fontSizeProvider = StateProvider<double>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return prefsService.getFontSize();
});

/// Provider pour les versets favoris (objets)
final favoriteVersesObjectsProvider = StateProvider<List<BibleVerse>>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return prefsService.getFavoriteVersesObjects();
});

/// Provider pour les références des versets favoris
final favoriteVersesProvider = StateProvider<List<String>>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return prefsService.getFavoriteVerses();
});

/// Provider pour les versets surlignés
final highlightedVersesProvider = StateProvider<List<BibleVerse>>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return prefsService.getHighlightedVerses();
});

/// Provider pour les notes des versets
final verseNotesProvider = StateProvider<Map<String, String>>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return prefsService.getVerseNotes();
});
