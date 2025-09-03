import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emb_mission/features/home/screens/home_screen.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';
import 'package:emb_mission/features/bible/screens/bible_screen.dart';
import 'package:emb_mission/features/bible/screens/reading_plans_screen.dart';
import 'package:emb_mission/features/prayer/screens/prayer_screen.dart';
import 'package:emb_mission/features/prayer/screens/prayer_detail_screen.dart';
import 'package:emb_mission/features/testimonies/screens/testimonies_screen.dart';
import 'package:emb_mission/features/testimonies/screens/new_testimony_screen.dart';
import 'package:emb_mission/features/community/screens/community_screen.dart';
import 'package:emb_mission/features/search/screens/search_screen.dart';
import 'package:emb_mission/features/profile/screens/profile_screen.dart';
import 'package:emb_mission/features/player/screens/player_screen.dart';
import 'package:emb_mission/features/radio/screens/radio_screen.dart';
import 'package:emb_mission/features/tv/screens/tv_live_screen.dart';
import 'package:emb_mission/features/actions/screens/actions_screen.dart';
import 'package:emb_mission/features/stats/screens/stats_screen.dart';
import 'package:emb_mission/features/settings/screens/advanced_settings_screen.dart';
import 'package:emb_mission/features/settings/screens/legal_pages_screen.dart';
import 'package:emb_mission/features/contents/screens/contents_screen.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:emb_mission/features/community/screens/group_detail_screen.dart';
import 'package:emb_mission/features/community/screens/forums_list_screen.dart';
import 'package:emb_mission/features/community/screens/forum_screen.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/community/screens/group_viewmsg_screen.dart';
import 'package:emb_mission/features/home/screens/about_screen.dart';
import 'package:emb_mission/features/profile/screens/edit_profile_screen.dart';

// Couleur bleue utilisée dans l'application
const Color bibleBlueColor = Color(0xFF64B5F6);

/// Classe pour écouter les changements de l'état d'onboarding
class OnboardingStatusNotifier extends ChangeNotifier {
  bool _isCompleted = false;
  
  bool get isCompleted => _isCompleted;
  
  OnboardingStatusNotifier() {
    _loadStatus();
  }
  
  // Méthode pour forcer l'affichage de l'onboarding
  Future<void> forceShowOnboarding() async {
    _isCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
    notifyListeners();
  }
  
  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isCompleted = prefs.getBool('onboarding_completed') ?? false;
    notifyListeners();
  }
  
  Future<void> setCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', value);
    _isCompleted = value;
    notifyListeners();
  }
}

/// Provider pour l'objet OnboardingStatusNotifier
final onboardingStatusProvider = Provider<OnboardingStatusNotifier>((ref) {
  return OnboardingStatusNotifier();
});

/// Provider pour vérifier si l'onboarding a été complété
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

