/// Modèle pour les prières
class Prayer {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final String? audioUrl;
  final int? duration; // en secondes pour l'audio
  final bool isLiked;

  Prayer({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    this.audioUrl,
    this.duration,
    this.isLiked = false,
  });

  factory Prayer.fromJson(Map<String, dynamic> json) {
    return Prayer(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      category: json['category'],
      createdAt: DateTime.parse(json['createdAt']),
      audioUrl: json['audioUrl'],
      duration: json['duration'],
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'audioUrl': audioUrl,
      'duration': duration,
      'isLiked': isLiked,
    };
  }

  Prayer copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    DateTime? createdAt,
    String? audioUrl,
    int? duration,
    bool? isLiked,
  }) {
    return Prayer(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

/// Catégories de prières disponibles
enum PrayerCategory {
  praise,
  intercession,
  thanksgiving,
  confession,
  guidance,
}

/// Extension pour faciliter la conversion entre string et enum PrayerCategory
extension PrayerCategoryExtension on PrayerCategory {
  String get displayName {
    switch (this) {
      case PrayerCategory.praise:
        return 'Louange';
      case PrayerCategory.intercession:
        return 'Intercession';
      case PrayerCategory.thanksgiving:
        return 'Reconnaissance';
      case PrayerCategory.confession:
        return 'Confession';
      case PrayerCategory.guidance:
        return 'Direction';
    }
  }

  static PrayerCategory fromString(String value) {
    return PrayerCategory.values.firstWhere(
      (category) => category.toString().split('.').last == value,
      orElse: () => PrayerCategory.praise,
    );
  }
}

class PrayerDetail {
  final int id;
  final String titre;
  final String description;
  final String date;
  final String heure;
  final String statut;
  final String type;
  final String? icone;
  final String? couleur;
  final String verset;
  final String transcription;
  final String audioUrl;
  final String fichierTranscription;
  final int duree;
  final int vues;
  final List<RessourceLiee> ressourcesLiees;

  PrayerDetail({
    required this.id,
    required this.titre,
    required this.description,
    required this.date,
    required this.heure,
    required this.statut,
    required this.type,
    required this.icone,
    required this.couleur,
    required this.verset,
    required this.transcription,
    required this.audioUrl,
    required this.fichierTranscription,
    required this.duree,
    required this.vues,
    required this.ressourcesLiees,
  });

  factory PrayerDetail.fromJson(Map<String, dynamic> json) {
    print('🔍 PrayerDetail.fromJson - JSON reçu: $json');
    
    try {
      final id = json['id'] ?? 0;
      print('✅ id: $id');
      
      final titre = json['titre']?.toString() ?? '';
      print('✅ titre: $titre');
      
      final description = json['description']?.toString() ?? '';
      print('✅ description: $description');
      
      final date = json['date']?.toString() ?? '';
      print('✅ date: $date');
      
      final heure = json['heure']?.toString() ?? '';
      print('✅ heure: $heure');
      
      final statut = json['statut']?.toString() ?? '';
      print('✅ statut: $statut');
      
      final type = json['type']?.toString() ?? '';
      print('✅ type: $type');
      
      final icone = json['icone']?.toString();
      print('✅ icone: $icone');
      
      final couleur = json['couleur']?.toString();
      print('✅ couleur: $couleur');
      
      final verset = json['verset']?.toString() ?? '';
      print('✅ verset: $verset');
      
      final transcription = json['transcription']?.toString() ?? '';
      print('✅ transcription: $transcription');
      
      final audioUrl = json['audio_url']?.toString() ?? '';
      print('✅ audioUrl: $audioUrl');
      
      final fichierTranscription = json['fichier_transcription']?.toString() ?? '';
      print('✅ fichierTranscription: $fichierTranscription');
      
      final duree = json['duree'] ?? 0;
      print('✅ duree: $duree');
      
      final vues = json['vues'] ?? 0;
      print('✅ vues: $vues');
      
      final ressourcesLiees = (json['ressources_liees'] as List<dynamic>?)?.map((e) => RessourceLiee.fromJson(e)).toList() ?? [];
      print('✅ ressourcesLiees: ${ressourcesLiees.length} éléments');
      
    return PrayerDetail(
        id: id,
        titre: titre,
        description: description,
        date: date,
        heure: heure,
        statut: statut,
        type: type,
        icone: icone,
        couleur: couleur,
        verset: verset,
        transcription: transcription,
        audioUrl: audioUrl,
        fichierTranscription: fichierTranscription,
        duree: duree,
        vues: vues,
        ressourcesLiees: ressourcesLiees,
      );
    } catch (e, stack) {
      print('❌ Erreur dans PrayerDetail.fromJson: $e');
      print('❌ Stack trace: $stack');
      rethrow;
    }
  }
}

class RessourceLiee {
  final String type;
  final String titre;
  final String note;
  final String url;

  RessourceLiee({
    required this.type,
    required this.titre,
    required this.note,
    required this.url,
  });

  factory RessourceLiee.fromJson(Map<String, dynamic> json) {
    return RessourceLiee(
      type: json['type'],
      titre: json['titre'],
      note: json['note'],
      url: json['url'],
    );
  }
}
