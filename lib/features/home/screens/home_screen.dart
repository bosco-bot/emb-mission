import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emb_mission/features/radio/screens/radio_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:emb_mission/features/tv/screens/tv_live_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emb_mission/features/home/screens/about_screen.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/features/player/screens/player_screen.dart';
import 'package:emb_mission/features/home/screens/donation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:emb_mission/core/services/audio_service.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:emb_mission/core/services/notification_service.dart';
import 'package:emb_mission/core/providers/notification_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Le modèle NotificationItem est maintenant dans notification_provider.dart

/// Écran d'accueil de l'application
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  // 🚨 VARIABLE GLOBALE pour forcer la fermeture de la carte radio
  static bool _forceCloseRadioCard = false;
  
  /// Getter pour accéder à la variable depuis l'extérieur
  static bool get forceCloseRadioCard => _forceCloseRadioCard;
  
  /// Setter pour activer la fermeture forcée de la carte radio
  static void setForceCloseRadioCard(bool value) {
    _forceCloseRadioCard = value;
    print('🔊 [HomeScreen] Variable globale _forceCloseRadioCard mise à: $value');
  }

  /// Fonction publique pour arrêter la radio live depuis n'importe où dans l'app
  static Future<void> stopRadioLive(WidgetRef ref) async {
    try {
      final radioPlayer = ref.read(radioPlayerProvider);
      await radioPlayer.stop();
      
      // 🚨 FORCER LA MISE À JOUR DE L'ÉTAT MULTIPLE FOIS
      print('🔊 [stopRadioLive] Arrêt du player audio...');
      await radioPlayer.stop();
      
      print('🔊 [stopRadioLive] Mise à jour radioPlayingProvider à false...');
      ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
      
      print('🔊 [stopRadioLive] Appel de stopRadio()...');
      await ref.read(radioPlayingProvider.notifier).stopRadio();
      
      // 🚨 NOUVEAU: Vérifier et forcer une deuxième fois si nécessaire
      await Future.delayed(Duration(milliseconds: 100));
      final currentState = ref.read(radioPlayingProvider);
      print('🔊 [stopRadioLive] État après 100ms: $currentState');
      
      if (currentState) {
        print('🔊 [stopRadioLive] État toujours à true, forçage final...');
        ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
        await ref.read(radioPlayingProvider.notifier).stopRadio();
      }
      
      print('🔊 Radio arrêtée depuis la fonction publique stopRadioLive');
    } catch (e) {
      print('❌ Erreur lors de l\'arrêt de la radio: $e');
    }
  }

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  // Supprimer les variables locales et utiliser les providers Riverpod
  // List<NotificationItem> _notifications = [];
  // int _unreadCount = 0;
  bool _isLoaded = false;
  
  // ✅ NOUVEAU: Variables pour l'actualisation des contenus "Aujourd'hui"
  Timer? _todayEventsRefreshTimer;
  List<TodayEvent> _todayEvents = [];
  bool _isLoadingTodayEvents = false;
  
  // Instance statique pour permettre l'accès depuis NotificationService
  static _HomeScreenState? _instance;
  
  @override
  void initState() {
    super.initState();
    _instance = this;
    
    // Ajouter l'observer pour le cycle de vie de l'app
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ NOUVEAU: Actualisation automatique des contenus "Aujourd'hui"
    _startTodayEventsRefresh();
    
    // Plus besoin de configurer le callback - les notifications sont gérées via les providers
    
    // Vérifier et traiter les notifications en attente au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Attendre un peu que NotificationService soit complètement initialisé
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            // Vérifier s'il y a des notifications en attente et les traiter
            _checkAndProcessPendingNotifications();
            
            // Si l'app a été ouverte depuis la barre système, ouvrir automatiquement le BottomSheet
            final shouldOpen = NotificationService.consumeOpenNotificationsSheetPending();
            if (shouldOpen && mounted) {
              _showNotificationsDialog(context);
            }
          }
        });
      } catch (e) {
        print('❌ Erreur dans initState postFrameCallback: $e');
      }
    });
  }
  
  // ✅ NOUVEAU: Méthode pour démarrer l'actualisation automatique des contenus "Aujourd'hui"
  void _startTodayEventsRefresh() {
    // Charger les événements immédiatement
    _loadTodayEvents();
    
    // Actualiser toutes les 5 minutes pour vérifier la durée de visibilité
    _todayEventsRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadTodayEvents();
      }
    });
  }
  
  // ✅ NOUVEAU: Méthode pour charger les contenus "Aujourd'hui"
  Future<void> _loadTodayEvents() async {
    if (_isLoadingTodayEvents) return;
    
    setState(() {
      _isLoadingTodayEvents = true;
    });
    
    try {
      final events = await fetchTodayEvents();
      if (mounted) {
        setState(() {
          _todayEvents = events;
          _isLoadingTodayEvents = false;
        });
        print('✅ Contenus "Aujourd\'hui" actualisés: ${events.length} événements');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTodayEvents = false;
        });
        print('❌ Erreur lors de l\'actualisation des contenus "Aujourd\'hui": $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 🚨 NOUVEAU: Vérifier la variable globale de fermeture forcée
    print('🔊 [didChangeDependencies] Appelé - Vérification variable globale...');
    print('🔊 [didChangeDependencies] État actuel: HomeScreen.forceCloseRadioCard = ${HomeScreen.forceCloseRadioCard}');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔊 [didChangeDependencies] PostFrameCallback exécuté');
      print('🔊 [didChangeDependencies] État dans PostFrameCallback: HomeScreen.forceCloseRadioCard = ${HomeScreen.forceCloseRadioCard}');
      
      if (HomeScreen.forceCloseRadioCard) {
        print('🔊 [didChangeDependencies] 🚨 FERMETURE FORCÉE DÉTECTÉE - Arrêt de la radio...');
        // Forcer l'arrêt de la radio
        HomeScreen.stopRadioLive(ref);
        // Réinitialiser la variable
        HomeScreen.setForceCloseRadioCard(false);
        print('🔊 [didChangeDependencies] ✅ Variable réinitialisée à false');
      } else {
        print('🔊 [didChangeDependencies] ✅ Pas de fermeture forcée nécessaire');
      }
    });
  }

  /// Vérifie et traite les notifications en attente au démarrage de l'app
  Future<void> _checkAndProcessPendingNotifications() async {
    try {
      print('🔍 DEBUG: Vérification des notifications en attente au démarrage...');
      
      // Vérifier s'il y a des notifications non lues
      final notifications = ref.read(notificationsProvider);
      final unreadCount = ref.read(unreadCountProvider);
      
      print('🔍 DEBUG: Notifications actuelles: ${notifications.length}, Non lues: $unreadCount');
      
      // Vérifier s'il y a des notifications en attente dans le fichier
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final notificationsFile = File('${appDir.path}/pending_notifications.json');
        
        if (await notificationsFile.exists()) {
          final content = await notificationsFile.readAsString();
          final List<dynamic> jsonList = jsonDecode(content);
          final notifications = jsonList.cast<Map<String, dynamic>>();
          
          print('🔍 DEBUG: Fichier de notifications trouvé avec ${notifications.length} notifications');
          
          if (notifications.isNotEmpty) {
            print('🔍 DEBUG: ${notifications.length} notifications en attente détectées dans le fichier');
            
            // Traiter ces notifications via NotificationService
            await NotificationService.processPendingNotifications();
            
            // Attendre un peu que les providers se mettent à jour
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Vérifier le nouveau compteur
            final newUnreadCount = ref.read(unreadCountProvider);
            final newNotifications = ref.read(notificationsProvider);
            
            print('🔍 DEBUG: Après traitement - Notifications: ${newNotifications.length}, Non lues: $newUnreadCount');
            
            // IMPORTANT: Ne PAS ouvrir automatiquement le bottom sheet ici
            // Le bottom sheet ne doit s'ouvrir que quand on clique sur une notification
            // Ici, on met juste à jour le badge et les notifications
            print('🔍 DEBUG: Notifications traitées, badge mis à jour, bottom sheet fermé (ouverture directe de l\'app)');
          } else {
            print('🔍 DEBUG: Fichier de notifications vide');
          }
        } else {
          print('🔍 DEBUG: Aucun fichier de notifications trouvé');
        }
      } catch (e) {
        print('❌ Erreur vérification fichier de notifications: $e');
      }
      
      // Même sans notifications en attente, si il y a des notifications non lues,
      // NE PAS ouvrir automatiquement le bottom sheet (seulement quand on clique sur notification)
      if (unreadCount > 0 && mounted) {
        print('🔍 DEBUG: Notifications non lues existantes, badge affiché, bottom sheet fermé (ouverture directe de l\'app)');
        // IMPORTANT: Ne PAS marquer pour ouverture automatique
        // Le bottom sheet ne doit s'ouvrir que quand on clique sur une notification
      }
    } catch (e) {
      print('❌ Erreur vérification notifications en attente: $e');
    }
  }
  
  @override
  void dispose() {
    if (_instance == this) {
      _instance = null;
    }
    
    // ✅ NOUVEAU: Nettoyer le timer d'actualisation des contenus "Aujourd'hui"
    _todayEventsRefreshTimer?.cancel();
    
    // Retirer l'observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed) {
      print('🔍 DEBUG: App revenue au premier plan, vérification des notifications...');
      // Attendre un peu puis vérifier s'il y a des notifications en attente
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkAndProcessPendingNotifications();
        }
      });
    }
  }
  
  // Les notifications sont maintenant gérées directement par les providers Riverpod
  // via NotificationService.addNotificationToProvider()

  // Supprimer une notification via le provider
  void _removeNotification(int index) {
    try {
      final notifier = ref.read(notificationsProvider.notifier);
      notifier.removeNotification(index);
      
      // Le compteur est maintenant géré automatiquement par le provider
      print('✅ Notification supprimée via provider');
    } catch (e) {
      print('❌ Erreur suppression notification: $e');
    }
  }

  // Marquer toutes comme lues via le provider
  void _markAllAsRead() {
    try {
      final notifications = ref.read(notificationsProvider);
      final notifier = ref.read(notificationsProvider.notifier);
      
      // Marquer toutes comme lues
      for (int i = 0; i < notifications.length; i++) {
        if (!notifications[i].isRead) {
          notifier.markAsRead(i);
        }
      }
      
      // Le compteur est maintenant géré automatiquement par le provider
      print('✅ Toutes les notifications marquées comme lues');
    } catch (e) {
      print('❌ Erreur marquage notifications: $e');
    }
  }

  // Marquer une notification individuelle comme lue via le provider
  void _markNotificationAsRead(int index) {
    try {
      final notifications = ref.read(notificationsProvider);
      if (index < notifications.length && !notifications[index].isRead) {
        final notifier = ref.read(notificationsProvider.notifier);
        notifier.markAsRead(index);
        
        // Le compteur est maintenant géré automatiquement par le provider
        print('✅ Notification $index marquée comme lue');
      }
    } catch (e) {
      print('❌ Erreur marquage notification: $e');
    }
  }





  @override
  Widget build(BuildContext context) {
    final homeItemsAsync = ref.watch(homeItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red,
              child: const Text(
                'emb',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMB-Mission',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Matthieu 28:19-20',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed('search_page'),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  _showNotificationsDialog(context);
                },
              ),
              if (ref.watch(unreadCountProvider) > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      ref.watch(unreadCountProvider) > 99 ? '99+' : ref.watch(unreadCountProvider).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Attendre que les providers soient rafraîchis
          await Future.wait([
            ref.refresh(homeItemsProvider.future),
            ref.refresh(popularItemsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière Radio Live
              _buildRadioLiveBanner(context, ref),
              
              // Section avec image de fond et boutons
              Container(
                width: double.infinity,
                height: 300,
                child: Stack(
                  children: [
                    // Image de fond - légèrement remontée
                    Positioned(
                      top: -20,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Image.asset(
                        'assets/images/FOND_EMB.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Boutons Radio Live et TV Live positionnés en bas
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) => ElevatedButton.icon(
                                icon: SvgPicture.asset(
                                  'assets/images/radio.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                ),
                                label: const Text('Radio Live', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  context.pushNamed('radio');
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.tv, color: Colors.white),
                              label: const Text('TV Live', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                print('🎬 Tentative de navigation vers TV Live');
                                context.pushNamed('tv');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Catégories
              Container(
                padding: const EdgeInsets.only(left: 4, right: 12, top: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                ),
                child: Column(
                  children: [
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(),
                        1: FlexColumnWidth(),
                        2: FlexColumnWidth(),
                        3: FlexColumnWidth(),
                      },
                      children: [
                        TableRow(
                          children: [
                            _buildCategoryButtonWithSvg(
                              svgAsset: 'assets/images/bible.svg',
                              label: 'Bible',
                              color: Colors.blue,
                              onTap: () => context.go('/bible?book=Genèse&chapter=1'),
                            ),
                            _buildCategoryButtonWithSvg(
                              svgAsset: 'assets/images/prières.svg',
                              label: 'Prières',
                              color: Colors.green,
                              onTap: () => context.pushNamed('prayer'),
                            ),
                            _buildCategoryButtonWithSvg(
                              svgAsset: 'assets/images/temoignages.svg',
                              label: 'Témoignages',
                              color: Colors.purple,
                              onTap: () => context.pushNamed('testimonies'),
                            ),
                            _buildCategoryButtonWithSvg(
                              svgAsset: 'assets/images/contenus.svg',
                              label: 'Contenus',
                              color: Colors.black,
                              onTap: () {
                                context.pushNamed('contents');
                              },
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const SizedBox(height: 16),
                            const SizedBox(height: 16),
                            const SizedBox(height: 16),
                            const SizedBox(height: 16),
                          ],
                        ),
                        TableRow(
                          children: [
                            _buildCategoryButtonWithSvg(
                              svgAsset: 'assets/images/temoignages.svg',
                              label: 'Faire un Don',
                              color: Colors.green,
                              backgroundColor: Colors.black.withAlpha(26),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const DonationScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildCategoryButtonWithSvg(
                              svgAsset: 'assets/images/a_propos.svg',
                              label: 'À propos',
                              color: Colors.green,
                              onTap: () => context.pushNamed('about'),
                            ),
                            _buildCategoryButtonWithIcon(
                              icon: FontAwesomeIcons.youtube,
                              label: 'YouTube',
                              color: Colors.red,
                              onTap: () async {
                                const raw = 'https://www.youtube.com/channel/UC5R0ylmE2ZyFi0p8yEhZM2A';
                                final uri = Uri.parse(raw);
                                // Ouvrir d'abord dans l'app (webview), sinon en externe
                                bool ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
                                if (!ok) {
                                  ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                            _buildCategoryButtonWithIcon(
                              icon: FontAwesomeIcons.facebook,
                              label: 'Facebook',
                              color: Colors.blue,
                              onTap: () async {
                                const id = '61571473247091';
                                final fbProfileUri = Uri.parse('fb://profile/$id');
                                final fbPageUri = Uri.parse('fb://page/$id');
                                final fbFacewebUri = Uri.parse('fb://facewebmodal/f?href=https://www.facebook.com/profile.php?id=$id');
                                final webMobile = Uri.https('m.facebook.com', '/profile.php', {'id': id});
                                final webWWW = Uri.https('www.facebook.com', '/profile.php', {'id': id});

                                Future<bool> tryOpen(Uri uri) async {
                                  try {
                                    return await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (_) {
                                    return false;
                                  }
                                }

                                if (await tryOpen(fbProfileUri)) return;
                                if (await tryOpen(fbPageUri)) return;
                                if (await tryOpen(fbFacewebUri)) return;
                                if (await tryOpen(webMobile)) return;
                                if (await tryOpen(webWWW)) return;
                                // Dernier recours: webview intégrée
                                await launchUrl(webMobile, mode: LaunchMode.inAppWebView);
                              },
                            ),
                          ],
                        ),
                      ],
                    ), // <-- fin Table
                    // (Supprimer le label 'Réseaux Sociaux' ici)
                  ],
                ),
              ),
              
              // Aujourd'hui - Section avec fond gris léger
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50], // Fond gris très léger
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre de la section
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: const Text(
                        'Aujourd\'hui',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    
                    // Éléments du jour
                    _isLoadingTodayEvents
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _todayEvents.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Aucun événement pour aujourd\'hui.'),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _todayEvents.length,
                                itemBuilder: (context, index) {
                                  final item = _todayEvents[index];
                                  return _buildTodayCard(
                                    title: item.titre,
                                    time: item.heure.substring(0, 5) + (item.statut == 'live' ? ' - En direct' : ''),
                                    isLive: item.statut == 'live',
                                    onTap: () {
                                      context.pushNamed('prayer_detail', pathParameters: {'id': item.id.toString()});
                                    },
                                  );
                                },
                              ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit un bouton de catégorie avec une icône SVG
  Widget _buildCategoryButtonWithSvg({
    required String svgAsset,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: backgroundColor ?? color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.asset(
                svgAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Construit un bouton de catégorie avec une icône Material
  Widget _buildCategoryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withAlpha(26), // Équivalent à une opacité de 0.1
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Construit une carte pour la section "Aujourd'hui"
  Widget _buildTodayCard({
    required String title,
    required String time,
    required bool isLive,
    required VoidCallback onTap,
  }) {
    // Déterminer l'icône SVG et la couleur de fond en fonction du titre
    String svgAsset;
    Color backgroundColor;
    Color iconColor;
    
    if (title.toLowerCase().contains('prière')) {
      svgAsset = 'assets/images/play.svg';
      backgroundColor = const Color(0xFF69B6FF); // Bleu vif comme sur l'image
      iconColor = Colors.white;
    } else {
      svgAsset = 'assets/images/etude.svg';
      backgroundColor = const Color(0xFF4CAF50); // Vert vif comme sur l'image
      iconColor = Colors.white;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icône SVG avec fond coloré
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    svgAsset,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge LIVE
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE), // Rose très clair comme sur l'image
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFFE57373), // Rouge clair pour le texte
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit la bannière Radio Live en haut de l'écran
  Widget _buildRadioLiveBanner(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(radioPlayingProvider);
    final radioPlayer = ref.read(radioPlayerProvider);
    
    // 🚨 NOUVEAU: Vérifier la variable globale de fermeture forcée
    print('🔊 [Radio Banner] 🔍 Vérification variable globale: HomeScreen.forceCloseRadioCard = ${HomeScreen.forceCloseRadioCard}');
    
    if (HomeScreen.forceCloseRadioCard) {
      print('🔊 [Radio Banner] 🚨 FERMETURE FORCÉE DÉTECTÉE - Arrêt de la radio...');
      // Réinitialiser la variable
      HomeScreen.setForceCloseRadioCard(false);
      print('🔊 [Radio Banner] ✅ Variable réinitialisée à false');
      // Forcer l'arrêt de la radio
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        print('🔊 [Radio Banner] PostFrameCallback exécuté - Arrêt de la radio...');
        await HomeScreen.stopRadioLive(ref);
        print('🔊 [Radio Banner] ✅ Radio arrêtée via PostFrameCallback');
      });
      return const SizedBox.shrink();
    }
    
    print('🔊 [Radio Banner] ✅ Pas de fermeture forcée - État normal: isPlaying = $isPlaying');
    if (!isPlaying) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        context.pushNamed('radio');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: Colors.lightBlue.shade300,
        child: Row(
          children: [
            Icon(
              isPlaying ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Radio Live',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'En cours...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () async {
                // Utiliser la fonction publique
                await HomeScreen.stopRadioLive(ref);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche une boîte de dialogue moderne pour les notifications
  void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Restez connecté avec votre communauté',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  
                  // Actions rapides
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _markAllAsRead();
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Toutes les notifications marquées comme lues')),
                              );
                            },
                            icon: const Icon(Icons.done_all, size: 16),
                            label: const Text('Tout marquer lu'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Liste des notifications
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final notifications = ref.watch(notificationsProvider);
                        print('🔍 DEBUG: HomeScreen - Nombre de notifications: ${notifications.length}');
                        if (notifications.isNotEmpty) {
                          print('🔍 DEBUG: HomeScreen - Première notification: ${notifications.first.title}');
                        }
                        
                        return notifications.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Aucune notification reçue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Les nouvelles notifications apparaîtront ici',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: notifications.length,
                                itemBuilder: (context, index) {
                                  final notification = notifications[index];
                                  final uniqueKey = Key('${notification.title}_${notification.receivedAt.millisecondsSinceEpoch}_$index');
                                  
                                  return Dismissible(
                                    key: uniqueKey,
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Supprimer la notification'),
                                            content: const Text('Êtes-vous sûr de vouloir supprimer cette notification ?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Supprimer'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _removeNotification(index);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Notification supprimée'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: _buildNotificationItem(
                                      notification,
                                      index,
                                      context,
                                    ),
                                  );
                                },
                              );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem notif, int index, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notif.isRead ? Colors.grey.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notif.isRead ? Colors.grey.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône de notification
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: notif.isRead ? Colors.grey.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              notif.isRead ? Icons.notifications_none : Icons.notifications,
              color: notif.isRead ? Colors.grey : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Contenu de la notification
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: notif.isRead ? Colors.grey[600] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: TextStyle(
                    fontSize: 14,
                    color: notif.isRead ? Colors.grey[500] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(notif.receivedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Bouton d'action
          IconButton(
            onPressed: notif.isRead ? null : () {
              _markNotificationAsRead(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification marquée comme lue')),
              );
            },
            icon: Icon(
              notif.isRead ? Icons.check_circle : Icons.check_circle_outline,
              color: notif.isRead ? Colors.green : Colors.grey[400],
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inSeconds < 60) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Il y a $m minute${m > 1 ? 's' : ''}';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Il y a $h heure${h > 1 ? 's' : ''}';
    } else {
      final d = diff.inDays;
      return 'Il y a $d jour${d > 1 ? 's' : ''}';
    }
  }
}



class TodayEvent {
  final int id;
  final String titre;
  final String description;
  final String heure;
  final String dateEvenement;
  final String type;
  final String statut;
  final String? icone;
  final String? couleur;

  TodayEvent({
    required this.id,
    required this.titre,
    required this.description,
    required this.heure,
    required this.dateEvenement,
    required this.type,
    required this.statut,
    this.icone,
    this.couleur,
  });

  factory TodayEvent.fromJson(Map<String, dynamic> json) {
    return TodayEvent(
      id: json['idevents'],
      titre: json['titre'],
      description: json['description'],
      heure: json['heure'],
      dateEvenement: json['date_evenement'],
      type: json['type'],
      statut: json['statut'],
      icone: json['icone'],
      couleur: json['couleur'],
    );
  }
}

Future<List<TodayEvent>> fetchTodayEvents() async {
  final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/today_home_events'));
  if (response.statusCode == 200) {
    final jsonBody = json.decode(response.body);
    if (jsonBody['statevents'] == 'success') {
      final List<dynamic> eventsJson = jsonBody['dataevents'];
      return eventsJson.map((e) => TodayEvent.fromJson(e)).toList();
    } else {
      throw Exception('Erreur lors de la récupération des événements');
    }
  } else {
    throw Exception('Erreur réseau');
  }
}

// Ajout de la fonction pour FontAwesome
  Widget _buildCategoryButtonWithIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: backgroundColor ?? color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: FaIcon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

