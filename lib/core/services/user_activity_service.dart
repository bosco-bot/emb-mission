import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

/// Service pour gérer l'activité des utilisateurs connectés
class UserActivityService {
  static const _lastActiveKey = 'user_last_active';
  static const _baseUrl = 'https://embmission.com/mobileappebm/api';

  /// Met à jour le last_active de l'utilisateur connecté côté backend
  static Future<bool> updateUserLastActive(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/update_user_last_active?user_id=$userId');
      
      print('🔄 Mise à jour de l\'activité utilisateur: $userId');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la mise à jour de l\'activité utilisateur');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == 'true') {
          // Sauvegarder le timestamp de la dernière mise à jour
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastActiveKey, DateTime.now().toIso8601String());
          
          print('✅ Activité utilisateur mise à jour avec succès');
          return true;
        } else {
          print('⚠️ Réponse API indique un échec: ${data['success']}');
          return false;
        }
      } else {
        print('⚠️ Erreur serveur lors de la mise à jour de l\'activité utilisateur: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'activité utilisateur: $e');
      return false;
    }
  }

  /// Récupère le timestamp de la dernière activité
  static Future<DateTime?> getLastActiveTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActive = prefs.getString(_lastActiveKey);
      if (lastActive != null) {
        return DateTime.parse(lastActive);
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du timestamp d\'activité utilisateur: $e');
      return null;
    }
  }

  /// Vérifie si l'utilisateur est actif (dernière activité < 1 heure)
  static Future<bool> isUserActive() async {
    try {
      final lastActive = await getLastActiveTime();
      if (lastActive == null) return false;
      
      final difference = DateTime.now().difference(lastActive);
      return difference.inHours < 1;
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'activité utilisateur: $e');
      return false;
    }
  }

  /// Nettoie les données utilisateur (pour la déconnexion)
  static Future<void> clearUserActivityData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastActiveKey);
      print('🧹 Données d\'activité utilisateur supprimées');
    } catch (e) {
      print('❌ Erreur lors de la suppression des données d\'activité utilisateur: $e');
    }
  }

  /// Vérifie si l'utilisateur doit être considéré comme actif
  static Future<bool> shouldUpdateActivity(String userId) async {
    try {
      final lastActive = await getLastActiveTime();
      if (lastActive == null) return true;
      
      // Mettre à jour si la dernière activité date de plus de 4 minutes
      final difference = DateTime.now().difference(lastActive);
      return difference.inMinutes >= 4;
    } catch (e) {
      print('❌ Erreur lors de la vérification de la nécessité de mise à jour: $e');
      return true; // En cas d'erreur, on met à jour par précaution
    }
  }
}
