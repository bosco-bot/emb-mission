import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service utilitaire pour la persistance locale des notes et surlignages Bible
class BibleLocalStorageService {
  static const String themeKey = 'bible_theme';
  /// Sauvegarde le thème sélectionné dans SharedPreferences
  static Future<void> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, theme);
  }

  /// Charge le thème depuis SharedPreferences
  static Future<String?> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(themeKey);
  }
  static const String notesKey = 'bible_notes';
  static const String highlightsKey = 'bible_highlights';
  static const String favoritesKey = 'bible_favorites';
  static const String fontSizeKey = 'bible_font_size';

  /// Sauvegarde les notes (Map<int, List<String>>) dans SharedPreferences
  static Future<void> saveNotes(Map<int, List<String>> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final notesString = jsonEncode(notes.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString(notesKey, notesString);
  }

  /// Charge les notes depuis SharedPreferences
  static Future<Map<int, List<String>>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesString = prefs.getString(notesKey);
    if (notesString == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(notesString);
    return decoded.map<int, List<String>>((k, v) => MapEntry(int.parse(k), List<String>.from(v)));
  }

  /// Sauvegarde les surlignages (Map<int, bool>) dans SharedPreferences
  static Future<void> saveHighlights(Map<int, bool> highlights) async {
    final prefs = await SharedPreferences.getInstance();
    final highlightsString = jsonEncode(highlights.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString(highlightsKey, highlightsString);
  }

  /// Charge les surlignages depuis SharedPreferences
  static Future<Map<int, bool>> loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final highlightsString = prefs.getString(highlightsKey);
    if (highlightsString == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(highlightsString);
    return decoded.map<int, bool>((k, v) => MapEntry(int.parse(k), v as bool));
  }

  /// Sauvegarde les favoris (List<int>) dans SharedPreferences
  static Future<void> saveFavorites(List<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final favString = jsonEncode(favorites);
    await prefs.setString(favoritesKey, favString);
  }

  /// Charge les favoris depuis SharedPreferences
  static Future<List<int>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favString = prefs.getString(favoritesKey);
    if (favString == null) return []; // valeur par défaut corrigée
    final List<dynamic> decoded = jsonDecode(favString);
    return decoded.map((e) => e as int).toList();
  }

  /// Sauvegarde la taille de police sélectionnée dans SharedPreferences
  static Future<void> saveFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(fontSizeKey, fontSize);
  }

  /// Charge la taille de police depuis SharedPreferences
  static Future<double?> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(fontSizeKey);
  }
}
