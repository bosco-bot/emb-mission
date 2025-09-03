import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../constants/onboarding_colors.dart';

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
  
  // Méthodes de style pour les boutons
  ButtonStyle _nextButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: OnboardingColors.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
  
  ButtonStyle _previousButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: OnboardingColors.textGrey,
      elevation: 0,
      side: BorderSide(color: OnboardingColors.borderGrey),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
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
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    // Marquer l'onboarding comme terminé
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    // Naviguer vers l'écran d'accueil
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          
          // Éléments de navigation conditionnels (pas sur l'écran de splash)
          if (!_showingSplash) ...[  
            // Logo EMB en haut à gauche ou flèche retour
            Positioned(
              top: 24,
              left: 24,
              child: _currentPage == 1 ? Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: OnboardingColors.primaryBlue,
                ),
                child: const Center(
                  child: Text(
                    'emb',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ) : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
            
            // Bouton passer en haut à droite
            Positioned(
              top: 32,
              right: 24,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text(
                  'Passer',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          
          // Indicateurs de page en bas pour l'écran de splash, en haut pour les autres
          Positioned(
            top: _showingSplash ? null : 40,
            bottom: _showingSplash ? 30 : null,
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
          colors: [OnboardingColors.lightBlue, OnboardingColors.darkBlue],
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
                    color: OnboardingColors.embRed,
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
            const SizedBox(height: 6),
            const Text(
              'Mission',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            SvgPicture.asset(
              'assets/images/colombe.svg',
              width: 48,
              height: 48,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const Spacer(flex: 3),
            const Text(
              'EMB Mission',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ministère Chrétien Francophone',
              style: TextStyle(
                color: Colors.white70,
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
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Cercle bleu avec icône de cœur
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [OnboardingColors.lightBlue, OnboardingColors.darkBlue],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/coeur.svg',
                width: 40,
                height: 40,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Titre
          const Text(
            'Bienvenue dans EMB Mission',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingColors.textBlack,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Description
          const Text(
            'Rejoignez notre communauté chrétienne francophone et découvrez un espace de partage, de prière et de croissance spirituelle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingColors.textGrey,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          
          // Section Radio & TV
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: OnboardingColors.green,
                ),
                child: const Icon(
                  Icons.tv,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Radio & TV en direct',
                      style: TextStyle(
                        color: OnboardingColors.textBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Écoutez nos programmes 24h/24',
                      style: TextStyle(
                        color: OnboardingColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Section Communauté active
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: OnboardingColors.purple,
                ),
                child: const Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Communauté active',
                      style: TextStyle(
                        color: OnboardingColors.textBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Partagez témoignages et prières',
                      style: TextStyle(
                        color: OnboardingColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          
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
                  style: _previousButtonStyle(),
                  child: const Text(
                    'Précédent',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: _nextButtonStyle(),
                  child: const Text(
                    'Suivant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Troisième page d'onboarding - Fonctionnalités principales
  Widget _buildThirdPage() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flèche de retour en haut à gauche (remplacée par le logo EMB dans le build principal)
          const SizedBox(height: 40),
          
          // Titre
          const Text(
            'Fonctionnalités principales',
            style: TextStyle(
              color: OnboardingColors.textBlack,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Description
          const Text(
            'Découvrez tout ce que l\'application EMB Mission peut vous offrir',
            style: TextStyle(
              color: OnboardingColors.textGrey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          
          // Carte Diffusion Live
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnboardingColors.embRed,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Diffusion Live',
                        style: TextStyle(
                          color: OnboardingColors.textBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Radio et TV en direct avec notifications',
                        style: TextStyle(
                          color: OnboardingColors.textGrey,
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
          
          // Carte Bible Interactive
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnboardingColors.primaryBlue,
                  ),
                  child: const Icon(
                    Icons.book,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Bible Interactive',
                        style: TextStyle(
                          color: OnboardingColors.textBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Plans de lecture et versets quotidiens',
                        style: TextStyle(
                          color: OnboardingColors.textGrey,
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
          
          // Carte Espace Prière
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnboardingColors.green,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Espace Prière',
                        style: TextStyle(
                          color: OnboardingColors.textBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Partagez vos demandes et priez ensemble en communauté',
                        style: TextStyle(
                          color: OnboardingColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          
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
                  style: _previousButtonStyle(),
                  child: const Text(
                    'Précédent',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: _nextButtonStyle(),
                  child: const Text(
                    'Suivant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
