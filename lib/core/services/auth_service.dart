import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emb_mission/main.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:emb_mission/core/services/monitoring_service.dart';

final userIdProvider = StateProvider<String?>((ref) => null);
final userAvatarProvider = StateProvider<String?>((ref) => null);
final userNameProvider = StateProvider<String?>((ref) => null);

// Provider pour initialiser l'état d'authentification au démarrage
final authInitializerProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final savedUserId = prefs.getString('user_id');
  
  if (savedUserId != null && savedUserId.isNotEmpty) {
    // ✅ CORRECTION: Charger TOUTES les données utilisateur
    ref.read(userIdProvider.notifier).state = savedUserId;
    
    // ✅ NOUVEAU: Charger l'avatar depuis le stockage local
    final savedAvatar = prefs.getString('user_avatar');
    if (savedAvatar != null && savedAvatar.isNotEmpty) {
      ref.read(userAvatarProvider.notifier).state = savedAvatar;
      print('✅ Avatar chargé depuis le stockage local');
    }
    
    // ✅ NOUVEAU: Charger le nom depuis le stockage local
    final savedName = prefs.getString('user_name');
    if (savedName != null && savedName.isNotEmpty) {
      ref.read(userNameProvider.notifier).state = savedName;
      print('✅ Nom d\'utilisateur chargé depuis le stockage local');
    }
    
    print('✅ État d\'authentification complet initialisé avec userId: $savedUserId');
  }
});

