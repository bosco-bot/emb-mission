import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;
  bool _showingSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    // Démarrer un timer pour passer automatiquement à la deuxième page après 3 secondes
    _splashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showingSplash = false;
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _splashTimer?.cancel();
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
    // Marquer l'onboarding comme terminé
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    print('Onboarding marqué comme terminé: ${prefs.getBool('onboarding_completed')}');
    
    // Navigation directe vers l'écran d'accueil
    if (mounted) {
      try {
        GoRouter.of(context).go('/');
      } catch (e) {
        print('Erreur avec GoRouter: $e');
        // Essayer de forcer un rebuild du router
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            GoRouter.of(context).go('/');
          }
        });
      }
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
            // Logo EMB
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Center(
                child: Text(
                  'emb',
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Matthieu 28:19-20',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Mission',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  // Deuxième page d'onboarding - Bienvenue dans EMB Mission
  Widget _buildSecondPage() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: SingleChildScrollView(
        child: Column(
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
            const SizedBox(height: 40),
            
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
            const SizedBox(height: 16),
            
            // Deuxième section - Communauté active
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
            const SizedBox(height: 60),
            
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
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            
            // Titre
            const Text(
              'Fonctionnalités principales',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            const Text(
              'Découvrez tout ce que EMB Mission vous offre',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            
            // Carte 1 - Diffusion Live
            Container(
              margin: const EdgeInsets.only(bottom: 16),
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
              margin: const EdgeInsets.only(bottom: 16),
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
              margin: const EdgeInsets.only(bottom: 16),
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
            
            const SizedBox(height: 40),
            
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
