import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:emb_mission/core/data/local_models.dart';

import 'package:emb_mission/core/router/app_router.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:emb_mission/core/services/preferences_service.dart';
import 'package:emb_mission/core/services/shared_preferences_provider.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/services/app_usage_service.dart';
import 'package:emb_mission/core/services/notification_service.dart';
import 'package:emb_mission/core/services/proactive_data_recovery_service.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:emb_mission/core/services/audio_service_handler.dart';
import 'package:emb_mission/core/widgets/app_exit_protection.dart';
import 'package:emb_mission/core/widgets/guest_activity_tracker.dart';
import 'package:emb_mission/core/widgets/user_activity_tracker.dart';
import 'package:emb_mission/core/services/monitoring_service.dart';
import 'package:emb_mission/core/services/background_maintenance_service.dart';
import 'package:emb_mission/core/services/notification_control_service.dart';
import 'package:emb_mission/core/services/radio_sync_monitor.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart' as radio_provider;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:emb_mission/core/config/app_config.dart';

// ✅ NOUVEAU: Configuration du monitoring Firebase
Future<void> _configureFirebaseMonitoring() async {
  try {
    AppConfig.log('Configuration du monitoring Firebase...', tag: 'FIREBASE');
    
    // 1. ✅ Activer Crashlytics (toujours utile)
    if (AppConfig.shouldEnableFirebaseCrashlytics) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      AppConfig.logSuccess('Firebase Crashlytics activé', tag: 'FIREBASE');
    }
    
    // 2. ✅ Analytics conditionnel selon l'environnement
    if (AppConfig.shouldEnableFirebaseAnalytics) {
      // ✅ PRODUCTION: Activer Analytics pour collecter de vraies données
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      AppConfig.logSuccess('Firebase Analytics activé (PRODUCTION)', tag: 'FIREBASE');
    } else {
      // ✅ DÉVELOPPEMENT: Désactiver Analytics pour éviter les crashes
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      AppConfig.logWarning('Firebase Analytics désactivé (DÉVELOPPEMENT)', tag: 'FIREBASE');
    }
    
    // 3. ✅ Configurer le handler d'erreurs Flutter
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    // 4. ✅ Configurer le handler d'erreurs non fatales
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
      return true;
    };
    
    AppConfig.logSuccess('Monitoring Firebase configuré avec succès', tag: 'FIREBASE');
    
  } catch (e) {
    AppConfig.logError('Erreur configuration monitoring Firebase', tag: 'FIREBASE', error: e);
    // Continuer sans monitoring
  }
}

// Configuration du handler de messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Message reçu en arrière-plan (main.dart): ${message.notification?.title}');
  
  // Sauvegarder la notification dans un fichier pour qu'elle soit traitée quand l'app s'ouvre
  try {
    // Utiliser le répertoire des documents de l'application (partagé entre processus)
    final appDir = await getApplicationDocumentsDirectory();
    final notificationsFile = File('${appDir.path}/pending_notifications.json');
    
    // Lire les notifications existantes
    List<Map<String, dynamic>> notifications = [];
    if (await notificationsFile.exists()) {
      try {
        final content = await notificationsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        notifications = jsonList.cast<Map<String, dynamic>>();
      } catch (e) {
        print('🔍 DEBUG: Erreur lecture fichier existant, création nouvelle liste');
        notifications = [];
      }
    }
    
    // Ajouter la nouvelle notification
    final notificationData = {
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    notifications.add(notificationData);
    
    // Sauvegarder dans le fichier
    await notificationsFile.writeAsString(jsonEncode(notifications));
    
    print('🔍 DEBUG: Notification sauvegardée dans fichier: ${appDir.path}/pending_notifications.json');
    print('🔍 DEBUG: Nombre total de notifications en attente: ${notifications.length}');
    print('✅ Notification en arrière-plan sauvegardée (main.dart): ${message.notification?.title}');
    
    // Vérifier que le fichier a bien été créé
    final fileExists = await notificationsFile.exists();
    print('🔍 DEBUG: Fichier créé avec succès: $fileExists');
    
  } catch (e) {
    print('❌ Erreur sauvegarde notification arrière-plan (main.dart): $e');
    print('❌ Stack trace: ${StackTrace.current}');
  }
}

/// Widget pour initialiser le service de notifications avec le ProviderContainer
class NotificationServiceInitializer extends ConsumerStatefulWidget {
  final Widget child;
  
  const NotificationServiceInitializer({required this.child, super.key});

  @override
  ConsumerState<NotificationServiceInitializer> createState() => _NotificationServiceInitializerState();
}

