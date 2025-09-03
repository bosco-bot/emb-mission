import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/providers/notification_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static Function? _readFunction;
  static Set<String> _processedNotifications = {}; // Pour éviter les doublons
  static bool _openNotificationsSheetPending = false; // Ouvrir sheet à l'ouverture depuis la barre système

  /// Initialise le service de notifications
  static Future<void> initialize(Function readFunction) async {
    try {
      _readFunction = readFunction;
      
      // Configurer la fonction de lecture dans NotificationsNotifier
      NotificationsNotifier.setReadFunction(readFunction);
      
      print('✅ NotificationService initialisé');
      
      // Traiter les notifications en attente (reçues en arrière-plan)
      await _processPendingNotifications();
      
      // Vérifier s'il y a une notification initiale (app ouverte depuis notification)
      await _checkInitialMessage();
      
      // Demander les permissions de manière conditionnelle
      _requestPermissionsWhenReady();
      
      // Configurer les handlers
      _setupMessageHandlers();
      
      // Configurer les canaux de notification
      await _setupNotificationChannels();
      
      print('✅ Service de notifications configuré avec succès');
    } catch (e) {
      print('❌ Erreur initialisation NotificationService: $e');
    }
  }

  /// Traite les notifications reçues en arrière-plan (méthode privée)
  static Future<void> _processPendingNotifications() async {
    try {
      // Lire les notifications depuis le fichier (plus fiable que SharedPreferences)
      final appDir = await getApplicationDocumentsDirectory();
      final notificationsFile = File('${appDir.path}/pending_notifications.json');
      
      if (await notificationsFile.exists()) {
        try {
          final content = await notificationsFile.readAsString();
          final List<dynamic> jsonList = jsonDecode(content);
          final notifications = jsonList.cast<Map<String, dynamic>>();
          
          if (notifications.isNotEmpty) {
            print('🔍 DEBUG: Traitement de ${notifications.length} notifications depuis le fichier');
            
            for (final notificationData in notifications) {
              try {
                final title = notificationData['title'] as String?;
                final body = notificationData['body'] as String?;
                
                if (title != null && body != null) {
                  print('🔍 DEBUG: Traitement notification depuis fichier: $title');
                  // Utiliser la méthode centralisée
                  await _handleNotification(title, body);
                }
              } catch (e) {
                print('❌ Erreur traitement notification depuis fichier: $e');
              }
            }
            
            // Supprimer le fichier après traitement
            await notificationsFile.delete();
            print('🔍 DEBUG: Fichier de notifications supprimé après traitement');
            print('✅ Notifications depuis fichier traitées et supprimées');
          } else {
            print('🔍 DEBUG: Fichier de notifications vide');
          }
        } catch (e) {
          print('❌ Erreur lecture fichier de notifications: $e');
          // En cas d'erreur, supprimer le fichier corrompu
          if (await notificationsFile.exists()) {
            await notificationsFile.delete();
            print('🔍 DEBUG: Fichier corrompu supprimé');
          }
        }
      } else {
        print('🔍 DEBUG: Aucun fichier de notifications trouvé');
      }
      
      // Nettoyer aussi les anciennes clés SharedPreferences si elles existent encore
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // Nettoyer d'abord les anciennes clés 'pending_notifications' si elles existent
      final oldPendingKeys = allKeys.where((key) => key == 'pending_notifications').toList();
      if (oldPendingKeys.isNotEmpty) {
        print('🔍 DEBUG: Nettoyage des anciennes clés: $oldPendingKeys');
        for (final key in oldPendingKeys) {
          await prefs.remove(key);
          print('🔍 DEBUG: Ancienne clé supprimée: $key');
        }
      }
      
      // Nettoyer aussi toutes les clés qui commencent par 'pending_notification_' (ancien format)
      final oldPendingNotificationKeys = allKeys.where((key) => key.startsWith('pending_notification_')).toList();
      if (oldPendingNotificationKeys.isNotEmpty) {
        print('🔍 DEBUG: Nettoyage des anciennes clés pending_notification_: $oldPendingNotificationKeys');
        for (final key in oldPendingNotificationKeys) {
          await prefs.remove(key);
          print('🔍 DEBUG: Ancienne clé pending_notification_ supprimée: $key');
        }
      }
      
      // Nettoyer aussi toutes les clés qui commencent par 'bg_notif_' (ancien format)
      final oldBgNotifKeys = allKeys.where((key) => key.startsWith('bg_notif_')).toList();
      if (oldBgNotifKeys.isNotEmpty) {
        print('🔍 DEBUG: Nettoyage des anciennes clés bg_notif_: $oldBgNotifKeys');
        for (final key in oldBgNotifKeys) {
          await prefs.remove(key);
          print('🔍 DEBUG: Ancienne clé bg_notif_ supprimée: $key');
        }
      }
      
    } catch (e) {
      print('❌ Erreur traitement notifications en attente: $e');
    }
  }

  /// Traite les notifications en attente (méthode publique pour HomeScreen)
  static Future<void> processPendingNotifications() async {
    await _processPendingNotifications();
  }

  /// Demande les permissions de notifications
  static Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      print('🔔 Permissions notifications: ${settings.authorizationStatus}');
    } catch (e) {
      print('❌ Erreur permissions: $e');
    }
  }

  /// Demande les permissions quand l'activité est prête
  static void _requestPermissionsWhenReady() {
    // Essayer plusieurs fois avec des délais croissants
    _tryRequestPermissions(attempt: 1);
  }

  /// Essaie de demander les permissions avec retry
  static void _tryRequestPermissions({required int attempt}) {
    if (attempt > 5) {
      print('⚠️ Impossible de demander les permissions après 5 tentatives');
      return;
    }

    // Délai croissant : 500ms, 1s, 2s, 4s, 8s
    final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
    
    Future.delayed(delay, () async {
      try {
        await _requestPermissions();
        print('✅ Permissions demandées avec succès à la tentative $attempt');
      } catch (e) {
        print('⚠️ Tentative $attempt échouée: $e');
        // Réessayer avec un délai plus long
        _tryRequestPermissions(attempt: attempt + 1);
      }
    });
  }

  /// Configure les canaux de notification
  static Future<void> _setupNotificationChannels() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Notifications importantes',
        description: 'Canal pour les notifications importantes',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      
      print('✅ Canaux de notification configurés');
    } catch (e) {
      print('❌ Erreur configuration canaux: $e');
    }
  }

  /// Marque l'ouverture automatique du BottomSheet notifications à la prochaine frame
  static void markOpenNotificationsSheetPending() {
    _openNotificationsSheetPending = true;
  }

  /// Consomme le flag d'ouverture automatique (retourne true une seule fois)
  static bool consumeOpenNotificationsSheetPending() {
    if (_openNotificationsSheetPending) {
      _openNotificationsSheetPending = false;
      return true;
    }
    return false;
  }

  /// Ajoute une notification au provider
  static void addNotificationToProvider(String title, String body) {
    print('🔍 DEBUG: Tentative d\'ajout de notification: $title');
    print('🔍 DEBUG: _readFunction est null? ${_readFunction == null}');
    
    if (_readFunction != null) {
      try {
        // Vérifier si la notification existe déjà
        final notifications = _readFunction!(notificationsProvider);
        final exists = notifications.any((n) => 
          n.title == title && 
          n.body == body && 
          DateTime.now().difference(n.receivedAt).inMinutes < 5
        );
        
        if (exists) {
          print('⚠️ Notification similaire déjà présente, ignorée: $title');
          return;
        }
        
        // Accéder au provider de notifications
        final notifier = _readFunction!(notificationsProvider.notifier);
        print('🔍 DEBUG: Notifier récupéré: ${notifier.runtimeType}');
        
        notifier.addNotification(title, body);
        print('🔍 DEBUG: Notification ajoutée au notifier');
        
        // Le compteur sera automatiquement mis à jour par NotificationsNotifier
        print('✅ Notification ajoutée: $title');
      } catch (e) {
        print('❌ Erreur ajout notification: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
    } else {
      print('❌ _readFunction est null');
    }
  }

  /// Méthode pour simuler l'ajout d'une notification (pour test)
  static void addTestNotification(String title, String body) {
    addNotificationToProvider(title, body);
  }

  /// Réinitialise le badge
  static void resetBadge() {
    if (_readFunction != null) {
      try {
        final countNotifier = _readFunction!(unreadCountProvider.notifier);
        countNotifier.reset();
      } catch (e) {
        print('❌ Erreur reset badge: $e');
      }
    }
  }

  /// Configure les handlers pour les messages
  static void _setupMessageHandlers() {
    // Message reçu quand l'app est en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Message reçu en premier plan: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Message reçu quand l'app est en arrière-plan et ouverte
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📨 App ouverte depuis notification: ${message.notification?.title}');
      try {
        final notification = message.notification;
        if (notification != null) {
          // Utiliser la méthode centralisée
          _handleNotification(
            notification.title!,
            notification.body!,
            shouldOpenBottomSheet: true,
          );
        }
      } catch (e) {
        print('❌ Erreur traitement notification ouverte: $e');
      }
    });

    // Note: getInitialMessage() est maintenant géré dans initialize() via _checkInitialMessage()
    print('✅ Handlers de messages configurés');
  }

  /// Affiche une notification locale
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      // Vérifier si la notification a déjà été traitée (plus strict)
      final notificationId = '${notification.title}_${notification.body}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}'; // ID par minute
      if (_processedNotifications.contains(notificationId)) {
        print('⚠️ Notification déjà traitée dans cette minute, ignorée: ${notification.title}');
        return;
      }

      // Marquer comme traitée
      _processedNotifications.add(notificationId);
      
      // Nettoyer les anciennes entrées
      _cleanupProcessedNotifications();

      // Utiliser la méthode centralisée pour traiter la notification
      await _handleNotification(notification.title!, notification.body!);

      // Afficher la notification locale
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'Notifications importantes',
        channelDescription: 'Canal pour les notifications importantes',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformChannelSpecifics,
      );

      print('✅ Notification locale affichée: ${notification.title}');
    } catch (e) {
      print('❌ Erreur affichage notification locale: $e');
    }
  }

  /// Nettoie les notifications traitées (pour éviter l'accumulation en mémoire)
  static void _cleanupProcessedNotifications() {
    if (_processedNotifications.length > 50) { // Réduit de 100 à 50
      _processedNotifications.clear();
      print('🧹 Nettoyage des notifications traitées');
    }
  }

  /// Vérifie s'il y a une notification initiale (app ouverte depuis notification)
  static Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('📨 Notification initiale détectée: ${initialMessage.notification?.title}');
        await _handleNotification(
          initialMessage.notification?.title ?? '',
          initialMessage.notification?.body ?? '',
          shouldOpenBottomSheet: true,
        );
      }
    } catch (e) {
      print('❌ Erreur vérification message initial: $e');
    }
  }

  /// Méthode centralisée pour gérer toutes les notifications
  static Future<void> _handleNotification(String title, String body, {bool shouldOpenBottomSheet = false}) async {
    if (title.isEmpty || body.isEmpty) return;
    
    print('🔍 DEBUG: _handleNotification appelé avec: $title');
    
    try {
      // Ajouter la notification au provider
      addNotificationToProvider(title, body);
      
      // Déclencher un nettoyage automatique après l'ajout
      _triggerAutoCleanup();
      
      // Marquer pour ouvrir le bottom sheet si nécessaire
      if (shouldOpenBottomSheet) {
        markOpenNotificationsSheetPending();
        print('🔍 DEBUG: Bottom sheet marqué pour ouverture automatique');
      }
      
      print('✅ Notification traitée avec succès: $title');
    } catch (e) {
      print('❌ Erreur traitement notification: $e');
    }
  }

  /// Déclenche le nettoyage automatique des notifications expirées
  static void _triggerAutoCleanup() {
    try {
      if (_readFunction != null) {
        final notifier = _readFunction!(notificationsProvider.notifier);
        // Appeler la méthode de nettoyage forcé pour un nettoyage immédiat
        notifier.forceCleanupExpiredNotifications();
        print('[NOTIFICATIONS] 🧹 Nettoyage automatique déclenché après nouvelle notification');
      }
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Erreur lors du déclenchement du nettoyage: $e');
    }
  }
} 