import 'package:emb_mission/core/models/bible_verse.dart';
import 'package:emb_mission/core/models/content_item.dart';
import 'package:emb_mission/core/models/testimony.dart';

/// Données mockées pour l'application
class MockData {
  /// Données pour la page d'accueil
  static final List<ContentItem> homeItems = [
    ContentItem(
      id: '1',
      title: 'Prière du matin',
      subtitle: '8:00 - En direct',
      type: ContentType.prayer,
      isLive: true,
      imageUrl: 'assets/images/prayer_morning.png',
    ),
    ContentItem(
      id: '2',
      title: 'Étude biblique',
      subtitle: '20:00 - Ce soir',
      type: ContentType.bibleStudy,
      isLive: false,
      imageUrl: 'assets/images/bible_study.png',
    ),
  ];

  /// Données pour les contenus populaires
  static final List<ContentItem> popularItems = [
    ContentItem(
      id: '3',
      title: 'Témoignages',
      viewCount: 1200,
      type: ContentType.testimony,
      imageUrl: 'assets/images/testimonies.png',
    ),
    ContentItem(
      id: '4',
      title: 'Prières',
      viewCount: 890,
      type: ContentType.prayer,
      imageUrl: 'assets/images/prayers.png',
    ),
  ];

  /// Données pour la recherche
  static final List<ContentItem> searchResults = [
    // Résultats audio
    ContentItem(
      id: '5',
      title: 'Prière du matin - Janvier',
      subtitle: 'Méditation • 15 min',
      type: ContentType.audio,
      viewCount: 1200,
      duration: 15,
      imageUrl: 'assets/images/prayer_morning_jan.png',
    ),
    ContentItem(
      id: '6',
      title: 'Témoignage de Marie',
      subtitle: 'Témoignage • 8 min',
      type: ContentType.audio,
      viewCount: 890,
      duration: 8,
      imageUrl: 'assets/images/testimony_marie.png',
    ),
    // Résultats vidéo
    ContentItem(
      id: '7',
      title: 'Étude biblique - Matthieu 5',
      subtitle: 'Enseignement • 45 min',
      type: ContentType.video,
      viewCount: 2100,
      duration: 45,
      imageUrl: 'assets/images/bible_study_matt5.png',
    ),
    // Résultats articles
    ContentItem(
      id: '8',
      title: 'La puissance de la prière',
      subtitle: 'Article • 5 min de lecture',
      type: ContentType.article,
      viewCount: 1500,
      imageUrl: 'assets/images/prayer_power.png',
    ),
  ];

  /// Données pour les témoignages
  static final List<Testimony> testimonies = [
    Testimony(
      id: '1',
      authorName: 'Marie Dubois',
      authorImageUrl: 'assets/images/profile_marie.png',
      category: TestimonyCategory.healing,
      content: 'J\'ai été guérie d\'une maladie chronique après la prière. Gloire à Dieu !',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      inputMode: InputMode.text,
      likeCount: 24,
    ),
    Testimony(
      id: '2',
      authorName: 'Jean Martin',
      authorImageUrl: 'assets/images/profile_jean.png',
      category: TestimonyCategory.family,
      content: 'Ma famille a été restaurée après des années de conflit. La prière a tout changé.',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      inputMode: InputMode.text,
      likeCount: 18,
    ),
    Testimony(
      id: '3',
      authorName: 'Sophie Laurent',
      authorImageUrl: 'assets/images/profile_sophie.png',
      category: TestimonyCategory.work,
      content: 'J\'ai trouvé un emploi après 6 mois de chômage, juste après avoir participé à la semaine de prière.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      inputMode: InputMode.text,
      likeCount: 32,
    ),
    Testimony(
      id: '4',
      authorName: 'Paul Dupont',
      authorImageUrl: 'assets/images/profile_paul.png',
      category: TestimonyCategory.prayer,
      content: 'Ma vie de prière a été transformée grâce aux enseignements de EMB Mission.',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      inputMode: InputMode.audio,
      audioUrl: 'assets/audio/testimony_paul.mp3',
      duration: 185, // 3:05 minutes
      likeCount: 45,
    ),
  ];

  /// Données pour la Bible - Matthieu 5
  static final BibleChapter matthieu5 = BibleChapter(
    book: 'Matthieu',
    bookTitle: 'Évangile selon Matthieu',
    chapter: 5,
    chapterTitle: 'Les Béatitudes',
    verses: [
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 1,
        text: 'Voyant la foule, Jésus monta sur la montagne; et, après qu\'il se fut assis, ses disciples s\'approchèrent de lui.',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 2,
        text: 'Puis, ayant ouvert la bouche, il les enseigna, et dit:',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 3,
        text: 'Heureux les pauvres en esprit, car le royaume des cieux est à eux!',
        isFavorite: true,
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 4,
        text: 'Heureux les affligés, car ils seront consolés!',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 5,
        text: 'Heureux les débonnaires, car ils hériteront la terre!',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 6,
        text: 'Heureux ceux qui ont faim et soif de la justice, car ils seront rassasiés!',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 7,
        text: 'Heureux les miséricordieux, car ils obtiendront miséricorde!',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 8,
        text: 'Heureux ceux qui ont le cœur pur, car ils verront Dieu!',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 9,
        text: 'Heureux ceux qui procurent la paix, car ils seront appelés fils de Dieu!',
      ),
      BibleVerse(
        book: 'Matthieu',
        chapter: 5,
        verse: 10,
        text: 'Heureux ceux qui sont persécutés pour la justice, car le royaume des cieux est à eux!',
      ),
    ],
  );
}