class _NotificationServiceInitializerState extends ConsumerState<NotificationServiceInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialiser le service de notifications avec la fonction read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.initialize(ref.read);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppLifecycleReactor extends StatefulWidget {
  final Widget child;
  const AppLifecycleReactor({required this.child, super.key});

  @override
  State<AppLifecycleReactor> createState() => _AppLifecycleReactorState();
}

class _AppLifecycleReactorState extends State<AppLifecycleReactor> with WidgetsBindingObserver {
  DateTime? _lastPauseTime;
  bool _isFirstLaunch = true; // ✅ NOUVEAU: Flag pour détecter le lancement initial
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppUsageService.startSession();
    print('🚀 Application initialisée - Premier lancement: $_isFirstLaunch');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppUsageService.endSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 AppLifecycleState changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        AppUsageService.startSession();
        
        // ✅ CORRECTION: Ne pas démarrer le service au lancement initial
        if (_isFirstLaunch) {
          print('🚀 Premier lancement détecté - Service de maintenance NON démarré');
          _isFirstLaunch = false;
        } else {
          // ✅ CORRECTION: Ne pas démarrer le service automatiquement
          // Le service sera démarré seulement quand l'utilisateur va sur la page radio
          print('✅ App revenue au premier plan - Service de maintenance NON démarré automatiquement');
        }
        break;
        
      case AppLifecycleState.paused:
        print('⏸️ App mise en pause - maintien en arrière-plan');
        // ✅ CRITIQUE: Ne pas arrêter le service de maintien
        // L'app doit rester active en arrière-plan
        _lastPauseTime = DateTime.now();
        print('⏰ Temps de pause enregistré: $_lastPauseTime');
        break;
        
      case AppLifecycleState.inactive:
        print('🔄 App inactive - transition en cours');
        break;
        
      case AppLifecycleState.hidden:
        print('👁️ App cachée - maintien en arrière-plan');
        break;
        
      case AppLifecycleState.detached:
        print('🚪 App détachée - VÉRIFICATION si fermeture réelle ou simple retour');
        
        // ✅ NOUVEAU: Vérifier si c'est une vraie fermeture ou juste un retour
        if (_isRealAppExit()) {
          print('🚪 Fermeture réelle de l\'app détectée');
          AppUsageService.endSession();
          BackgroundMaintenanceService().stop();
          _performProactiveDataRecovery();
        } else {
          print('⏸️ Simple retour en arrière-plan - maintien des services');
          // Garder les services actifs
        }
        break;
    }
  }

  /// ✅ NOUVEAU: Détermine si c'est une vraie fermeture ou un simple retour
  bool _isRealAppExit() {
    // Si l'app est en arrière-plan depuis moins de 30 secondes, 
    // c'est probablement un simple retour, pas une fermeture
    final now = DateTime.now();
    final timeSincePause = now.difference(_lastPauseTime ?? now);
    
    // Si moins de 30 secondes depuis la pause, c'est un retour
    if (timeSincePause.inSeconds < 30) {
      print('⏸️ Détecté comme retour en arrière-plan (${timeSincePause.inSeconds}s)');
      return false;
    }
    
    print('🚪 Détecté comme fermeture réelle (${timeSincePause.inSeconds}s)');
    return true;
  }

  /// ✅ NOUVEAU: Effectue la récupération proactive des données utilisateur
  Future<void> _performProactiveDataRecovery() async {
    try {
      // Vérifier si un utilisateur est connecté
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId != null && userId.isNotEmpty) {
        print('🔄 App en pause/fermeture - Récupération proactive des données utilisateur');
        
        // Effectuer la récupération proactive
        await ProactiveDataRecoveryService.performProactiveRecovery(userId);
        
        print('✅ Récupération proactive terminée avant fermeture de l\'app');
      } else {
        print('ℹ️ Aucun utilisateur connecté - Pas de récupération proactive nécessaire');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération proactive: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> syncLocalDataToBackend(String userId) async {
  final favBox = Hive.box('favorites');
  final progressBox = Hive.box('progress');
  final commentsBox = Hive.box('comments');

  // Sync favoris
  for (var fav in favBox.values) {
    if (fav is LocalFavorite && fav.needsSync) {
      // On tente de récupérer la durée depuis la progression locale si dispo
      final prog = progressBox.values.cast<LocalProgress?>().firstWhere(
        (p) => p?.contentId == fav.contentId,
        orElse: () => null,
      );
      final duration = prog?.position ?? 0;
      final url = Uri.parse('https://embmission.com/mobileappebm/api/save_delete_favorie_contents?idcontents=${fav.contentId}&userId=$userId&duration=$duration');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          fav.needsSync = false;
          await fav.save();
        }
      } catch (_) {}
    }
  }

  // Sync progression
  for (var prog in progressBox.values) {
    if (prog is LocalProgress && prog.needsSync) {
      final duration = prog.position; // Ici, on suppose que la durée totale est stockée dans position (à ajuster si tu as la vraie durée)
      final url = Uri.parse('https://embmission.com/mobileappebm/api/save_listens_contents?userId=$userId&contentId=${prog.contentId}&position=${prog.position}&duration=$duration');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          prog.needsSync = false;
          await prog.save();
        }
      } catch (_) {}
    }
  }

  // Sync commentaires
  for (var comment in commentsBox.values) {
    if (comment is LocalComment && comment.needsSync) {
      try {
        final response = await http.post(
          Uri.parse('https://embmission.com/mobileappebm/api/save_contents_comments'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idcontents': comment.contentId,
            'id_user': userId,
            'contentscomments': comment.text,
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == 'true') {
            comment.needsSync = false;
            await comment.save();
            print('[SYNC] Commentaire synchronisé: ${comment.text}');
          }
        }
      } catch (e) {
        print('[SYNC] Erreur synchronisation commentaire: $e');
      }
    }
  }
}

