import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

/// Service pour la récupération proactive des données utilisateur
class ProactiveDataRecoveryService {
  static const _baseUrl = 'https://embmission.com/mobileappebm/api';
  static const _lastRecoveryKey = 'last_proactive_recovery';
  static const _recoveryInterval = Duration(minutes: 30); // Récupération toutes les 30 minutes max

  /// Vérifie si une récupération proactive est nécessaire
  static Future<bool> shouldPerformRecovery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRecovery = prefs.getString(_lastRecoveryKey);
      
      if (lastRecovery == null) return true;
      
      final lastRecoveryTime = DateTime.parse(lastRecovery);
      final difference = DateTime.now().difference(lastRecoveryTime);
      
      // Récupération si plus de 30 minutes se sont écoulées
      return difference >= _recoveryInterval;
    } catch (e) {
      print('❌ Erreur lors de la vérification de la nécessité de récupération: $e');
      return true; // En cas d'erreur, on récupère par précaution
    }
  }

  /// Récupère proactivement les données utilisateur depuis l'API
  static Future<bool> performProactiveRecovery(String userId) async {
    try {
      print('🔄 Récupération proactive des données utilisateur pour: $userId');
      
      // Vérifier si une récupération est nécessaire
      if (!await shouldPerformRecovery()) {
        print('ℹ️ Récupération proactive non nécessaire (trop récente)');
        return true;
      }

      // Récupérer le profil utilisateur depuis l'API
      final url = Uri.parse('$_baseUrl/user_profile?user_id=$userId');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la récupération proactive');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == 'true' && data['data'] != null) {
          final userData = data['data'];
          
          // Extraire et sauvegarder les données
          final avatar = userData['user_avatar'];
          final name = userData['user_name'];
          
          if (avatar != null && avatar.isNotEmpty) {
            await _saveUserAvatar(avatar);
            print('✅ Avatar utilisateur récupéré et sauvegardé: ${avatar.substring(0, 20)}...');
          }
          
          if (name != null && name.isNotEmpty) {
            await _saveUserName(name);
            print('✅ Nom utilisateur récupéré et sauvegardé: $name');
          }
          
          // Marquer la récupération comme effectuée
          await _markRecoveryCompleted();
          
          print('✅ Récupération proactive terminée avec succès');
          return true;
        } else {
          print('⚠️ Réponse API indique un échec: ${data['success']}');
          return false;
        }
      } else {
        print('⚠️ Erreur serveur lors de la récupération proactive: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération proactive: $e');
      return false;
    }
  }

  /// Sauvegarde l'avatar utilisateur
  static Future<void> _saveUserAvatar(String avatarUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', avatarUrl);
      print('💾 Avatar sauvegardé localement');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde de l\'avatar: $e');
    }
  }

  /// Sauvegarde le nom utilisateur
  static Future<void> _saveUserName(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', userName);
      print('💾 Nom utilisateur sauvegardé localement');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du nom: $e');
    }
  }

  /// Marque la récupération comme terminée
  static Future<void> _markRecoveryCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRecoveryKey, DateTime.now().toIso8601String());
      print('⏰ Timestamp de récupération mis à jour');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du timestamp: $e');
    }
  }

  /// Force une récupération proactive (ignorant l'intervalle)
  static Future<bool> forceProactiveRecovery(String userId) async {
    try {
      print('🔄 Récupération proactive forcée pour: $userId');
      
      // Récupérer le profil utilisateur depuis l'API
      final url = Uri.parse('$_baseUrl/user_profile?user_id=$userId');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la récupération proactive forcée');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == 'true' && data['data'] != null) {
          final userData = data['data'];
          
          // Extraire et sauvegarder les données
          final avatar = userData['user_avatar'];
          final name = userData['user_name'];
          
          if (avatar != null && avatar.isNotEmpty) {
            await _saveUserAvatar(avatar);
            print('✅ Avatar utilisateur récupéré et sauvegardé (forcé)');
          }
          
          if (name != null && name.isNotEmpty) {
            await _saveUserName(name);
            print('✅ Nom utilisateur récupéré et sauvegardé (forcé)');
          }
          
          // Marquer la récupération comme effectuée
          await _markRecoveryCompleted();
          
          print('✅ Récupération proactive forcée terminée avec succès');
          return true;
        } else {
          print('⚠️ Réponse API indique un échec: ${data['success']}');
          return false;
        }
      } else {
        print('⚠️ Erreur serveur lors de la récupération proactive forcée: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération proactive forcée: $e');
      return false;
    }
  }

  /// Nettoie les données de récupération (pour la déconnexion)
  static Future<void> clearRecoveryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRecoveryKey);
      print('🧹 Données de récupération proactive supprimées');
    } catch (e) {
      print('❌ Erreur lors de la suppression des données de récupération: $e');
    }
  }

  /// Récupère le timestamp de la dernière récupération
  static Future<DateTime?> getLastRecoveryTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRecovery = prefs.getString(_lastRecoveryKey);
      if (lastRecovery != null) {
        return DateTime.parse(lastRecovery);
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du timestamp: $e');
      return null;
    }
  }
}
