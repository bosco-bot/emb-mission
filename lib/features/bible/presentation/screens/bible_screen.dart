import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/models/bible_verse.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/services/preferences_service.dart';
import 'package:emb_mission/core/theme/app_theme.dart';

/// Provider pour le chapitre biblique actuel
final currentBibleChapterProvider = StateProvider<BibleChapter?>((ref) => null);

/// Provider pour les versets favoris
final favoriteBibleVersesProvider = StateProvider<List<String>>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return preferencesService.getFavoriteVerses();
});

/// Provider pour la taille de police des versets
final bibleFontSizeProvider = StateProvider<double>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return preferencesService.getFontSize();
});

/// Écran de lecture de la Bible
class BibleScreen extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  
  const BibleScreen({
    super.key,
    required this.book,
    required this.chapter,
  });

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  final ScrollController _scrollController = ScrollController();
  late String _selectedBook;
  late int _selectedChapter;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.book;
    _selectedChapter = widget.chapter;
    _loadChapter();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Charge le chapitre biblique sélectionné
  Future<void> _loadChapter() async {
    final contentService = ref.read(contentServiceProvider);
    final chapter = await contentService.getBibleChapter(_selectedBook, _selectedChapter);
    ref.read(currentBibleChapterProvider.notifier).state = chapter;
  }

  /// Ajoute ou supprime un verset des favoris
  void _toggleFavorite(String verseReference) {
    final preferencesService = ref.read(preferencesServiceProvider);
    final favorites = List<String>.from(ref.read(favoriteBibleVersesProvider));
    
    if (favorites.contains(verseReference)) {
      favorites.remove(verseReference);
    } else {
      favorites.add(verseReference);
    }
    
    preferencesService.saveFavoriteVerses(favorites);
    ref.read(favoriteBibleVersesProvider.notifier).state = favorites;
  }

  /// Change la taille de police
  void _changeFontSize(double size) {
    final preferencesService = ref.read(preferencesServiceProvider);
    preferencesService.saveFontSize(size);
    ref.read(bibleFontSizeProvider.notifier).state = size;
  }

  @override
  Widget build(BuildContext context) {
    final currentChapter = ref.watch(currentBibleChapterProvider);
    final favorites = ref.watch(favoriteBibleVersesProvider);
    final fontSize = ref.watch(bibleFontSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.bibleColor,
              child: const Icon(
                Icons.menu_book,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Bible'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => _showFavorites(),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSettings(),
          ),
        ],
      ),
      body: currentChapter == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Sélecteur de livre et chapitre
                _buildChapterSelector(currentChapter),
                
                // Versets
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: currentChapter.verses.length,
                    itemBuilder: (context, index) {
                      final verse = currentChapter.verses[index];
                      final verseRef = verse.reference;
                      final isFavorite = favorites.contains(verseRef);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Numéro du verset
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 8, top: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.bibleColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  verse.verse.toString(),
                                  style: TextStyle(
                                    color: AppTheme.bibleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Contenu du verset
                            Expanded(
                              child: Text(
                                verse.text,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            
                            // Bouton favori
                            IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.bookmark
                                    : Icons.bookmark_outline,
                                color: isFavorite
                                    ? AppTheme.bibleColor
                                    : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => _toggleFavorite(verseRef),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.bibleColor,
        child: const Icon(Icons.format_size),
        onPressed: () => _showFontSizeDialog(),
      ),
    );
  }

  /// Construit le sélecteur de livre et chapitre
  Widget _buildChapterSelector(BibleChapter currentChapter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.bibleColor.withOpacity(0.1),
      child: Row(
        children: [
          // Livre
          Expanded(
            child: InkWell(
              onTap: () => _showBookSelector(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Text(
                      currentChapter.book,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Chapitre
          InkWell(
            onTap: () => _showChapterSelector(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Text(
                    'Chapitre ${currentChapter.chapter}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Affiche le sélecteur de livre
  void _showBookSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        // Liste fictive de livres bibliques
        final books = [
          'Genèse', 'Exode', 'Lévitique', 'Nombres', 'Deutéronome',
          'Matthieu', 'Marc', 'Luc', 'Jean', 'Actes',
          'Romains', '1 Corinthiens', '2 Corinthiens', 'Galates', 'Éphésiens',
          'Philippiens', 'Colossiens', '1 Thessaloniciens', '2 Thessaloniciens',
          '1 Timothée', '2 Timothée', 'Tite', 'Philémon', 'Hébreux',
          'Jacques', '1 Pierre', '2 Pierre', '1 Jean', '2 Jean', '3 Jean',
          'Jude', 'Apocalypse'
        ];
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sélectionner un livre',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bibleColor,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isSelected = book == _selectedBook;
                  
                  return ListTile(
                    title: Text(
                      book,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.bibleColor : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check,
                            color: AppTheme.bibleColor,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedBook = book;
                        _selectedChapter = 1; // Réinitialiser au chapitre 1
                      });
                      Navigator.pop(context);
                      _loadChapter();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Affiche le sélecteur de chapitre
  void _showChapterSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        // Nombre fictif de chapitres (dépendrait du livre)
        final chapterCount = _selectedBook == 'Matthieu' ? 28 : 20;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sélectionner un chapitre',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bibleColor,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: chapterCount,
                itemBuilder: (context, index) {
                  final chapter = index + 1;
                  final isSelected = chapter == _selectedChapter;
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedChapter = chapter;
                      });
                      Navigator.pop(context);
                      _loadChapter();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.bibleColor
                            : AppTheme.bibleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          chapter.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.bibleColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Affiche les versets favoris
  void _showFavorites() {
    final favorites = ref.read(favoriteBibleVersesProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Versets favoris',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.bibleColor,
                    ),
                  ),
                ),
                Expanded(
                  child: favorites.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun verset favori',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            final reference = favorites[index];
                            // Ici, on devrait charger le verset depuis le service
                            // Pour l'exemple, on affiche juste la référence
                            return ListTile(
                              leading: Icon(
                                Icons.bookmark,
                                color: AppTheme.bibleColor,
                              ),
                              title: Text(reference),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  _toggleFavorite(reference);
                                  Navigator.pop(context);
                                  _showFavorites();
                                },
                              ),
                              onTap: () {
                                // Naviguer vers le verset
                                Navigator.pop(context);
                              },
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
  }

  /// Affiche les paramètres
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bibleColor,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('Taille du texte'),
              onTap: () {
                Navigator.pop(context);
                _showFontSizeDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Thème'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Traduction'),
              onTap: () {},
            ),
          ],
        );
      },
    );
  }

  /// Affiche le dialogue de taille de police
  void _showFontSizeDialog() {
    final fontSize = ref.read(bibleFontSizeProvider);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Taille du texte',
                style: TextStyle(color: AppTheme.bibleColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exemple de texte',
                    style: TextStyle(fontSize: fontSize),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 14,
                          max: 24,
                          divisions: 5,
                          activeColor: AppTheme.bibleColor,
                          onChanged: (value) {
                            setState(() {
                              _changeFontSize(value);
                            });
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Fermer'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
