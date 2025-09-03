import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:emb_mission/core/router/app_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;
  bool _showingSplash = true;
  Timer? _splashTimer;
  Timer? _autoScrollTimer; // Timer pour le défilement automatique
  
  // Contrôleur pour la vidéo du logo
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  
  Future<void> _initializeVideo() async {
    try {
      // Initialiser le contrôleur vidéo
      _videoController = VideoPlayerController.asset('assets/images/Annitation_LOGO.mp4');
      
      // Attendre que la vidéo soit initialisée
      await _videoController!.initialize();
      
      // Obtenir la durée de la vidéo
      final videoDuration = _videoController!.value.duration;
      
      // Configurer la vidéo pour qu'elle se répète
      await _videoController!.setLooping(false);
      
      // Démarrer la lecture de la vidéo
      await _videoController!.play();
      
      setState(() {
        _isVideoInitialized = true;
        _isVideoPlaying = true;
      });
      
      // Timer synchronisé avec la durée de la vidéo
      _splashTimer = Timer(videoDuration + const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showingSplash = false;
            _isVideoPlaying = false;
          });
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
          // Démarrer le défilement automatique après la transition
          _startAutoScroll();
        }
      });
      
      print('✅ Vidéo du logo initialisée avec succès. Durée: ${videoDuration.inMilliseconds}ms');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de la vidéo: $e');
      // Fallback : utiliser le timer original de 3 secondes
      _splashTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showingSplash = false;
          });
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _splashTimer?.cancel();
    _autoScrollTimer?.cancel(); // Annuler le timer de défilement automatique
    _videoController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      if (page == 0) {
        _showingSplash = true;
      } else {
        _showingSplash = false;
      }
    });
    
    // Démarrer le défilement automatique après le changement de page
    _startAutoScroll();
  }
  
  // Méthode pour démarrer le défilement automatique
  void _startAutoScroll() {
    // Annuler le timer précédent s'il existe
    _autoScrollTimer?.cancel();
    
    // Si on est sur la dernière page, marquer l'onboarding comme terminé après 3 secondes
    if (_currentPage >= _numPages - 1) {
      _autoScrollTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _completeOnboarding();
        }
      });
      return;
    }
    
    // Démarrer le défilement automatique après 3 secondes
    _autoScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _currentPage < _numPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Sur la dernière page, marquer l'onboarding comme terminé et naviguer directement
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    print('Début de _completeOnboarding');
    try {
      // Utiliser le notifier pour mettre à jour l'état d'onboarding
      final onboardingStatus = ref.read(onboardingStatusProvider);
      await onboardingStatus.setCompleted(true);
      print('✅ Onboarding marqué comme terminé via notifier');
      
      // Vérifier que la valeur est bien sauvegardée
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool('onboarding_completed');
      print('🔍 Vérification - onboarding_completed sauvegardé: $savedValue');
      
      // Navigation directe vers l'écran d'accueil
      if (mounted) {
        print('Tentative de navigation vers /home');
        try {
          // Utiliser context.go qui est la méthode recommandée avec go_router
          context.go('/home');
          print('Navigation vers /home réussie');
        } catch (e) {
          print('Erreur de navigation: $e');
          // Plan B: essayer avec un délai
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              try {
                context.go('/home');
                print('Navigation différée réussie');
              } catch (e2) {
                print('Navigation différée échouée: $e2');
              }
            }
          });
        }
      }
    } catch (e) {
      print('Erreur lors de la complétion de l\'onboarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _showingSplash ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Bouton Passer
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text(
              'Passer',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Pages d'onboarding
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: _showingSplash ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            children: [
              _buildSplashScreen(),
              _buildSecondPage(),
              _buildThirdPage(),
            ],
          ),
          // Indicateurs de page (sauf pour l'écran de splash)
          if (!_showingSplash)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _numPages,
                  (index) => _buildPageIndicator(index),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isActive = index == _currentPage;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: isActive ? 10 : 8,
      height: isActive ? 10 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
        border: isActive ? Border.all(color: Colors.white, width: 1) : null,
      ),
    );
  }

  // Écran de splash - Introduction
  Widget _buildSplashScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF64B5F6),
            Color(0xFF1976D2),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Logo EMB animé
            Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: _isVideoInitialized && _videoController != null
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : _buildFallbackLogo(),
              ),
            ),
            const SizedBox(height: 40),
            const Spacer(flex: 3),
            const Text(
              'EMB Mission',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ministère Chrétien Francophone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40), // Espace pour les indicateurs de page
          ],
        ),
      ),
    );
  }
  
  // Logo de fallback si la vidéo ne charge pas
  Widget _buildFallbackLogo() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'emb',
            style: TextStyle(
              color: Color(0xFFE53935),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Matthieu 28:19-20',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Mission',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Image.asset(
            'assets/images/colombe.png',
            height: 24,
            width: 24,
          ),
        ],
      ),
    );
  }

  // Deuxième page d'onboarding - Bienvenue dans EMB Mission
  Widget _buildSecondPage() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 5), // Réduire le padding du bas
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Utiliser min pour éviter le débordement
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cercle bleu avec icône de cœur
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2196F3),
              ),
              child: const Icon(
                Icons.favorite,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            
            // Titre
            const Text(
              'Bienvenue dans EMB Mission',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Description
            const Text(
              'Rejoignez notre communauté chrétienne francophone et accédez à des contenus inspirants pour nourrir votre foi au quotidien.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30), // Réduire l'espace
            
            // Première section - Radio & TV en direct
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE3F2FD),
                    ),
                    child: const Icon(
                      Icons.radio,
                      color: Color(0xFF2196F3),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radio & TV en direct',
                          style: TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Accédez aux émissions en direct et aux archives',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10), // Réduire l'espace
            
            // Deuxième section - Communauté active
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 5), // Ajout d'une marge inférieure de 5 pixels
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8F5E9),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Color(0xFF4CAF50),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Communauté active',
                          style: TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Partagez et échangez avec d\'autres croyants',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30), // Réduire l'espace
            
            // Boutons Précédent et Suivant
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Précédent'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    child: const Text('Suivant'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Troisième page d'onboarding - Fonctionnalités principales
  Widget _buildThirdPage() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 5), // Réduire le padding du bas
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Utiliser min pour éviter le débordement
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // Titre
            const Text(
              'Fonctionnalités principales',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Description
            const Text(
              'Découvrez tout ce que EMB Mission vous offre',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Carte 1 - Diffusion Live
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2196F3),
                        ),
                        child: const Icon(
                          Icons.live_tv,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Diffusion Live',
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Accédez aux émissions en direct et aux archives vidéo et audio',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Carte 2 - Bible Interactive
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF9C27B0),
                        ),
                        child: const Icon(
                          Icons.book,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Bible Interactive',
                        style: TextStyle(
                          color: Color(0xFF4A148C),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lisez la Bible, prenez des notes et partagez des versets',
                    style: TextStyle(
                      color: Color(0xFF6A1B9A),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Carte 3 - Espace Prière
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4CAF50),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Espace Prière',
                        style: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Suivez des guides de prière et partagez vos intentions',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Boutons Précédent et Suivant
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Précédent'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    child: const Text('Suivant'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
