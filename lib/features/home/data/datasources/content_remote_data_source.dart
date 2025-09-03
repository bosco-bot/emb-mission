import '../models/content_item_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Interface pour la source de données distante des contenus
abstract class ContentRemoteDataSource {
  /// Récupère les contenus du jour depuis l'API
  Future<List<ContentItemModel>> getTodayContent();
  
  /// Récupère les contenus populaires depuis l'API
  Future<List<ContentItemModel>> getPopularContent();
  
  /// Récupère le statut du live depuis l'API
  Future<bool> getLiveStatus();
}

/// Implémentation de la source de données distante des contenus
/// Utilise des données simulées pour le moment, mais sera remplacée par des appels API réels
class ContentRemoteDataSourceImpl implements ContentRemoteDataSource {
  @override
  Future<List<ContentItemModel>> getTodayContent() async {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/today_home_events'),
    );
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['statevents'] == 'success') {
        final List<dynamic> data = jsonBody['dataevents'];
        return data.map((item) => ContentItemModel(
          id: (item['idevents'] ?? '').toString(),
          title: item['titre']?.toString() ?? '',
          description: item['description']?.toString(),
          imageUrl: null, // ou item['icone'] si tu veux afficher une icône
          audioUrl: null, // à adapter si tu as un champ audio
          videoUrl: null, // à adapter si tu as un champ vidéo
          date: null, // ou DateTime.parse(item['date_evenement']) si tu veux la date
          isLive: (item['statut']?.toString().toLowerCase() == 'live'),
          category: item['type']?.toString(),
        )).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Erreur lors du chargement des contenus du jour');
    }
  }
  
  @override
  Future<List<ContentItemModel>> getPopularContent() async {
    // Simulation de données pour le moment
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      ContentItemModel(
        id: '3',
        title: 'Témoignage inspirant',
        description: 'Un témoignage puissant de transformation',
        category: 'testimony',
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ContentItemModel(
        id: '4',
        title: 'Enseignement sur la foi',
        description: 'Comment développer une foi inébranlable',
        category: 'teaching',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }
  
  @override
  Future<bool> getLiveStatus() async {
    // Simulation de données pour le moment
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}