/// Configuration du routeur de l'application
/// Provider pour le routeur de l'application
final appRouterProvider = Provider<GoRouter>((ref) {
  // Utiliser uniquement le status notifier qui implémente Listenable
  final onboardingStatus = ref.watch(onboardingStatusProvider);
  
      return GoRouter(
      initialLocation: '/',
      refreshListenable: onboardingStatus,
    redirect: (context, state) {
      // Utiliser la valeur du notifier qui est toujours à jour
      final bool isOnboardingCompleted = onboardingStatus.isCompleted;
      final bool isOnboardingRoute = state.uri.path == '/';
      
      // Afficher les valeurs pour le débogage
      print('Onboarding complété: $isOnboardingCompleted, Route actuelle: ${state.uri.path}');
      
      // Si l'onboarding est terminé et que l'utilisateur est sur la route d'onboarding
      if (isOnboardingCompleted && isOnboardingRoute) {
        print('Redirection vers /home car onboarding terminé');
        return '/home';
      }
      
      // Si l'onboarding n'est pas terminé et que l'utilisateur essaie d'accéder à une autre route
      if (!isOnboardingCompleted && !isOnboardingRoute) {
        print('Redirection vers / car onboarding non terminé');
        return '/';
      }
      
      // Pas de redirection nécessaire
      print('Pas de redirection nécessaire');
      return null;
    },
    debugLogDiagnostics: true,
    routes: [
      // Route d'onboarding
      GoRoute(
        path: '/',
        name: 'onboarding',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: OnboardingScreen(),
        ),
      ),
      // Route principale avec navigation par onglets
      ShellRoute(
        builder: (context, state, child) {
          return ScaffoldWithBottomNavBar(child: child);
        },
        routes: [
          // Accueil
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
            routes: [
              // Recherche
              GoRoute(
                path: 'search',
                name: 'search',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SearchScreen(),
                ),
              ),
            ],
          ),
          // Bible
          GoRoute(
            path: '/bible',
            name: 'bible',
            pageBuilder: (context, state) {
              final params = state.uri.queryParameters;
              final book = params['book'] ?? 'Genèse';
              final chapter = int.tryParse(params['chapter'] ?? '1') ?? 1;
              return NoTransitionPage(
                child: BibleScreen(
                  key: ValueKey('${book}_$chapter'),
                  book: book,
                  chapter: chapter,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'reading-plans',
                name: 'reading_plans',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ReadingPlansScreen(),
                ),
              ),
            ],
          ),
          // Communauté
          GoRoute(
            path: '/community',
            name: 'community',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CommunityScreen(),
            ),
            routes: [
              GoRoute(
                path: 'group-detail/:id',
                name: 'group_detail',
                builder: (context, state) {
                  final groupId = state.pathParameters['id'] ?? '';
                  return GroupDetailScreen(groupId: groupId);
                },
              ),
              GoRoute(
                path: 'forum-detail/:id',
                name: 'forum_detail',
                builder: (context, state) {
                  final forumIdStr = state.pathParameters['id'] ?? '';
                  final forumId = int.tryParse(forumIdStr) ?? 0;
                  // On suppose que l'userId est accessible via Riverpod ou autre, ici on le récupère via ProviderScope.containerOf
                  final userId = ProviderScope.containerOf(context, listen: false).read(userIdProvider);
                  return ForumScreen(forumId: forumId, userId: userId ?? '');
                },
              ),
              GoRoute(
                path: 'forums',
                name: 'forums_list',
                builder: (context, state) => const ForumsListScreen(),
              ),
              GoRoute(
                path: 'group/:id',
                name: 'group_viewmsg',
                builder: (context, state) {
                  final groupId = state.pathParameters['id'] ?? '';
                  return GroupViewMsgScreen(groupId: groupId);
                },
              ),
            ],
          ),
          // Profil
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'edit_profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: EditProfileScreen(),
                ),
              ),
            ],
          ),
          // Contenus
          GoRoute(
            path: '/contents',
            name: 'contents',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ContentsScreen(),
            ),
          ),
          // Paramètres
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdvancedSettingsScreen(),
            ),
            routes: [
              // Pages légales
              GoRoute(
                path: 'legal',
                name: 'legal_pages',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: LegalPagesScreen(),
                ),
              ),
            ],
          ),
          // Stats
          GoRoute(
            path: '/stats',
            name: 'stats',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StatsScreen(),
            ),
          ),
          // Actions
          GoRoute(
            path: '/actions',
            name: 'actions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ActionsScreen(),
            ),
          ),
          // Radio
          GoRoute(
            path: '/radio',
            name: 'radio',
            pageBuilder: (context, state) => NoTransitionPage(
                              child: const RadioScreen(
                  radioName: 'Radio EMB-Mission',
                  streamUrl: 'https://stream.zeno.fm/rxi8n979ui1tv',
                ),
            ),
          ),

          // Lecteur
          GoRoute(
            path: '/player/:contentId',
            name: 'player',
            pageBuilder: (context, state) {
              final contentId = state.pathParameters['contentId'] ?? 'current';
              final title = state.uri.queryParameters['title'] ?? '';
              final author = state.uri.queryParameters['author'] ?? '';
              final fileUrl = state.uri.queryParameters['fileUrl'] ?? '';
              final startPosition = int.tryParse(state.uri.queryParameters['startPosition'] ?? '0') ?? 0;
              
              return NoTransitionPage(
                child: PlayerScreen(
                  contentId: contentId,
                  title: title.isNotEmpty ? title : null,
                  author: author.isNotEmpty ? author : null,
                  fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
                  startPosition: startPosition > 0 ? startPosition : null,
                ),
              );
            },
          ),
          // Recherche
          GoRoute(
            path: '/search',
            name: 'search_page',
            pageBuilder: (context, state) => NoTransitionPage(
              child: const SearchScreen(),
            ),
          ),

          // À propos
          GoRoute(
            path: '/about',
            name: 'about',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AboutScreen(),
            ),
          ),

        ],
      ),
      
      // Routes indépendantes
      GoRoute(
        path: '/prayer',
        name: 'prayer',
        builder: (context, state) => const PrayerScreen(),
        routes: [
          GoRoute(
            path: 'detail/:id',
            name: 'prayer_detail',
            builder: (context, state) {
              final prayerIdStr = state.pathParameters['id'] ?? '';
              final prayerId = int.tryParse(prayerIdStr) ?? 0;
              return PrayerDetailScreen(prayerId: prayerId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/testimonies',
        name: 'testimonies',
        builder: (context, state) => const TestimoniesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new_testimony',
            builder: (context, state) => const NewTestimonyScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      // TV Live
      GoRoute(
        path: '/tv',
        name: 'tv',
        builder: (context, state) => const TVLiveScreen(
          tvName: 'EMB TV Live',
          streamUrl: 'https://stream.berosat.live:19360/emb-mission-stream/emb-mission-stream.m3u8',
        ),
      ),
    ],
  );
});

/// Widget pour la barre de navigation du bas
class ScaffoldWithBottomNavBar extends StatefulWidget {
  final Widget child;

  const ScaffoldWithBottomNavBar({
    super.key,
    required this.child,
  });

  @override
  State<ScaffoldWithBottomNavBar> createState() => _ScaffoldWithBottomNavBarState();
}

class _ScaffoldWithBottomNavBarState extends State<ScaffoldWithBottomNavBar> {
  // Clé globale pour accéder au Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Éléments principaux pour la barre de navigation
  static const List<_NavigationDestination> _mainDestinations = [
    _NavigationDestination(
      route: '/home',
      svgAsset: 'assets/images/home.svg',
      label: 'Accueil',
    ),
    _NavigationDestination(
      route: '/bible',
      svgAsset: 'assets/images/bible.svg',
      label: 'Bible',
    ),
    _NavigationDestination(
      route: '/community',
      svgAsset: 'assets/images/communauté.svg',
      label: 'Communauté',
    ),
    _NavigationDestination(
      route: '/profile',
      svgAsset: 'assets/images/profil.svg',
      label: 'Profil',
    ),
  ];
  
  // Éléments supplémentaires pour le menu hamburger
  static const List<_NavigationDestination> _drawerDestinations = [
    _NavigationDestination(
      route: '/contents',
      svgAsset: 'assets/images/contenus.svg',
      label: 'Contenus',
    ),
    _NavigationDestination(
      route: '/settings',
      svgAsset: 'assets/images/params.svg',
      label: 'Paramètres',
    ),
    _NavigationDestination(
      route: '/stats',
      svgAsset: 'assets/images/stats.svg',
      label: 'Stats',
    ),
    _NavigationDestination(
      route: '/actions',
      svgAsset: 'assets/images/actions.svg',
      label: 'Actions',
    ),
    _NavigationDestination(
      route: '/radio',
      svgAsset: 'assets/images/radio.svg',
      label: 'Radio',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    print('ScaffoldWithBottomNavBar build exécuté');
    print('ScaffoldWithBottomNavBar child type: \\${widget.child.runtimeType}');
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF757575)),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text(
          'EMB-Mission',
          style: TextStyle(
            color: Color(0xFF757575),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Bouton de recherche
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF757575)),
            onPressed: () {
              context.go('/search');
            },
          ),

        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF4CB6FF),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 37,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 74,
                        height: 74,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'EMB-Mission',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Mathieu 28:19-20',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),


            // Contenus
            ListTile(
              leading: SvgPicture.asset(
                'assets/images/contenus.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Color(0xFF757575), BlendMode.srcIn),
              ),
              title: const Text('Contenus'),
              onTap: () {
                Navigator.pop(context);
                context.go('/contents');
              },
            ),
            // Paramètres
            ListTile(
              leading: SvgPicture.asset(
                'assets/images/params.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Color(0xFF757575), BlendMode.srcIn),
              ),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
            // Stats
            ListTile(
              leading: SvgPicture.asset(
                'assets/images/stats.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Color(0xFF757575), BlendMode.srcIn),
              ),
              title: const Text('Stats'),
              onTap: () {
                Navigator.pop(context);
                context.go('/stats');
              },
            ),
            // Actions
            ListTile(
              leading: SvgPicture.asset(
                'assets/images/actions.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Color(0xFF757575), BlendMode.srcIn),
              ),
              title: const Text('Actions'),
              onTap: () {
                Navigator.pop(context);
                context.go('/actions');
              },
            ),
            // Radio
            ListTile(
              leading: SvgPicture.asset(
                'assets/images/radio.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Color(0xFF757575), BlendMode.srcIn),
              ),
              title: const Text('Radio'),
              onTap: () {
                Navigator.pop(context);
                context.go('/radio');
              },
            ),

          ],
        ),
      ),
      body: widget.child,
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _mainDestinations.asMap().entries.map((entry) {
            final index = entry.key;
            final destination = entry.value;
            final isSelected = _getSelectedIndex(context) == index;
            return Expanded(
              child: InkWell(
                onTap: () async {
                  // Vérification connexion pour Profil
                  if (destination.route == '/profile') {
                    final container = ProviderScope.containerOf(context, listen: false);
                    final userId = container.read(userIdProvider);
                    if (userId == null || userId.isEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WelcomeScreen(),
                        ),
                      );
                      return;
                    }
                  }
                  context.go(destination.route);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      destination.svgAsset,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        isSelected ? bibleBlueColor : Colors.grey,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? bibleBlueColor : Colors.grey,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          ),
        ),
      ),
    );
  }
  
  // Méthode pour déterminer l'index sélectionné en fonction de l'URL actuelle
  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _mainDestinations.length; i++) {
      if (location.startsWith(_mainDestinations[i].route)) {
        return i;
      }
    }
    return 0; // Par défaut, retourner l'accueil
  }
}

/// Classe pour définir une destination de navigation
class _NavigationDestination {
  final String route;
  final String svgAsset;
  final String label;

  const _NavigationDestination({
    required this.route,
    required this.svgAsset,
    required this.label,
  });
}
