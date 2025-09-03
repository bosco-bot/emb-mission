import 'package:flutter/material.dart';

/// Constantes de couleur pour l'onboarding
class OnboardingColors {
  /// Couleur principale bleue pour les boutons et éléments d'accent
  static const Color primaryBlue = Color(0xFF4CB6FF);
  
  /// Couleur de dégradé bleu clair pour le splash screen
  static const Color lightBlue = Color(0xFF64B5F6);
  
  /// Couleur de dégradé bleu foncé pour le splash screen
  static const Color darkBlue = Color(0xFF1976D2);
  
  /// Couleur rouge pour le logo EMB
  static const Color embRed = Color(0xFFE53935);
  
  /// Couleur verte pour les icônes
  static const Color green = Color(0xFF4CAF50);
  
  /// Couleur violette pour les icônes
  static const Color purple = Color(0xFF9C27B0);
}

/// Modèle de données pour une page d'onboarding
class OnboardingPageModel {
  final String title;
  final String subtitle;
  final String description;
  final String imagePath;
  final Color backgroundColor;
  final Color textColor;

  const OnboardingPageModel({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imagePath,
    required this.backgroundColor,
    required this.textColor,
  });
}
