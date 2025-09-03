import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

/// Service pour gérer les invités anonymes
class GuestService {
  static const _guestIdKey = 'guest_id';
  static const _lastActiveKey = 'guest_last_active';
  static const _baseUrl = 'https://embmission.com/mobileappebm/api';

  /// Récupère ou génère un guestId unique pour l'invité
  static Future<String> getOrCreateGuestId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? guestId = prefs.getString(_guestIdKey);
      
      if (guestId == null || guestId.isEmpty) {
        // Générer un nouvel ID unique
        guestId = _generateUniqueId();
        await prefs.setString(_guestIdKey, guestId);
        print('🆔 Nouvel ID invité généré: $guestId');
      }
      
      return guestId;
    } catch (e) {
      print('❌ Erreur lors de la récupération/création de l\'ID invité: $e');
      // Fallback: générer un ID temporaire
      return _generateUniqueId();
    }
  }

  /// Génère un ID unique basé sur le timestamp et un nombre aléatoire
  static String _generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'guest_${timestamp}_$random';
  }

  /// Met à jour le last_active de l'invité côté backend
  static Future<bool> updateGuestLastActive() async {
    try {
      final guestId = await getOrCreateGuestId();
      final url = Uri.parse('$_baseUrl/update_guest_last_active?guestId=$guestId');
      
      print('🔄 Mise à jour de l\'activité invité: $guestId');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la mise à jour de l\'activité invité');
        },
      );
      
      if (response.statusCode == 200) {
        // Sauvegarder le timestamp de la dernière mise à jour
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastActiveKey, DateTime.now().toIso8601String());
        
        print('✅ Activité invité mise à jour avec succès');
        return true;
      } else {
        print('⚠️ Erreur serveur lors de la mise à jour de l\'activité invité: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'activité invité: $e');
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
      print('❌ Erreur lors de la récupération du timestamp d\'activité: $e');
      return null;
    }
  }

  /// Vérifie si l'invité est actif (dernière activité < 1 heure)
  static Future<bool> isGuestActive() async {
    try {
      final lastActive = await getLastActiveTime();
      if (lastActive == null) return false;
      
      final difference = DateTime.now().difference(lastActive);
      return difference.inHours < 1;
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'activité invité: $e');
      return false;
    }
  }

  /// Nettoie les données invité (pour la déconnexion ou transition vers utilisateur connecté)
  static Future<void> clearGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestIdKey);
      await prefs.remove(_lastActiveKey);
      print('🧹 Données invité supprimées');
    } catch (e) {
      print('❌ Erreur lors de la suppression des données invité: $e');
    }
  }

  /// Vérifie si l'utilisateur était un invité avant la connexion
  static Future<bool> wasGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guestId = prefs.getString(_guestIdKey);
      return guestId != null && guestId.isNotEmpty;
    } catch (e) {
      print('❌ Erreur lors de la vérification du statut invité: $e');
      return false;
    }
  }

  /// Nettoie complètement les données invité et arrête le suivi
  static Future<void> completeGuestCleanup() async {
    try {
      await clearGuestData();
      print('✅ Nettoyage complet des données invité terminé');
    } catch (e) {
      print('❌ Erreur lors du nettoyage complet des données invité: $e');
    }
  }
}

/// Widget pour suivre l'activité des invités
class GuestActivityTracker extends StatefulWidget {
  final Widget child;
  
  const GuestActivityTracker({
    required this.child,
    super.key,
  });

  @override
  State<GuestActivityTracker> createState() => _GuestActivityTrackerState();
}

class _GuestActivityTrackerState extends State<GuestActivityTracker> 
    with WidgetsBindingObserver {
  Timer? _activityTimer;
  Timer? _statusTimer;
  bool _isTracking = false;
  String? _currentGuestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activityTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  /// Initialise le suivi d'activité
  Future<void> _initializeTracking() async {
    try {
      // Récupérer l'ID invité
      _currentGuestId = await GuestService.getOrCreateGuestId();
      
      // Première mise à jour immédiate
      await GuestService.updateGuestLastActive();
      
      // Démarrer le timer de mise à jour (toutes les 5 minutes)
      _activityTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _updateGuestActivity();
      });
      
      // Démarrer le timer de statut (toutes les 30 secondes)
      _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _checkGuestStatus();
      });
      
      setState(() {
        _isTracking = true;
      });
      
      print('🚀 Suivi d\'activité invité initialisé pour: $_currentGuestId');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du suivi invité: $e');
    }
  }

  /// Met à jour l'activité de l'invité
  Future<void> _updateGuestActivity() async {
    if (!mounted) return;
    
    try {
      final success = await GuestService.updateGuestLastActive();
      if (success) {
        print('✅ Activité invité mise à jour: ${DateTime.now().toIso8601String()}');
      } else {
        print('⚠️ Échec de la mise à jour de l\'activité invité');
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'activité invité: $e');
    }
  }

  /// Vérifie le statut de l'invité
  Future<void> _checkGuestStatus() async {
    if (!mounted) return;
    
    try {
      final isActive = await GuestService.isGuestActive();
      if (isActive) {
        print('🟢 Invité actif: $_currentGuestId');
      } else {
        print('🟡 Invité inactif: $_currentGuestId');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification du statut invité: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App reprise: mettre à jour l'activité
        _updateGuestActivity();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App en pause: pas de mise à jour automatique
        break;
      case AppLifecycleState.hidden:
        // Nouveau dans Flutter 3.16+
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin pour ajouter le suivi d'activité invité aux écrans
mixin GuestActivityMixin<T extends StatefulWidget> on State<T> {
  Timer? _guestActivityTimer;

  /// Démarrer le suivi d'activité pour cet écran
  void startGuestActivityTracking() {
    _guestActivityTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      GuestService.updateGuestLastActive();
    });
  }

  /// Arrêter le suivi d'activité pour cet écran
  void stopGuestActivityTracking() {
    _guestActivityTimer?.cancel();
    _guestActivityTimer = null;
  }

  @override
  void dispose() {
    stopGuestActivityTracking();
    super.dispose();
  }
}
