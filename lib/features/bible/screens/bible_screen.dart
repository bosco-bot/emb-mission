import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:emb_mission/core/widgets/home_back_button.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:emb_mission/core/services/bible_local_storage_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:emb_mission/features/bible/screens/reading_plans_screen.dart';
import 'package:emb_mission/core/services/auth_service.dart';
// Enum pour les thèmes disponibles
enum BibleVersesTheme { light, dark, sepia }

// Provider pour le thème de l'espace verset biblique (clair, sombre, sepia)
final bibleVersesThemeProvider = StateProvider<BibleVersesTheme>((ref) => BibleVersesTheme.light);

// Fonction utilitaire pour obtenir les couleurs selon le thème
class BibleVersesThemeStyles {
  static Color background(BibleVersesTheme theme) {
    switch (theme) {
      case BibleVersesTheme.dark:
        return const Color(0xFF232323);
      case BibleVersesTheme.sepia:
        return const Color(0xFFF5ECD9);
      case BibleVersesTheme.light:
        return Colors.white;
    }
  }
  static Color text(BibleVersesTheme theme) {
    switch (theme) {
      case BibleVersesTheme.dark:
        return Colors.white;
      case BibleVersesTheme.sepia:
        return const Color(0xFF5B4636);
      case BibleVersesTheme.light:
        return Colors.black;
    }
  }
  static Color verseNumber(BibleVersesTheme theme) {
    switch (theme) {
      case BibleVersesTheme.dark:
        return Colors.grey;
      case BibleVersesTheme.sepia:
        return const Color(0xFF8B6F47);
      case BibleVersesTheme.light:
        return Colors.grey;
    }
  }
}

/// Provider pour la traduction biblique sélectionnée
final bibleTranslationProvider = StateProvider<String>((ref) {
  return 'LSG'; // Louis Segond par défaut
});

/// Provider pour les versets surlignés (stockage local, même logique que les notes)
final highlightedBibleVersesProvider = StateProvider<Map<int, bool>>((ref) {
  // Map : numéro de verset => true si surligné
  return {};
});

/// Provider pour les versets favoris (si besoin de séparer favoris et surlignés)
final favoriteBibleVersesProvider = StateProvider<List<int>>((ref) {
  return []; // Aucun favori par défaut
});
/// Provider pour la taille de police
final bibleFontSizeProvider = StateProvider<double>((ref) {
  return 16.0; // Taille par défaut
});

/// Provider pour les notes locales par verset (clé = numéro de verset, valeur = liste de notes)
final bibleNotesProvider = StateProvider<Map<int, List<String>>>((ref) {
  return {};
});