// ✅ NOUVEAU: Provider pour la récupération automatique des données
final userDataRecoveryProvider = FutureProvider<void>((ref) async {
  final userId = ref.read(userIdProvider);
  if (userId != null && userId.isNotEmpty) {
    print('🔄 Déclenchement de la récupération automatique des données...');
    
    // Vérifier si l'avatar est manquant
    final currentAvatar = ref.read(userAvatarProvider);
    if (currentAvatar == null || currentAvatar.isEmpty) {
      print('🔄 Avatar manquant, tentative de récupération...');
      final recoveredAvatar = await AuthService.recoverUserAvatar(userId);
      if (recoveredAvatar != null) {
        ref.read(userAvatarProvider.notifier).state = recoveredAvatar;
        print('✅ Avatar récupéré et mis à jour dans le provider');
      }
    }
    
    // Vérifier si le nom est manquant
    final currentName = ref.read(userNameProvider);
    if (currentName == null || currentName.isEmpty) {
      print('🔄 Nom manquant, tentative de récupération...');
      final recoveredName = await AuthService.recoverUserName(userId);
      if (recoveredName != null) {
        ref.read(userNameProvider.notifier).state = recoveredName;
        print('✅ Nom d\'utilisateur récupéré et mis à jour dans le provider');
      }
    }
    
    print('✅ Récupération automatique terminée');
  }
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream pour écouter les changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription avec email et mot de passe
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'Le mot de passe fourni est trop faible.';
          break;
        case 'email-already-in-use':
          message = 'Un compte existe déjà avec cette adresse email.';
          break;
        case 'invalid-email':
          message = 'L\'adresse email fournie n\'est pas valide.';
          break;
        case 'operation-not-allowed':
          message = 'L\'inscription par email/mot de passe n\'est pas activée.';
          break;
        default:
          message = 'Une erreur s\'est produite lors de l\'inscription: ${e.message}';
      }
      throw AuthException(message);
    } catch (e) {
      throw AuthException('Une erreur inattendue s\'est produite: $e');
    }
  }

  // Connexion avec email et mot de passe
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // ✅ NOUVEAU: Monitoring de connexion
      final userId = userCredential.user?.uid;
      if (userId != null) {
        await MonitoringService.logUserAction('user_login', {
          'method': 'email_password',
          'user_id': userId,
        });
      }
      
      // Synchronisation locale → backend après connexion
      if (userId != null && userId.isNotEmpty) {
        await syncLocalDataToBackend(userId);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // ✅ NOUVEAU: Monitoring des erreurs d'auth
      await MonitoringService.logError(e, StackTrace.current, fatal: false);
      
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Aucun utilisateur trouvé avec cette adresse email.';
          break;
        case 'wrong-password':
          message = 'Mot de passe incorrect.';
          break;
        case 'invalid-email':
          message = 'L\'adresse email fournie n\'est pas valide.';
          break;
        case 'user-disabled':
          message = 'Ce compte utilisateur a été désactivé.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives de connexion. Veuillez réessayer plus tard.';
          break;
        default:
          message = 'Une erreur s\'est produite lors de la connexion: ${e.message}';
      }
      throw AuthException(message);
    } catch (e) {
      // ✅ NOUVEAU: Monitoring des erreurs générales
      await MonitoringService.logError(e, StackTrace.current, fatal: false);
      throw AuthException('Une erreur inattendue s\'est produite: $e');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Erreur lors de la déconnexion: $e');
    }
  }

  // Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Aucun utilisateur trouvé avec cette adresse email.';
          break;
        case 'invalid-email':
          message = 'L\'adresse email fournie n\'est pas valide.';
          break;
        default:
          message = 'Une erreur inattendue s\'est produite: ${e.message}';
      }
      throw AuthException(message);
    } catch (e) {
      throw AuthException('Une erreur inattendue s\'est produite: $e');
    }
  }

  // ✅ NOUVEAU: Méthode pour sauvegarder l'avatar de l'utilisateur
  static Future<void> saveUserAvatar(String avatarUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', avatarUrl);
      print('✅ Avatar sauvegardé localement: $avatarUrl');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde de l\'avatar: $e');
    }
  }

  // ✅ NOUVEAU: Méthode pour sauvegarder le nom de l'utilisateur
  static Future<void> saveUserName(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', userName);
      print('✅ Nom d\'utilisateur sauvegardé localement: $userName');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du nom: $e');
    }
  }

  // ✅ NOUVEAU: Méthode pour récupérer l'avatar depuis l'API
  static Future<String?> recoverUserAvatar(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/user_profile?user_id=$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // ✅ CORRECTION: Utiliser la bonne structure de l'API
        if (data['success'] == "true" && data['data'] != null) {
          final avatarUrl = data['data']['user_avatar'];
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            // Sauvegarder automatiquement l'avatar récupéré
            await saveUserAvatar(avatarUrl);
            return avatarUrl;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'avatar: $e');
      return null;
    }
  }

  // ✅ NOUVEAU: Méthode pour récupérer le nom depuis l'API
  static Future<String?> recoverUserName(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/user_profile?user_id=$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // ✅ CORRECTION: Utiliser la bonne structure de l'API
        if (data['success'] == "true" && data['data'] != null) {
          final userName = data['data']['user_name'];
          if (userName != null && userName.isNotEmpty) {
            // Sauvegarder automatiquement le nom récupéré
            await saveUserName(userName);
            return userName;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du nom: $e');
      return null;
    }
  }

  // ✅ NOUVELLE MÉTHODE: Récupération automatique des données manquantes
  static Future<void> autoRecoverUserData(String userId) async {
    try {
      print('🔄 Récupération automatique des données utilisateur...');
      
      // Vérifier si l'avatar est manquant
      final currentAvatar = await SharedPreferences.getInstance().then((prefs) => prefs.getString('user_avatar'));
      if (currentAvatar == null || currentAvatar.isEmpty) {
        print('🔄 Avatar manquant, tentative de récupération...');
        final recoveredAvatar = await recoverUserAvatar(userId);
        if (recoveredAvatar != null) {
          // Mettre à jour le provider
          // Note: Cette méthode sera appelée depuis l'extérieur
          print('✅ Avatar récupéré et mis à jour');
        }
      }
      
      // Vérifier si le nom est manquant
      final currentName = await SharedPreferences.getInstance().then((prefs) => prefs.getString('user_name'));
      if (currentName == null || currentName.isEmpty) {
        print('🔄 Nom manquant, tentative de récupération...');
        final recoveredName = await recoverUserName(userId);
        if (recoveredName != null) {
          // Mettre à jour le provider
          // Note: Cette méthode sera appelée depuis l'extérieur
          print('✅ Nom d\'utilisateur récupéré et mis à jour');
        }
      }
      
      print('✅ Récupération automatique terminée');
    } catch (e) {
      print('❌ Erreur lors de la récupération automatique: $e');
    }
  }

  // Envoyer un email de vérification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw AuthException('Erreur lors de l\'envoi de l\'email de vérification: $e');
    }
  }
}

// Exception personnalisée pour les erreurs d'authentification
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
} 