void main() async {
  print('Lancement de MON projet EBM');
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase avec gestion d'erreur
  try {
    await Firebase.initializeApp();
    
    // ✅ NOUVEAU: Configuration du monitoring Firebase
    await _configureFirebaseMonitoring();
    
    // ✅ NOUVEAU: Initialiser le service de monitoring
    await MonitoringService.initialize();
    
    // Configurer le handler de messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    print('✅ Firebase initialisé avec succès');
  } catch (e) {
    print('❌ Erreur Firebase (non critique): $e');
    // Continuer sans Firebase
  }

  // Initialiser AudioService pour la lecture en arrière-plan
  try {
    await AudioService.init(
      builder: () => RadioAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.embmission.radio',
        androidNotificationChannelName: 'EMB-Mission Radio',
        androidNotificationOngoing: false,
        // ✅ CRITIQUE: Ne pas arrêter le service en arrière-plan
        androidStopForegroundOnPause: false,
        androidResumeOnClick: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        notificationColor: const Color(0xFF2196F3),
      ),
    );
    print('✅ AudioService initialisé avec succès - configuration optimisée pour l\'arrière-plan');
  } catch (e) {
    print('❌ Erreur AudioService (non critique): $e');
    // Continuer sans AudioService
  }
  
  // Initialiser les préférences partagées
  final prefs = await SharedPreferences.getInstance();
  
  // Vérifier l'état de l'onboarding (normalement false à la première installation)
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  print('État de l\'onboarding : $onboardingCompleted');
  
  // Afficher le statut de l'onboarding
  if (!onboardingCompleted) {
    print('🆕 Première installation - OnboardingScreen va s\'afficher');
  } else {
    print('📱 Installation existante - OnboardingScreen déjà complété');
  }
  
  // Initialiser l'état d'authentification si l'utilisateur est déjà connecté
  final savedUserId = prefs.getString('user_id');
  if (savedUserId != null && savedUserId.isNotEmpty) {
    print('✅ Utilisateur déjà connecté détecté: $savedUserId');
  } else {
    print('ℹ️ Aucun utilisateur connecté détecté');
  }

  await Hive.initFlutter();
  Hive.registerAdapter(LocalFavoriteAdapter());
  Hive.registerAdapter(LocalProgressAdapter());
  Hive.registerAdapter(LocalCommentAdapter());
  await Hive.openBox('favorites');
  await Hive.openBox('progress');
  await Hive.openBox('comments');
  
  // Initialiser les services de contrôle
  // NotificationControlService().initialize(); // Nécessite un WidgetRef
  
  // ✅ DÉSACTIVÉ: Moniteur de synchronisation radio DÉSACTIVÉ au démarrage de l'app
  // (pour éviter le démarrage automatique du service Android et de la notification radio)
  print('🔧 [MAIN] ✅ Moniteur de synchronisation radio DÉSACTIVÉ au démarrage de l\'app');
  // final radioSyncMonitor = RadioSyncMonitor();
  // radioSyncMonitor.startMonitoring(); // ← DÉSACTIVÉ
  print('🔧 [MAIN] ✅ Moniteur de synchronisation radio DÉSACTIVÉ (évite la notification radio)');
  
  runApp(
    ProviderScope(
      overrides: [
        // Fournir l'instance de SharedPreferences à l'application
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: NotificationServiceInitializer(
        child: AppLifecycleReactor(
          child: const MyApp(),
        ),
      ),
    ),
  );
}



