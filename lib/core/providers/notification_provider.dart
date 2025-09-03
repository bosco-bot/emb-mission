import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

// Modèle simple pour les notifications
class NotificationItem {
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool isRead; // Ajouter la propriété isRead

  NotificationItem({
    required this.title,
    required this.body,
    required this.receivedAt,
    this.isRead = false, // Par défaut non lue
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
    'isRead': isRead, // Sauvegarder l'état de lecture
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false, // Charger l'état de lecture
    );
  }

  // Créer une copie avec un état de lecture différent
  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      title: title,
      body: body,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

// Provider simple pour les notifications
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>((ref) {
  return NotificationsNotifier();
});

// Provider pour le compteur de notifications non lues
final unreadCountProvider = StateNotifierProvider<UnreadCountNotifier, int>((ref) {
  return UnreadCountNotifier();
});

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier() : super([]) {
    _loadNotifications();
    _startAutoCleanupTimer();
  }

  // Timer pour le nettoyage automatique
  Timer? _cleanupTimer;
  
  // Configuration du nettoyage automatique
  static const Duration _cleanupInterval = Duration(hours: 1); // Vérifier toutes les heures
  static const Duration _notificationLifetime = Duration(hours: 12); // Durée de vie des notifications

  // Démarrer le timer de nettoyage automatique
  void _startAutoCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _cleanupExpiredNotifications();
    });
    print('[NOTIFICATIONS] 🧹 Timer de nettoyage automatique démarré - Vérification toutes les $_cleanupInterval');
  }

  // Nettoyer automatiquement les notifications expirées (après 12h)
  void _cleanupExpiredNotifications() {
    try {
      final now = DateTime.now();
      final initialCount = state.length;
      
      // Filtrer les notifications non expirées
      final validNotifications = state.where((notification) {
        final age = now.difference(notification.receivedAt);
        final isExpired = age > _notificationLifetime;
        
        if (isExpired) {
          print('[NOTIFICATIONS] 🗑️ Notification expirée supprimée: "${notification.title}" (âge: ${age.inHours}h ${age.inMinutes % 60}m)');
        }
        
        return !isExpired; // Garder seulement les notifications non expirées
      }).toList();
      
      final removedCount = initialCount - validNotifications.length;
      
      if (removedCount > 0) {
        state = validNotifications;
        _saveNotifications();
        _updateUnreadCount();
        
        print('[NOTIFICATIONS] 🧹 Nettoyage automatique terminé: $removedCount notification(s) supprimée(s) après 12h');
        print('[NOTIFICATIONS] 📊 Notifications restantes: ${state.length}');
      }
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Erreur lors du nettoyage automatique: $e');
    }
  }

  // Méthode publique pour forcer le nettoyage (utile pour les tests)
  void forceCleanupExpiredNotifications() {
    print('[NOTIFICATIONS] 🧹 Nettoyage forcé des notifications expirées');
    _cleanupExpiredNotifications();
  }

  // Ajouter une notification
  void addNotification(String title, String body) {
    print('🔍 DEBUG: NotificationsNotifier.addNotification appelé avec: $title');
    print('🔍 DEBUG: État actuel: ${state.length} notifications');
    
    final newNotification = NotificationItem(
      title: title,
      body: body,
      receivedAt: DateTime.now(),
      isRead: false, // Nouvelle notification non lue
    );
    
    final updatedList = [newNotification, ...state];
    state = updatedList;
    print('🔍 DEBUG: Nouvel état: ${state.length} notifications');
    print('🔍 DEBUG: Première notification: ${state.first.title}');
    
    _saveNotifications();
    
    // Mettre à jour le compteur de notifications non lues
    _updateUnreadCount();
  }

  // Marquer une notification comme lue
  void markAsRead(int index) {
    if (index >= 0 && index < state.length) {
      final notification = state[index];
      if (!notification.isRead) {
        final updatedList = List<NotificationItem>.from(state);
        updatedList[index] = notification.copyWith(isRead: true);
        state = updatedList;
        _saveNotifications();
        
        // Mettre à jour le compteur de notifications non lues
        _updateUnreadCount();
      }
    }
  }

  // Supprimer une notification
  void removeNotification(int index) {
    if (index >= 0 && index < state.length) {
      final notification = state[index];
      print('[NOTIFICATIONS] 🗑️ Suppression manuelle: "${notification.title}"');
      
      final updatedList = List<NotificationItem>.from(state);
      updatedList.removeAt(index);
      state = updatedList;
      _saveNotifications();
      
      // Mettre à jour le compteur de notifications non lues
      _updateUnreadCount();
    }
  }

  // Marquer toutes les notifications comme lues
  void markAllAsRead() {
    if (state.isNotEmpty) {
      final updatedList = state.map((notification) => notification.copyWith(isRead: true)).toList();
      state = updatedList;
      _saveNotifications();
      _updateUnreadCount();
      print('[NOTIFICATIONS] ✅ Toutes les notifications marquées comme lues');
    }
  }

  // Charger les notifications depuis SharedPreferences
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('notifications') ?? [];
      
      final notifications = notificationsJson
          .map((json) {
            try {
              return NotificationItem.fromJson(jsonDecode(json));
            } catch (e) {
              print('❌ Erreur parsing notification: $e');
              return null;
            }
          })
          .where((notification) => notification != null)
          .cast<NotificationItem>()
          .toList();
      
      // Filtrer les notifications expirées au chargement
      final now = DateTime.now();
      final validNotifications = notifications.where((notification) {
        final age = now.difference(notification.receivedAt);
        final isExpired = age > _notificationLifetime;
        
        if (isExpired) {
          print('[NOTIFICATIONS] 🗑️ Notification expirée supprimée au chargement: "${notification.title}" (âge: ${age.inHours}h ${age.inMinutes % 60}m)');
        }
        
        return !isExpired;
      }).toList();
      
      final removedCount = notifications.length - validNotifications.length;
      if (removedCount > 0) {
        print('[NOTIFICATIONS] 🧹 Nettoyage au chargement: $removedCount notification(s) expirée(s) supprimée(s)');
      }
      
      state = validNotifications;
      print('🔍 DEBUG: ${state.length} notifications chargées depuis SharedPreferences');
      
      // Mettre à jour le compteur après le chargement
      _updateUnreadCount();
    } catch (e) {
      print('❌ Erreur chargement notifications: $e');
      state = [];
    }
  }

  // Sauvegarder les notifications dans SharedPreferences
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = state
          .map((notification) => jsonEncode(notification.toJson()))
          .toList();
      await prefs.setStringList('notifications', notificationsJson);
      
      print('🔍 DEBUG: ${state.length} notifications sauvegardées dans SharedPreferences');
    } catch (e) {
      print('❌ Erreur sauvegarde notifications: $e');
    }
  }

  // Mettre à jour le compteur de notifications non lues
  void _updateUnreadCount() {
    try {
      final unreadCount = state.where((notification) => !notification.isRead).length;
      print('🔍 DEBUG: Mise à jour compteur - notifications non lues: $unreadCount');
      
      // Accéder au provider de compteur via une fonction globale
      // Cette méthode sera appelée depuis NotificationService
      if (_readFunction != null) {
        final countNotifier = _readFunction!(unreadCountProvider.notifier);
        countNotifier.setCount(unreadCount);
      }
    } catch (e) {
      print('❌ Erreur mise à jour compteur: $e');
    }
  }

  // Reset du compteur
  void _resetUnreadCount() {
    try {
      if (_readFunction != null) {
        final countNotifier = _readFunction!(unreadCountProvider.notifier);
        countNotifier.reset();
      }
    } catch (e) {
      print('❌ Erreur reset compteur: $e');
    }
  }

  // Variable statique pour accéder à la fonction de lecture
  static Function? _readFunction;
  
  // Méthode pour définir la fonction de lecture
  static void setReadFunction(Function readFunction) {
    _readFunction = readFunction;
  }

  // Nettoyer les ressources lors de la destruction
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    print('[NOTIFICATIONS] 🧹 Timer de nettoyage automatique arrêté');
    super.dispose();
  }
}

class UnreadCountNotifier extends StateNotifier<int> {
  UnreadCountNotifier() : super(0) {
    _loadCount();
  }

  void increment() {
    state = state + 1;
    _saveCount();
  }

  void decrement() {
    if (state > 0) {
      state = state - 1;
      _saveCount();
    }
  }

  void reset() {
    state = 0;
    _saveCount();
  }

  // Nouvelle méthode pour synchroniser le compteur
  void setCount(int count) {
    if (state != count) {
      print('🔍 DEBUG: Mise à jour compteur de $state à $count');
      state = count;
      _saveCount();
    }
  }

  Future<void> _loadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt('unread_count') ?? 0;
    } catch (e) {
      state = 0;
    }
  }

  Future<void> _saveCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_count', state);
    } catch (e) {
      print('Erreur sauvegarde compteur: $e');
    }
  }
} 