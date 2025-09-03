/// Modèle pour les versets bibliques
class BibleVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;
  final bool isHighlighted;
  final bool isFavorite;
  final String? note;

  BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    this.isHighlighted = false,
    this.isFavorite = false,
    this.note,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      book: json['book'],
      chapter: json['chapter'],
      verse: json['verse'],
      text: json['text'],
      isHighlighted: json['isHighlighted'] ?? false,
      isFavorite: json['isFavorite'] ?? false,
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      'isHighlighted': isHighlighted,
      'isFavorite': isFavorite,
      'note': note,
    };
  }

  BibleVerse copyWith({
    String? book,
    int? chapter,
    int? verse,
    String? text,
    bool? isHighlighted,
    bool? isFavorite,
    String? note,
  }) {
    return BibleVerse(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      text: text ?? this.text,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      isFavorite: isFavorite ?? this.isFavorite,
      note: note ?? this.note,
    );
  }

  /// Retourne la référence du verset (ex: Matthieu 5:3)
  String get reference => '$book $chapter:$verse';
}

/// Modèle pour un chapitre biblique
class BibleChapter {
  final String book;
  final String bookTitle;
  final int chapter;
  final String? chapterTitle;
  final List<BibleVerse> verses;

  BibleChapter({
    required this.book,
    required this.bookTitle,
    required this.chapter,
    this.chapterTitle,
    required this.verses,
  });

  factory BibleChapter.fromJson(Map<String, dynamic> json) {
    return BibleChapter(
      book: json['book'],
      bookTitle: json['bookTitle'],
      chapter: json['chapter'],
      chapterTitle: json['chapterTitle'],
      verses: (json['verses'] as List)
          .map((verse) => BibleVerse.fromJson(verse))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'bookTitle': bookTitle,
      'chapter': chapter,
      'chapterTitle': chapterTitle,
      'verses': verses.map((verse) => verse.toJson()).toList(),
    };
  }

  /// Retourne la référence du chapitre (ex: Matthieu 5)
  String get reference => '$book $chapter';
  
  /// Retourne la référence complète du chapitre (ex: Matthieu 5 - Les Béatitudes)
  String get fullReference => 
      chapterTitle != null ? '$book $chapter - $chapterTitle' : '$book $chapter';
}