/// Provider pour le thème de l'application
final themeProvider = StateProvider<ThemeMode>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return preferencesService.isDarkMode() ? ThemeMode.dark : ThemeMode.light;
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  /// ✅ NOUVEAU: Restaure immédiatement les données proactives
  Future<void> _restoreProactiveData() async {
    try {
      print('🔄 Restauration immédiate des données proactives...');
      
      // Vérifier si un utilisateur est connecté
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId != null && userId.isNotEmpty) {
        // Vérifier si des données proactives sont disponibles
        final lastRecovery = await ProactiveDataRecoveryService.getLastRecoveryTime();
        
        if (lastRecovery != null) {
          final difference = DateTime.now().difference(lastRecovery);
          
          // Si la récupération date de moins de 2 heures, les données sont considérées fraîches
          if (difference.inHours < 2) {
            print('✅ Données proactives récentes disponibles (${difference.inMinutes} minutes)');
            print('📊 Avatar et nom utilisateur restaurés immédiatement');
          } else {
            print('ℹ️ Données proactives expirées (${difference.inHours} heures)');
            print('🔄 Récupération en arrière-plan nécessaire');
          }
        } else {
          print('ℹ️ Aucune donnée proactive disponible');
        }
      } else {
        print('ℹ️ Aucun utilisateur connecté - Pas de restauration nécessaire');
      }
    } catch (e) {
      print('❌ Erreur lors de la restauration des données proactives: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ NOUVEAU: Initialiser le service de contrôle de notification
    NotificationControlService.instance.initialize(ref);
    
    // Vérifier si les préférences sont initialisées
    final prefsState = ref.watch(preferencesServiceInitProvider);
    // Initialiser l'état d'authentification
    final authState = ref.watch(authInitializerProvider);
    
    return prefsState.when(
      data: (_) => authState.when(
        data: (_) => _buildApp(context, ref),
        loading: () => MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        error: (error, stack) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Erreur d\'authentification: $error'),
            ),
          ),
        ),
      ),
      loading: () => MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Erreur de chargement: $error'),
          ),
        ),
      ),
    );
  }
  
  Widget _buildApp(BuildContext context, WidgetRef ref) {
    // Récupérer le routeur
    final router = ref.watch(appRouterProvider);
    
    // Récupérer le mode de thème
    final themeMode = ref.watch(themeProvider);

      // ✅ RÉCUPÉRATION AUTOMATIQUE: Déclencher la récupération des données utilisateur
  ref.watch(userDataRecoveryProvider);
  
  // ✅ NOUVEAU: Restauration immédiate des données proactives
  _restoreProactiveData();
  
  // ✅ DÉSACTIVÉ: Service de maintien en arrière-plan DÉSACTIVÉ au démarrage de l'app
  // (pour éviter le démarrage automatique du service Android et de la notification radio)
  // WidgetsBinding.instance.addPostFrameCallback((_) {
  //   BackgroundMaintenanceService().start(); // ← DÉSACTIVÉ
  // });

  // ✅ NOUVEAU: Arrêter forcément la radio au démarrage de l'app pour éviter la notification
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      print('🚨 [MAIN] Arrêt forcé de la radio au démarrage de l\'app...');
      
      // Importer le provider de la radio
      final radioProvider = ref.read(radio_provider.radioPlayingProvider.notifier);
      
      // Arrêter forcément la radio
      await radioProvider.forceStopRadioOnAppStart();
      
      print('✅ [MAIN] Radio arrêtée avec succès au démarrage de l\'app');
      
    } catch (e) {
      print('❌ [MAIN] Erreur lors de l\'arrêt forcé de la radio: $e');
    }
  });

    return AppExitProtection(
      child: UserActivityTracker(
        child: GuestActivityTracker(
          child: NotificationServiceInitializer(
            child: MaterialApp.router(
              title: 'EMB-Mission',
              debugShowCheckedModeBanner: false,
              
              // Configuration du routeur
              routerConfig: router,
              
              // Thème clair
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: AppTheme.lightColorScheme,
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
                appBarTheme: AppTheme.appBarTheme,
                cardTheme: AppTheme.cardTheme,
                elevatedButtonTheme: AppTheme.elevatedButtonTheme,
                outlinedButtonTheme: AppTheme.outlinedButtonTheme,
                bottomNavigationBarTheme: AppTheme.bottomNavBarTheme,
              ),
              
              // Thème sombre
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: AppTheme.darkColorScheme,
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
                appBarTheme: AppTheme.darkAppBarTheme,
                cardTheme: AppTheme.darkCardTheme,
                elevatedButtonTheme: AppTheme.elevatedButtonTheme,
                outlinedButtonTheme: AppTheme.outlinedButtonTheme,
                bottomNavigationBarTheme: AppTheme.darkBottomNavBarTheme,
              ),
              
              // Mode de thème actuel
              themeMode: themeMode,
            ),
          ),
        ),
      ),
    );
  }
}
