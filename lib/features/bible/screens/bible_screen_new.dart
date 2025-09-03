import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Provider pour la traduction biblique sélectionnée
final bibleTranslationProvider = StateProvider<String>((ref) {
  return 'LSG'; // Louis Segond par défaut
});

/// Provider pour les versets favoris
final favoriteBibleVersesProvider = StateProvider<List<int>>((ref) {
  return [3]; // Par défaut, le verset 3 est en favori comme sur l'image
});

/// Provider pour la taille de police
final bibleFontSizeProvider = StateProvider<double>((ref) {
  return 16.0; // Taille par défaut
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
  // Couleur principale pour l'écran Bible
  final Color bibleBlueColor = const Color(0xFF64B5F6);
  
  // Versets du chapitre sélectionné
  late List<Map<String, String>> verses;

  @override
  void initState() {
    super.initState();
    // Initialiser les versets en fonction du livre et du chapitre
    _loadVerses();
  }

  // Charger les versets en fonction du livre et du chapitre
  void _loadVerses() {
    // Dans un cas réel, ces données viendraient d'une API ou d'une base de données
    // Pour l'exemple, on utilise des données statiques pour Matthieu 5
    if (widget.book == 'Matthieu' && widget.chapter == 5) {
      verses = [
        {
          'number': '1',
          'text': 'Voyant la foule, Jésus monta sur la montagne; et, après qu\'il se fut assis, ses disciples s\'approchèrent de lui.',
        },
        {
          'number': '2',
          'text': 'Puis, ayant ouvert la bouche, il les enseigna, et dit:',
        },
        {
          'number': '3',
          'text': 'Heureux les pauvres en esprit, car le royaume des cieux est à eux!',
        },
        {
          'number': '4',
          'text': 'Heureux les affligés, car ils seront consolés!',
        },
      ];
    } else {
      // Pour les autres livres/chapitres, on utilise des versets génériques
      verses = [
        {
          'number': '1',
          'text': 'Premier verset de ${widget.book} ${widget.chapter}.',
        },
        {
          'number': '2',
          'text': 'Deuxième verset de ${widget.book} ${widget.chapter}.',
        },
        {
          'number': '3',
          'text': 'Troisième verset de ${widget.book} ${widget.chapter}.',
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteVerses = ref.watch(favoriteBibleVersesProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: bibleBlueColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
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
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/images/bible/favori.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
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
          
          // Barre de navigation du bas
          _buildBottomNavBar(),
        ],
      ),
    );
  }
  
  // En-tête du chapitre avec navigation précédent/suivant
  Widget _buildChapterHeader() {
    return Container(
      color: bibleBlueColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bouton Précédent
              TextButton.icon(
                onPressed: () {},
                icon: SvgPicture.asset(
                  'assets/images/bible/precedent.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                label: const Text(
                  'Précédent',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
              
              // Titre du chapitre
              Column(
                children: [
                  Text(
                    '${widget.book} ${widget.chapter}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Les Béatitudes',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              
              // Bouton Suivant
              TextButton.icon(
                onPressed: () {},
                icon: const Text(
                  'Suivant',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                label: SvgPicture.asset(
                  'assets/images/bible/suivant.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Taille de texte
          InkWell(
            onTap: () {},
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/bible/typography.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(Colors.grey.shade700, BlendMode.srcIn),
                ),
                const SizedBox(width: 4),
                const Text('Aa', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          
          // Thème
          InkWell(
            onTap: () {},
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/bible/theme.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(Colors.grey.shade700, BlendMode.srcIn),
                ),
                const SizedBox(width: 4),
                const Text('Thème', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: verses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final verse = verses[index];
        final verseNumber = int.parse(verse['number']!);
        final isFavorite = favoriteVerses.contains(verseNumber);
        
        return _buildVerseItem(
          number: verseNumber,
          text: verse['text']!,
          isFavorite: isFavorite,
        );
      },
    );
  }
  
  // Item de verset individuel
  Widget _buildVerseItem({required int number, required String text, required bool isFavorite}) {
    final backgroundColor = isFavorite ? const Color(0xFFE3F2FD) : Colors.transparent;
    
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
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          
          // Texte du verset
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          
          // Bouton favori (uniquement pour le verset favori)
          if (isFavorite)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SvgPicture.asset(
                'assets/images/bible/coeur.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(Colors.blue.shade300, BlendMode.srcIn),
              ),
            ),
          
          // Bouton + (pour les versets non favoris)
          if (!isFavorite)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SvgPicture.asset(
                'assets/images/bible/plus.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
              ),
            ),
        ],
      ),
    );
  }
  
  // Barre d'outils du bas
  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(
            svgAsset: 'assets/images/bible/notes.svg',
            label: 'Notes',
          ),
          _buildToolbarButton(
            svgAsset: 'assets/images/bible/surligner.svg',
            label: 'Surligner',
          ),
          _buildToolbarButton(
            svgAsset: 'assets/images/bible/partager.svg',
            label: 'Partager',
          ),
          _buildToolbarButton(
            svgAsset: 'assets/images/bible/plan.svg',
            label: 'Plan',
          ),
        ],
      ),
    );
  }
  
  // Bouton de la barre d'outils
  Widget _buildToolbarButton({required String svgAsset, required String label}) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgAsset,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(Colors.grey.shade700, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
  
  // Barre de navigation du bas
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavBarItem(
            svgAsset: 'assets/images/home.svg',
            label: 'Accueil',
            isSelected: false,
          ),
          _buildNavBarItem(
            svgAsset: 'assets/images/bible.svg',
            label: 'Bible',
            isSelected: true,
          ),
          _buildNavBarItem(
            svgAsset: 'assets/images/communauté.svg',
            label: 'Communauté',
            isSelected: false,
          ),
          _buildNavBarItem(
            svgAsset: 'assets/images/settings.svg',
            label: 'Paramètres',
            isSelected: false,
          ),
        ],
      ),
    );
  }
  
  // Élément de la barre de navigation
  Widget _buildNavBarItem({required String svgAsset, required String label, required bool isSelected}) {
    final color = isSelected ? bibleBlueColor : Colors.grey.shade600;
    
    return InkWell(
      onTap: () {
        if (!isSelected) {
          if (label == 'Accueil') {
            context.go('/');
          } else if (label == 'Bible') {
            context.go('/bible');
          } else if (label == 'Communauté') {
            context.go('/community');
          } else if (label == 'Paramètres') {
            context.go('/profile');
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgAsset,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}