/// Écran de lecture de la Bible
class BibleScreen extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  final String? range;

  BibleScreen({
    Key? key,
    required this.book,
    required this.chapter,
    this.range,
  }) : super(key: key ?? ValueKey('${book}_$chapter'));

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  // Liste complète des livres de la Bible (centralisée)
  static const List<String> _bibleBooks = [
    // Ancien Testament
    'Genèse', 'Exode', 'Lévitique', 'Nombres', 'Deutéronome',
    'Josué', 'Juges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Rois', '2 Rois', '1 Chroniques', '2 Chroniques',
    'Esdras', 'Néhémie', 'Esther', 'Job', 'Psaumes',
    'Proverbes', 'Ecclésiaste', 'Cantique des Cantiques',
    'Ésaïe', 'Jérémie', 'Lamentations', 'Ézéchiel',
    'Daniel', 'Osée', 'Joël', 'Amos', 'Abdias',
    'Jonas', 'Michée', 'Nahum', 'Habacuc', 'Sophonie',
    'Aggée', 'Zacharie', 'Malachie',
    // Nouveau Testament
    'Matthieu', 'Marc', 'Luc', 'Jean', 'Actes',
    'Romains', '1 Corinthiens', '2 Corinthiens', 'Galates',
    'Éphésiens', 'Philippiens', 'Colossiens', '1 Thessaloniciens',
    '2 Thessaloniciens', '1 Timothée', '2 Timothée', 'Tite',
    'Philémon', 'Hébreux', 'Jacques', '1 Pierre', '2 Pierre',
    '1 Jean', '2 Jean', '3 Jean', 'Jude', 'Apocalypse',
  ];

  // Nombre de chapitres par livre de la Bible
  static const Map<String, int> _bibleChapters = {
    // Ancien Testament
    'Genèse': 50, 'Exode': 40, 'Lévitique': 27, 'Nombres': 36, 'Deutéronome': 34,
    'Josué': 24, 'Juges': 21, 'Ruth': 4, '1 Samuel': 31, '2 Samuel': 24,
    '1 Rois': 22, '2 Rois': 25, '1 Chroniques': 29, '2 Chroniques': 36,
    'Esdras': 10, 'Néhémie': 13, 'Esther': 10, 'Job': 42, 'Psaumes': 150,
    'Proverbes': 31, 'Ecclésiaste': 12, 'Cantique des Cantiques': 8,
    'Ésaïe': 66, 'Jérémie': 52, 'Lamentations': 5, 'Ézéchiel': 48,
    'Daniel': 12, 'Osée': 14, 'Joël': 3, 'Amos': 9, 'Abdias': 1,
    'Jonas': 4, 'Michée': 7, 'Nahum': 3, 'Habacuc': 3, 'Sophonie': 3,
    'Aggée': 2, 'Zacharie': 14, 'Malachie': 4,
    // Nouveau Testament
    'Matthieu': 28, 'Marc': 16, 'Luc': 24, 'Jean': 21, 'Actes': 28,
    'Romains': 16, '1 Corinthiens': 16, '2 Corinthiens': 13, 'Galates': 6,
    'Éphésiens': 6, 'Philippiens': 4, 'Colossiens': 4, '1 Thessaloniciens': 5,
    '2 Thessaloniciens': 3, '1 Timothée': 6, '2 Timothée': 4, 'Tite': 3,
    'Philémon': 1, 'Hébreux': 13, 'Jacques': 5, '1 Pierre': 5, '2 Pierre': 3,
    '1 Jean': 5, '2 Jean': 1, '3 Jean': 1, 'Jude': 1, 'Apocalypse': 22,
  };

  // Chargement initial des notes et surlignages persistés
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPersistedData();
  }

  Future<void> _loadPersistedData() async {
    // Notes
    final notes = await BibleLocalStorageService.loadNotes();
    ref.read(bibleNotesProvider.notifier).state = notes;
    // Surlignages
    final highlights = await BibleLocalStorageService.loadHighlights();
    ref.read(highlightedBibleVersesProvider.notifier).state = highlights;
    // Favoris
    final favorites = await BibleLocalStorageService.loadFavorites();
    ref.read(favoriteBibleVersesProvider.notifier).state = favorites;
    // Thème
    final themeString = await BibleLocalStorageService.loadTheme();
    if (themeString != null) {
      final theme = _themeFromString(themeString);
      if (theme != null) {
        ref.read(bibleVersesThemeProvider.notifier).state = theme;
      }
    }
    // Taille de police
    final fontSize = await BibleLocalStorageService.loadFontSize();
    if (fontSize != null) {
      ref.read(bibleFontSizeProvider.notifier).state = fontSize;
    }
  }

  BibleVersesTheme? _themeFromString(String value) {
    switch (value) {
      case 'light':
        return BibleVersesTheme.light;
      case 'dark':
        return BibleVersesTheme.dark;
      case 'sepia':
        return BibleVersesTheme.sepia;
      default:
        return null;
    }
  }

  String _themeToString(BibleVersesTheme theme) {
    switch (theme) {
      case BibleVersesTheme.light:
        return 'light';
      case BibleVersesTheme.dark:
        return 'dark';
      case BibleVersesTheme.sepia:
        return 'sepia';
    }
  }
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int? _highlightedVerseIndex;

  @override
  void dispose() {
    // Rien à disposer pour ItemScrollController
    super.dispose();
  }

  // Couleur principale pour l'écran Bible
  final Color bibleBlueColor = const Color(0xFF64B5F6);
  
  // Versets du chapitre sélectionné
  List<Map<String, String>> verses = [];
  bool isLoading = true;
  late List<Map<String, String>> versesToShow;

  // Fonction de recherche dans toute la Bible
  Future<void> _searchInBible(String query) async {
    // D'abord vérifier si c'est un testament
    final testamentResult = _searchTestament(query);
    if (testamentResult != null) {
      // Navigation vers le premier livre du testament
      final firstBook = testamentResult.first;
      context.go('/bible?book=$firstBook&chapter=1');
      final testamentName = testamentResult.length == 39 ? 'Ancien Testament' : 'Nouveau Testament';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation vers $testamentName - $firstBook chapitre 1.')),
      );
      return;
    }

    // Ensuite vérifier si c'est un nom de livre
    final bookResult = _searchBook(query);
    if (bookResult != null) {
      // Navigation directe vers le livre trouvé
      context.go('/bible?book=$bookResult&chapter=1');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation vers $bookResult chapitre 1.')),
      );
      return;
    }

    // D'abord chercher dans le chapitre actuel
    int? targetIndex;
    final verseNum = int.tryParse(query);
    
    if (verseNum != null) {
      // Recherche par numéro de verset dans le chapitre actuel
      targetIndex = versesToShow.indexWhere((v) => v['number'] == verseNum.toString());
      if (targetIndex != -1) {
        setState(() {
          _highlightedVerseIndex = targetIndex;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verset $verseNum trouvé dans ce chapitre.')),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _highlightedVerseIndex == targetIndex) {
            setState(() {
              _highlightedVerseIndex = null;
            });
          }
        });
        return;
      } else {
        // Si le verset n'est pas dans ce chapitre, chercher dans d'autres chapitres
        await _searchVerseInOtherChapters(verseNum);
        return;
      }
    } else {
      // Vérifier si c'est une recherche dans un testament spécifique (format: "testament:recherche")
      final testamentMatch = RegExp(r'^(ancien|nouveau|at|nt):(.+)$', caseSensitive: false).firstMatch(query);
      if (testamentMatch != null) {
        final testamentType = testamentMatch.group(1)!.toLowerCase();
        final searchTerm = testamentMatch.group(2)!.trim();
        
        List<String> testamentBooks;
        if (testamentType == 'ancien' || testamentType == 'at') {
          testamentBooks = _bibleBooks.take(39).toList();
        } else {
          testamentBooks = _bibleBooks.skip(39).toList();
        }
        
        // Vérifier si c'est un numéro de verset
        final verseNum = int.tryParse(searchTerm);
        if (verseNum != null) {
          await _searchVerseInTestament(verseNum, testamentBooks);
        } else {
          await _searchKeywordInTestament(searchTerm, testamentBooks);
        }
        return;
      }
      
      // Recherche par mot-clé dans le chapitre actuel
      final found = versesToShow.indexWhere((v) => v['text']!.toLowerCase().contains(query.toLowerCase()));
      if (found != -1) {
        setState(() {
          _highlightedVerseIndex = found;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$query" trouvé dans ${versesToShow.where((v) => v['text']!.toLowerCase().contains(query.toLowerCase())).length} verset(s) du chapitre.')),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _highlightedVerseIndex == found) {
            setState(() {
              _highlightedVerseIndex = null;
            });
          }
        });
        return;
      } else {
        // Si le mot-clé n'est pas dans ce chapitre, chercher dans d'autres chapitres
        await _searchKeywordInOtherChapters(query);
        return;
      }
    }
  }

  // Rechercher un livre par nom
  String? _searchBook(String query) {
    final queryLower = query.toLowerCase().trim();
    
    // Recherche exacte
    for (final book in _bibleBooks) {
      if (book.toLowerCase() == queryLower) {
        return book;
      }
    }
    
    // Recherche partielle (contient)
    for (final book in _bibleBooks) {
      if (book.toLowerCase().contains(queryLower)) {
        return book;
      }
    }
    
    // Recherche par abréviation courante
    final abbreviations = {
      'gen': 'Genèse',
      'exo': 'Exode',
      'lev': 'Lévitique',
      'num': 'Nombres',
      'deu': 'Deutéronome',
      'jos': 'Josué',
      'jug': 'Juges',
      'rut': 'Ruth',
      '1sa': '1 Samuel',
      '2sa': '2 Samuel',
      '1ro': '1 Rois',
      '2ro': '2 Rois',
      '1ch': '1 Chroniques',
      '2ch': '2 Chroniques',
      'esd': 'Esdras',
      'neh': 'Néhémie',
      'est': 'Esther',
      'job': 'Job',
      'psa': 'Psaumes',
      'pro': 'Proverbes',
      'ecc': 'Ecclésiaste',
      'can': 'Cantique des Cantiques',
      'isa': 'Ésaïe',
      'jer': 'Jérémie',
      'lam': 'Lamentations',
      'eze': 'Ézéchiel',
      'dan': 'Daniel',
      'hos': 'Osée',
      'joe': 'Joël',
      'amo': 'Amos',
      'oba': 'Abdias',
      'jon': 'Jonas',
      'mic': 'Michée',
      'nah': 'Nahum',
      'hab': 'Habacuc',
      'zep': 'Sophonie',
      'hag': 'Aggée',
      'zac': 'Zacharie',
      'mal': 'Malachie',
      'mat': 'Matthieu',
      'mar': 'Marc',
      'luc': 'Luc',
      'jea': 'Jean',
      'act': 'Actes',
      'rom': 'Romains',
      '1co': '1 Corinthiens',
      '2co': '2 Corinthiens',
      'gal': 'Galates',
      'eph': 'Éphésiens',
      'phi': 'Philippiens',
      'col': 'Colossiens',
      '1th': '1 Thessaloniciens',
      '2th': '2 Thessaloniciens',
      '1ti': '1 Timothée',
      '2ti': '2 Timothée',
      'tit': 'Tite',
      'phm': 'Philémon',
      'heb': 'Hébreux',
      'jam': 'Jacques',
      '1pe': '1 Pierre',
      '2pe': '2 Pierre',
      '1jo': '1 Jean',
      '2jo': '2 Jean',
      '3jo': '3 Jean',
      'jud': 'Jude',
      'apo': 'Apocalypse',
    };
    
    for (final entry in abbreviations.entries) {
      if (entry.key.toLowerCase() == queryLower) {
        return entry.value;
      }
    }
    
    return null;
  }

  // Rechercher par testament
  List<String>? _searchTestament(String query) {
    final queryLower = query.toLowerCase().trim();
    
    // Ancien Testament
    if (queryLower.contains('ancien') || queryLower.contains('old') || queryLower == 'at') {
      return _bibleBooks.take(39).toList(); // 39 premiers livres
    }
    
    // Nouveau Testament
    if (queryLower.contains('nouveau') || queryLower.contains('new') || queryLower == 'nt') {
      return _bibleBooks.skip(39).toList(); // 27 derniers livres
    }
    
    return null;
  }

  // Rechercher un verset spécifique dans d'autres chapitres
  Future<void> _searchVerseInOtherChapters(int verseNum) async {
    // Chercher dans les chapitres suivants du même livre
    for (int chapter = widget.chapter + 1; chapter <= (_bibleChapters[widget.book] ?? 1); chapter++) {
      try {
        final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=${widget.book}&chapter=$chapter');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'true' && data['data'] != null) {
            final verses = List<Map<String, dynamic>>.from(data['data']);
            final foundIndex = verses.indexWhere((v) => v['number'] == verseNum.toString());
            
            if (foundIndex != -1) {
              // Naviguer vers ce chapitre et surligner le verset
              context.go('/bible?book=${widget.book}&chapter=$chapter');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verset $verseNum trouvé dans ${widget.book} chapitre $chapter.')),
              );
              return;
            }
          }
        }
      } catch (e) {
        print('Erreur lors de la recherche: $e');
      }
    }
    
    // Si pas trouvé, chercher dans d'autres livres
    await _searchVerseInOtherBooks(verseNum);
  }

  // Rechercher un mot-clé dans d'autres chapitres
  Future<void> _searchKeywordInOtherChapters(String keyword) async {
    // Chercher dans les chapitres suivants du même livre
    for (int chapter = widget.chapter + 1; chapter <= (_bibleChapters[widget.book] ?? 1); chapter++) {
      try {
        final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=${widget.book}&chapter=$chapter');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'true' && data['data'] != null) {
            final verses = List<Map<String, dynamic>>.from(data['data']);
            final foundIndex = verses.indexWhere((v) => v['text']!.toLowerCase().contains(keyword.toLowerCase()));
            
            if (foundIndex != -1) {
              // Naviguer vers ce chapitre et surligner le verset
              context.go('/bible?book=${widget.book}&chapter=$chapter');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$keyword" trouvé dans ${widget.book} chapitre $chapter.')),
              );
              return;
            }
          }
        }
      } catch (e) {
        print('Erreur lors de la recherche: $e');
      }
    }
    
    // Si pas trouvé, chercher dans d'autres livres
    await _searchKeywordInOtherBooks(keyword);
  }

  // Rechercher un verset dans d'autres livres
  Future<void> _searchVerseInOtherBooks(int verseNum) async {
    final currentBookIndex = _bibleBooks.indexOf(widget.book);
    
    // Chercher dans les livres suivants
    for (int bookIndex = currentBookIndex + 1; bookIndex < _bibleBooks.length; bookIndex++) {
      final book = _bibleBooks[bookIndex];
      final maxChapters = _bibleChapters[book] ?? 1;
      
      for (int chapter = 1; chapter <= maxChapters; chapter++) {
        try {
          final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=$book&chapter=$chapter');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'true' && data['data'] != null) {
              final verses = List<Map<String, dynamic>>.from(data['data']);
              final foundIndex = verses.indexWhere((v) => v['number'] == verseNum.toString());
              
              if (foundIndex != -1) {
                // Naviguer vers ce chapitre
                context.go('/bible?book=$book&chapter=$chapter');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verset $verseNum trouvé dans $book chapitre $chapter.')),
                );
                return;
              }
            }
          }
        } catch (e) {
          print('Erreur lors de la recherche: $e');
        }
      }
    }
    
    // Si pas trouvé, afficher un message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verset $verseNum non trouvé dans toute la Bible.')),
    );
  }

  // Rechercher un verset dans un testament spécifique
  Future<void> _searchVerseInTestament(int verseNum, List<String> testamentBooks) async {
    for (final book in testamentBooks) {
      final maxChapters = _bibleChapters[book] ?? 1;
      
      for (int chapter = 1; chapter <= maxChapters; chapter++) {
        try {
          final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=$book&chapter=$chapter');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'true' && data['data'] != null) {
              final verses = List<Map<String, dynamic>>.from(data['data']);
              final foundIndex = verses.indexWhere((v) => v['number'] == verseNum.toString());
              
              if (foundIndex != -1) {
                // Naviguer vers ce chapitre
                context.go('/bible?book=$book&chapter=$chapter');
                final testamentName = testamentBooks.length == 39 ? 'Ancien Testament' : 'Nouveau Testament';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verset $verseNum trouvé dans $testamentName - $book chapitre $chapter.')),
                );
                return;
              }
            }
          }
        } catch (e) {
          print('Erreur lors de la recherche: $e');
        }
      }
    }
    
    // Si pas trouvé, afficher un message
    final testamentName = testamentBooks.length == 39 ? 'Ancien Testament' : 'Nouveau Testament';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verset $verseNum non trouvé dans le $testamentName.')),
    );
  }

  // Rechercher un mot-clé dans d'autres livres
  Future<void> _searchKeywordInOtherBooks(String keyword) async {
    final currentBookIndex = _bibleBooks.indexOf(widget.book);
    
    // Chercher dans les livres suivants
    for (int bookIndex = currentBookIndex + 1; bookIndex < _bibleBooks.length; bookIndex++) {
      final book = _bibleBooks[bookIndex];
      final maxChapters = _bibleChapters[book] ?? 1;
      
      for (int chapter = 1; chapter <= maxChapters; chapter++) {
        try {
          final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=$book&chapter=$chapter');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'true' && data['data'] != null) {
              final verses = List<Map<String, dynamic>>.from(data['data']);
              final foundIndex = verses.indexWhere((v) => v['text']!.toLowerCase().contains(keyword.toLowerCase()));
              
              if (foundIndex != -1) {
                // Naviguer vers ce chapitre
                context.go('/bible?book=$book&chapter=$chapter');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$keyword" trouvé dans $book chapitre $chapter.')),
                );
                return;
              }
            }
          }
        } catch (e) {
          print('Erreur lors de la recherche: $e');
        }
      }
    }
    
    // Si pas trouvé, afficher un message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aucun résultat pour "$keyword" dans toute la Bible.')),
    );
  }

  // Rechercher un mot-clé dans un testament spécifique
  Future<void> _searchKeywordInTestament(String keyword, List<String> testamentBooks) async {
    for (final book in testamentBooks) {
      final maxChapters = _bibleChapters[book] ?? 1;
      
      for (int chapter = 1; chapter <= maxChapters; chapter++) {
        try {
          final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=$book&chapter=$chapter');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'true' && data['data'] != null) {
              final verses = List<Map<String, dynamic>>.from(data['data']);
              final foundIndex = verses.indexWhere((v) => v['text']!.toLowerCase().contains(keyword.toLowerCase()));
              
              if (foundIndex != -1) {
                // Naviguer vers ce chapitre
                context.go('/bible?book=$book&chapter=$chapter');
                final testamentName = testamentBooks.length == 39 ? 'Ancien Testament' : 'Nouveau Testament';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$keyword" trouvé dans $testamentName - $book chapitre $chapter.')),
                );
                return;
              }
            }
          }
        } catch (e) {
          print('Erreur lors de la recherche: $e');
        }
      }
    }
    
    // Si pas trouvé, afficher un message
    final testamentName = testamentBooks.length == 39 ? 'Ancien Testament' : 'Nouveau Testament';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aucun résultat pour "$keyword" dans le $testamentName.')),
    );
  }

  void _updateVersesToShow() {
    versesToShow = verses;
    if (widget.range != null && widget.range!.contains('-')) {
      final parts = widget.range!.split('-');
      final int? start = int.tryParse(parts[0]);
      final int? end = int.tryParse(parts[1]);
      if (start != null && end != null) {
        versesToShow = verses.where((v) {
          final num = int.tryParse(v['number'] ?? '') ?? 0;
          return num >= start && num <= end;
        }).toList();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  // Charger les versets en fonction du livre et du chapitre depuis l'API
  Future<void> _loadVerses() async {
    setState(() { isLoading = true; });
    final String book = widget.book.isNotEmpty ? widget.book : 'Genèse';
    final int chapter = widget.chapter > 0 ? widget.chapter : 1;
    final url = Uri.parse('https://embmission.com/mobileappebm/api/showbibleversetchapt?book=$book&chapter=$chapter');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        verses = (data['verses'] as List)
            .map<Map<String, String>>((v) => {
                  'number': v['verse'].toString(),
                  'text': v['text'].toString(),
                })
            .toList();
      } else {
        verses = [
          {'number': '1', 'text': 'Premier verset de $book $chapter.'},
          {'number': '2', 'text': 'Deuxième verset de $book $chapter.'},
          {'number': '3', 'text': 'Troisième verset de $book $chapter.'},
        ];
      }
    } catch (e) {
      verses = [
        {'number': '1', 'text': 'Premier verset de $book $chapter.'},
        {'number': '2', 'text': 'Deuxième verset de $book $chapter.'},
        {'number': '3', 'text': 'Troisième verset de $book $chapter.'},
      ];
    }
    setState(() { isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    _updateVersesToShow();
    final favoriteVerses = ref.watch(favoriteBibleVersesProvider);

    // Scroll automatique si demandé
    if (_highlightedVerseIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_highlightedVerseIndex! >= 0 && _highlightedVerseIndex! < versesToShow.length) {
          _itemScrollController.scrollTo(
            index: _highlightedVerseIndex!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: bibleBlueColor,
        elevation: 0,
        leading: HomeBackButton(color: Colors.white),
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/images/bible.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            const Text(
              'Bible',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) {
                  String query = '';
                  return AlertDialog(
                    title: const Text('Recherche dans la Bible'),
                    content:                         TextField(
                          autofocus: true,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Nom de livre, numéro de verset\nou mot-clé',
                            hintMaxLines: 2,
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                      onChanged: (value) => query = value,
                      onSubmitted: (value) => Navigator.of(context).pop(value),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(query),
                        child: const Text('Rechercher'),
                      ),
                    ],
                  );
                },
              );
              if (result != null && result.isNotEmpty) {
                await _searchInBible(result);
              }
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/images/favori.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onPressed: () async {
              String query = '';
              final result = await showDialog<String>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Ajouter/Retirer un favori'),
                    content: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Numéro de verset',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => query = value,
                      onSubmitted: (value) => Navigator.of(context).pop(value),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(query),
                        child: const Text('Valider'),
                      ),
                    ],
                  );
                },
              );
              if (result != null && result.isNotEmpty) {
                final verseNum = int.tryParse(result);
                final index = versesToShow.indexWhere((v) => v['number'] == verseNum?.toString());
                if (verseNum != null && index != -1) {
                  final favoritesNotifier = ref.read(favoriteBibleVersesProvider.notifier);
                  final favorites = List<int>.from(ref.read(favoriteBibleVersesProvider));
                  if (favorites.contains(verseNum)) {
                    favorites.remove(verseNum);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verset $verseNum retiré des favoris.')),
                    );
                  } else {
                    favorites.add(verseNum);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verset $verseNum ajouté aux favoris !')),
                    );
                  }
                  favoritesNotifier.state = favorites;
                  await BibleLocalStorageService.saveFavorites(favorites);
                  setState(() {
                    _highlightedVerseIndex = index;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _itemScrollController.scrollTo(
                      index: index,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  });
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _highlightedVerseIndex == index) {
                      setState(() {
                        _highlightedVerseIndex = null;
                      });
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verset $result non trouvé dans ce chapitre.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // En-tête du chapitre
                _buildChapterHeader(),
                // Options de lecture
                _buildReadingOptions(),
                // Contenu des versets
                Expanded(
                  child: _buildVersesList(favoriteVerses),
                ),
                // Barre d'outils du bas
                _buildBottomToolbar(),
              ],
            ),
    );
  }
  
  // En-tête du chapitre avec navigation précédent/suivant
  Widget _buildChapterHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bouton Précédent
              TextButton.icon(
                onPressed: () {
                  // Navigation vers le chapitre précédent ou livre précédent
                  String prevBook = widget.book;
                  int prevChapter = widget.chapter;
                  
                  // Utiliser la liste centralisée des livres
                  int bookIndex = _bibleBooks.indexOf(widget.book);
                  
                  if (widget.chapter > 1) {
                    // Chapitre précédent dans le même livre
                    prevChapter = widget.chapter - 1;
                  } else if (bookIndex > 0) {
                    // Livre précédent, dernier chapitre
                    prevBook = _bibleBooks[bookIndex - 1];
                    prevChapter = _bibleChapters[prevBook] ?? 1;
                  }
                  
                  // Navigation seulement si on n'est pas au début de la Bible
                  if (bookIndex > 0 || widget.chapter > 1) {
                    context.go('/bible?book=$prevBook&chapter=$prevChapter');
                  }
                },
                icon: SvgPicture.asset(
                  'assets/images/precedent.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(Colors.grey.shade600, BlendMode.srcIn),
                ),
                label: Text(
                  'Précédent',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
              // Titre du chapitre
              Column(
                children: [
                  Text(
                    '${widget.book} ${widget.chapter}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  /*
                  Text(
                    'Les Béatitudes',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  */
                ],
              ),
              // Bouton Suivant
              TextButton.icon(
                onPressed: () {
                  // Navigation vers le chapitre suivant ou livre suivant
                  String nextBook = widget.book;
                  int nextChapter = widget.chapter + 1;
                  
                  // Utiliser la liste centralisée des livres
                  int bookIndex = _bibleBooks.indexOf(widget.book);
                  int currentBookChapters = _bibleChapters[widget.book] ?? 1;
                  
                  // Navigation vers le livre suivant si on est au dernier chapitre
                  if (widget.chapter >= currentBookChapters && bookIndex < _bibleBooks.length - 1) {
                    nextBook = _bibleBooks[bookIndex + 1];
                    nextChapter = 1;
                  }
                  
                  // Navigation seulement si on n'est pas à la fin de la Bible
                  if (bookIndex < _bibleBooks.length - 1 || widget.chapter < currentBookChapters) {
                    context.go('/bible?book=$nextBook&chapter=$nextChapter');
                  }
                },
                icon: Text(
                  'Suivant',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                label: SvgPicture.asset(
                  'assets/images/suivant.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(Colors.grey.shade600, BlendMode.srcIn),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Options de lecture (taille de texte, thème, traduction)
  Widget _buildReadingOptions() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Taille de texte
          InkWell(
            onTap: () async {
              final currentFontSize = ref.read(bibleFontSizeProvider);
              double tempSize = currentFontSize;
              final newSize = await showModalBottomSheet<double>(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setState) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Taille du texte', style: TextStyle(fontWeight: FontWeight.bold)),
                          Slider(
                            min: 12,
                            max: 32,
                            divisions: 10,
                            value: tempSize,
                            label: tempSize.round().toString(),
                            onChanged: (value) => setState(() => tempSize = value),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Petit'),
                              Text('Moyen'),
                              Text('Grand'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, tempSize),
                            child: const Text('Valider'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
              if (newSize != null) {
                ref.read(bibleFontSizeProvider.notifier).state = newSize;
                await BibleLocalStorageService.saveFontSize(newSize);
              }
            },
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/typography.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(Colors.grey.shade700, BlendMode.srcIn),
                ),
                const SizedBox(width: 4),
                const Text('Aa', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          
          // Thème de l'espace verset biblique
          // Ce bouton ouvre un dialogue pour choisir le thème d'affichage des versets
          Consumer(
            builder: (context, ref, _) {
              final currentTheme = ref.watch(bibleVersesThemeProvider);
              String themeLabel;
              switch (currentTheme) {
                case BibleVersesTheme.dark:
                  themeLabel = 'Sombre';
                  break;
                case BibleVersesTheme.sepia:
                  themeLabel = 'Sépia';
                  break;
                case BibleVersesTheme.light:
                  themeLabel = 'Clair';
                  break;
              }
              return InkWell(
                onTap: () async {
                  final selected = await showDialog<BibleVersesTheme>(
                    context: context,
                    builder: (context) {
                      BibleVersesTheme tempTheme = currentTheme;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            title: const Text('Choisir le thème des versets'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioListTile<BibleVersesTheme>(
                                  title: const Text('Clair'),
                                  value: BibleVersesTheme.light,
                                  groupValue: tempTheme,
                                  onChanged: (val) {
                                    setState(() { tempTheme = BibleVersesTheme.light; });
                                  },
                                  selected: tempTheme == BibleVersesTheme.light,
                                  activeColor: Colors.blue,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                                RadioListTile<BibleVersesTheme>(
                                  title: const Text('Sombre'),
                                  value: BibleVersesTheme.dark,
                                  groupValue: tempTheme,
                                  onChanged: (val) {
                                    setState(() { tempTheme = BibleVersesTheme.dark; });
                                  },
                                  selected: tempTheme == BibleVersesTheme.dark,
                                  activeColor: Colors.blue,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                                RadioListTile<BibleVersesTheme>(
                                  title: const Text('Sépia'),
                                  value: BibleVersesTheme.sepia,
                                  groupValue: tempTheme,
                                  onChanged: (val) {
                                    setState(() { tempTheme = BibleVersesTheme.sepia; });
                                  },
                                  selected: tempTheme == BibleVersesTheme.sepia,
                                  activeColor: Colors.blue,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(tempTheme),
                                child: const Text('Valider'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                  if (selected != null && selected != currentTheme) {
                    ref.read(bibleVersesThemeProvider.notifier).state = selected;
                    await BibleLocalStorageService.saveTheme(_themeToString(selected));
                  }
                },
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/theme.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(Colors.grey.shade700, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 4),
                    Text('Thème: $themeLabel', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
          
          // Traduction
          InkWell(
            onTap: () {},
            child: Row(
              children: [
                const Text('LSG', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Text(
                  'Changer',
                  style: TextStyle(color: bibleBlueColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Liste des versets
  Widget _buildVersesList(List<int> favoriteVerses) {
    // Récupère la map des versets surlignés depuis le provider
    final highlightedMap = ref.watch(highlightedBibleVersesProvider);
    final versesTheme = ref.watch(bibleVersesThemeProvider);
    // Applique le thème choisi à la zone des versets
    return Container(
      color: BibleVersesThemeStyles.background(versesTheme),
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: const EdgeInsets.all(16),
        itemCount: versesToShow.length,
        itemBuilder: (context, index) {
          final verse = versesToShow[index];
          final verseNumber = int.parse(verse['number']!);
          final isFavorite = favoriteVerses.contains(verseNumber);
          // Surlignage local : soit temporaire (recherche), soit persistant (stocké)
          final isHighlighted = _highlightedVerseIndex == index || (highlightedMap[verseNumber] ?? false);
          return _buildVerseItem(
            number: verseNumber,
            text: verse['text']!,
            isFavorite: isFavorite,
            isHighlighted: isHighlighted,
            versesTheme: versesTheme,
          );
        },
      ),
    );
  }
  
  // Item de verset individuel
  Widget _buildVerseItem({
    required int number,
    required String text,
    required bool isFavorite,
    bool isHighlighted = false,
    BibleVersesTheme versesTheme = BibleVersesTheme.light,
  }) {
    // Applique le fond et la couleur du texte selon le thème choisi
    final backgroundColor = isHighlighted
        ? Colors.yellow.withOpacity(0.5)
        : (isFavorite ? const Color(0xFFE3F2FD) : Colors.transparent);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro du verset
          Text(
            number.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: BibleVersesThemeStyles.verseNumber(versesTheme),
            ),
          ),
          const SizedBox(width: 8),
          // Texte du verset
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final fontSize = ref.watch(bibleFontSizeProvider);
                return Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.5,
                    color: BibleVersesThemeStyles.text(versesTheme),
                  ),
                );
              },
            ),
          ),
          // Affiche l'icône favori même si le verset est surligné
          if (isFavorite)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SvgPicture.asset(
                'assets/images/coeur.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(Colors.blue.shade300, BlendMode.srcIn),
              ),
            ),
        ],
      ),
    );
  }
  
  // Barre d'outils du bas
  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildToolbarButton(
              svgAsset: 'assets/images/notes.svg',
              label: 'Notes',
              color: const Color(0xFF64B5F6),
              onTap: () async {
                int? selectedVerseNum;
                await showDialog(
                  context: context,
                  builder: (context) {
                    String query = '';
                    return AlertDialog(
                      title: const Text('Notes sur un verset'),
                      content: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Numéro de verset',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => query = value,
                        onSubmitted: (value) => Navigator.of(context).pop(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(query),
                          child: const Text('Voir les notes'),
                        ),
                      ],
                    );
                  },
                ).then((result) async {
                  if (result != null && result.isNotEmpty) {
                    final verseNum = int.tryParse(result);
                    final index = versesToShow.indexWhere((v) => v['number'] == verseNum?.toString());
                    if (verseNum != null && index != -1) {
                      selectedVerseNum = verseNum;
                      await showDialog(
                        context: context,
                        builder: (context) {
                          return NotesDialog(
                            verseNum: selectedVerseNum!,
                          );
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verset $result non trouvé dans ce chapitre.')),
                      );
                    }
                  }
                });
              },
            ),
            _buildToolbarButton(
              svgAsset: 'assets/images/surligner.svg',
              label: 'Surligner',
              color: const Color(0xFF4CAF50),
              onTap: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    String query = '';
                    return AlertDialog(
                      title: const Text('Surligner un verset'),
                      content: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Numéro de verset',
                        ),
                        onChanged: (value) => query = value,
                        onSubmitted: (value) => Navigator.of(context).pop(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(query),
                          child: const Text('Surligner'),
                        ),
                      ],
                    );
                  },
                );
                if (result != null && result.isNotEmpty) {
                  final verseNum = int.tryParse(result);
                  final index = versesToShow.indexWhere((v) => v['number'] == verseNum.toString());
                  if (index != -1) {
                    // Ajout local du surlignage dans le provider
                    final highlightedNotifier = ref.read(highlightedBibleVersesProvider.notifier);
                    final highlightedMap = Map<int, bool>.from(ref.read(highlightedBibleVersesProvider));
                    bool wasHighlighted = highlightedMap[verseNum] ?? false;
                    if (!wasHighlighted) {
                      // Surligner uniquement
                      highlightedMap[verseNum!] = true;
                      highlightedNotifier.state = highlightedMap;
                      await BibleLocalStorageService.saveHighlights(highlightedMap);
                      setState(() {
                        _highlightedVerseIndex = index;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _itemScrollController.scrollTo(
                          index: index,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verset $verseNum surligné !')),
                      );
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted && _highlightedVerseIndex == index) {
                          setState(() {
                            _highlightedVerseIndex = null;
                          });
                        }
                      });
                    } else {
                      // Si déjà surligné, désactive le surlignage
                      highlightedMap.remove(verseNum);
                      highlightedNotifier.state = highlightedMap;
                      await BibleLocalStorageService.saveHighlights(highlightedMap);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Surlignage retiré pour le verset $verseNum.')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verset $result non trouvé dans ce chapitre.')),
                    );
                  }
                }
              },
            ),
            _buildToolbarButton(
              svgAsset: 'assets/images/partager.svg',
              label: 'Partager',
              color: const Color(0xFF9E9E9E),
              onTap: () async {
                String query = '';
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Partager un verset'),
                      content: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Numéro de verset',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => query = value,
                        onSubmitted: (value) => Navigator.of(context).pop(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(query),
                          child: const Text('Partager'),
                        ),
                      ],
                    );
                  },
                );
                if (result != null && result.isNotEmpty) {
                  final verseNum = int.tryParse(result);
                  final verse = versesToShow.firstWhere(
                    (v) => v['number'] == verseNum?.toString(),
                    orElse: () => {},
                  );
                  if (verse.isNotEmpty) {
                    final text = verse['text']!;
                    final reference = '${widget.book} ${widget.chapter}:$verseNum';
                    final message = '$text\n\n$reference\nPartagé via EMB Mission App';
                    await Share.share(message);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verset $result non trouvé dans ce chapitre.')),
                    );
                  }
                }
              },
            ),
            _buildToolbarButton(
              svgAsset: 'assets/images/plan.svg',
              label: 'Plan',
              color: const Color(0xFFAB47BC),
              onTap: () {
                final userId = ref.read(userIdProvider);
                if (userId != null) {
                  // Utilisateur connecté : naviguer vers la page du plan de lecture avec GoRouter
                  context.push('/bible/reading-plans');
                } else {
                  // Non connecté : rediriger vers la page de bienvenue (comportement classique)
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const WelcomeScreen(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Bouton de la barre d'outils
  Widget _buildToolbarButton({
    required String svgAsset,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgAsset,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ],
      ),
    );
  }
  
  @override
  void didUpdateWidget(covariant BibleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book != widget.book || oldWidget.chapter != widget.chapter) {
      _loadVerses();
      _highlightedVerseIndex = null;
    }
  }

  String? get range => widget.range;
}

// --- Classe de dialogue pour notes, version compatible Riverpod ---
// (À placer tout en bas du fichier, en dehors de toute autre classe)
// Classe de dialogue permettant d'afficher, ajouter, modifier et supprimer les notes d'un verset donné.
// Utilise Riverpod pour la gestion locale des notes (Map<int, List<String>>)
class NotesDialog extends StatefulWidget {
  final int verseNum;
  const NotesDialog({Key? key, required this.verseNum}) : super(key: key);

  @override
  State<NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<NotesDialog> {
  // Contrôleur pour la zone de saisie d'ajout de note
  late TextEditingController addController;

  @override
  void initState() {
    super.initState();
    // Initialisation du contrôleur de texte pour l'ajout de note
    addController = TextEditingController();
  }

  @override
  void dispose() {
    // Libération du contrôleur lors de la fermeture du dialogue
    addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Consumer permet d'accéder au provider Riverpod pour les notes
    return Consumer(
      builder: (context, ref, _) {
        // Récupère la map des notes (clé = numéro de verset, valeur = liste de notes)
        final notesMap = ref.watch(bibleNotesProvider);
        // Liste des notes pour le verset sélectionné
        final notes = notesMap[widget.verseNum] ?? [];
        // Notifier pour modifier la map des notes
        final notesNotifier = ref.read(bibleNotesProvider.notifier);

        return AlertDialog(
          // Titre du dialogue avec le numéro du verset
          title: Text('Notes pour le verset ${widget.verseNum}'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Affiche un message si aucune note n'est présente
                if (notes.isEmpty)
                  const Text('Aucune note pour ce verset.'),
                // Affiche la liste des notes existantes avec possibilité d'édition et suppression
                if (notes.isNotEmpty)
                  ...notes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final note = entry.value;
                    // Contrôleur pour éditer la note existante
                    final editController = TextEditingController(text: note);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Zone de texte pour modifier la note
                        Expanded(
                          child: TextField(
                            controller: editController,
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Note',
                            ),
                            onSubmitted: (val) {
                              // Met à jour la note modifiée dans la liste
                              final updated = [...notes];
                              updated[i] = val;
                              final newMap = {
                                ...notesMap,
                                widget.verseNum: updated,
                              };
                              notesNotifier.state = newMap;
                              BibleLocalStorageService.saveNotes(newMap);
                              setState(() {});
                            },
                          ),
                        ),
                        // Bouton pour supprimer la note
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            final updated = [...notes]..removeAt(i);
                            final newMap = {
                              ...notesMap,
                              widget.verseNum: updated,
                            };
                            notesNotifier.state = newMap;
                            BibleLocalStorageService.saveNotes(newMap);
                            setState(() {});
                          },
                        ),
                      ],
                    );
                  }),
                const SizedBox(height: 12),
                // Zone d'ajout d'une nouvelle note
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addController,
                        decoration: const InputDecoration(
                          hintText: 'Ajouter une note...',
                        ),
                        onSubmitted: (val) {
                          // Ajoute la note si le champ n'est pas vide
                          if (val.trim().isNotEmpty) {
                            final updated = [...notes, val.trim()];
                            final newMap = {
                              ...notesMap,
                              widget.verseNum: updated,
                            };
                            notesNotifier.state = newMap;
                            BibleLocalStorageService.saveNotes(newMap);
                            addController.clear();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    // Bouton pour ajouter la note
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.blue),
                      onPressed: () {
                        final val = addController.text.trim();
                        if (val.isNotEmpty) {
                          final updated = [...notes, val];
                          final newMap = {
                            ...notesMap,
                            widget.verseNum: updated,
                          };
                          notesNotifier.state = newMap;
                          BibleLocalStorageService.saveNotes(newMap);
                          addController.clear();
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            // Bouton pour fermer le dialogue
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
