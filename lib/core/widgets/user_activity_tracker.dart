import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/user_activity_service.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/widgets/guest_activity_tracker.dart';
import 'dart:async';

/// Widget pour suivre l'activité des utilisateurs connectés
class UserActivityTracker extends ConsumerStatefulWidget {
  final Widget child;
  
  const UserActivityTracker({
    required this.child,
    super.key,
  });

  @override
  ConsumerState<UserActivityTracker> createState() => _UserActivityTrackerState();
}

class _UserActivityTrackerState extends ConsumerState<UserActivityTracker> 
    with WidgetsBindingObserver {
  Timer? _activityTimer;
  Timer? _statusTimer;
  bool _isTracking = false;
  String? _currentUserId;
  bool _isUserLoggedIn = false;

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
      // Vérifier si un utilisateur est connecté
      final userId = ref.read(userIdProvider);
      _isUserLoggedIn = userId != null;
      _currentUserId = userId;
      
      if (_isUserLoggedIn && _currentUserId != null) {
        // ✅ NOUVEAU: Vérifier si l'utilisateur était un invité et nettoyer
        await _handleGuestToUserTransition();
        
        // Première mise à jour immédiate
        await UserActivityService.updateUserLastActive(_currentUserId!);
        
        // Démarrer le timer de mise à jour (toutes les 5 minutes)
        _activityTimer = Timer.periodic(const Duration(minutes: 5), (_) {
          _updateUserActivity();
        });
        
        // Démarrer le timer de statut (toutes les 30 secondes)
        _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          _checkUserStatus();
        });
        
        setState(() {
          _isTracking = true;
        });
        
        print('🚀 Suivi d\'activité utilisateur initialisé pour: $_currentUserId');
      } else {
        print('ℹ️ Aucun utilisateur connecté, suivi d\'activité désactivé');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du suivi utilisateur: $e');
    }
  }

  /// Met à jour l'activité de l'utilisateur
  Future<void> _updateUserActivity() async {
    if (!mounted) return;
    
    try {
      // Vérifier si l'utilisateur est toujours connecté
      final currentUserId = ref.read(userIdProvider);
      if (currentUserId == null || currentUserId != _currentUserId) {
        print('ℹ️ Utilisateur déconnecté ou changé, arrêt du suivi');
        _stopTracking();
        return;
      }
      
      // Vérifier si une mise à jour est nécessaire
      if (await UserActivityService.shouldUpdateActivity(currentUserId)) {
        final success = await UserActivityService.updateUserLastActive(currentUserId);
        if (success) {
          print('✅ Activité utilisateur mise à jour: ${DateTime.now().toIso8601String()}');
        } else {
          print('⚠️ Échec de la mise à jour de l\'activité utilisateur');
        }
      } else {
        print('ℹ️ Mise à jour de l\'activité utilisateur non nécessaire');
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'activité utilisateur: $e');
    }
  }

  /// Vérifie le statut de l'utilisateur
  Future<void> _checkUserStatus() async {
    if (!mounted) return;
    
    try {
      final currentUserId = ref.read(userIdProvider);
      if (currentUserId == null || currentUserId != _currentUserId) {
        print('ℹ️ Utilisateur déconnecté ou changé, arrêt du suivi');
        _stopTracking();
        return;
      }
      
      final isActive = await UserActivityService.isUserActive();
      if (isActive) {
        print('🟢 Utilisateur actif: $_currentUserId');
      } else {
        print('🟡 Utilisateur inactif: $_currentUserId');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification du statut utilisateur: $e');
    }
  }

  /// Arrête le suivi d'activité
  void _stopTracking() {
    _activityTimer?.cancel();
    _statusTimer?.cancel();
    setState(() {
      _isTracking = false;
      _currentUserId = null;
      _isUserLoggedIn = false;
    });
    print('🛑 Suivi d\'activité utilisateur arrêté');
  }

  /// ✅ NOUVEAU: Gère la déconnexion et le nettoyage
  Future<void> handleUserLogout() async {
    try {
      print('🔓 Déconnexion utilisateur détectée');
      
      // Arrêter le suivi
      _stopTracking();
      
      // Nettoyer les données d'activité utilisateur
      await UserActivityService.clearUserActivityData();
      
      print('✅ Nettoyage post-déconnexion terminé');
      print('📊 L\'utilisateur peut redevenir invité si nécessaire');
    } catch (e) {
      print('❌ Erreur lors du nettoyage post-déconnexion: $e');
    }
  }

  /// Redémarre le suivi d'activité
  Future<void> _restartTracking() async {
    _stopTracking();
    await _initializeTracking();
  }

  /// ✅ NOUVEAU: Gère la transition invité → utilisateur connecté
  Future<void> _handleGuestToUserTransition() async {
    try {
      // Vérifier si l'utilisateur était un invité
      final wasGuest = await GuestService.wasGuest();
      
      if (wasGuest) {
        print('🔄 Transition détectée: Invité → Utilisateur connecté');
        print('🧹 Nettoyage des données invité pour: $_currentUserId');
        
        // Nettoyer complètement les données invité
        await GuestService.completeGuestCleanup();
        
        print('✅ Transition invité → utilisateur terminée avec succès');
        print('📊 L\'utilisateur n\'est plus compté parmi les invités');
      } else {
        print('ℹ️ Utilisateur connecté directement (pas d\'historique invité)');
      }
    } catch (e) {
      print('❌ Erreur lors de la gestion de la transition invité → utilisateur: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App reprise: vérifier la connexion et mettre à jour l'activité
        _handleAppResumed();
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

  /// Gère la reprise de l'application
  Future<void> _handleAppResumed() async {
    try {
      final currentUserId = ref.read(userIdProvider);
      
      // Si l'utilisateur vient de se connecter
      if (currentUserId != null && !_isUserLoggedIn) {
        print('🔐 Utilisateur connecté, démarrage du suivi d\'activité');
        await _restartTracking();
      }
      // Si l'utilisateur vient de se déconnecter
      else if (currentUserId == null && _isUserLoggedIn) {
        print('🔓 Utilisateur déconnecté, arrêt du suivi d\'activité');
        _stopTracking();
      }
      // Si l'utilisateur est toujours connecté, mettre à jour l'activité
      else if (currentUserId != null && _isUserLoggedIn) {
        await _updateUserActivity();
      }
    } catch (e) {
      print('❌ Erreur lors de la gestion de la reprise de l\'app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin pour ajouter le suivi d'activité utilisateur aux écrans
mixin UserActivityMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _userActivityTimer;

  /// Démarrer le suivi d'activité pour cet écran
  void startUserActivityTracking() {
    final userId = ref.read(userIdProvider);
    if (userId != null) {
      _userActivityTimer = Timer.periodic(const Duration(minutes: 2), (_) {
        UserActivityService.updateUserLastActive(userId);
      });
      print('🚀 Suivi d\'activité utilisateur démarré pour l\'écran: $userId');
    }
  }

  /// Arrêter le suivi d'activité pour cet écran
  void stopUserActivityTracking() {
    _userActivityTimer?.cancel();
    _userActivityTimer = null;
    print('🛑 Suivi d\'activité utilisateur arrêté pour l\'écran');
  }

  @override
  void dispose() {
    stopUserActivityTracking();
    super.dispose();
  }
}
