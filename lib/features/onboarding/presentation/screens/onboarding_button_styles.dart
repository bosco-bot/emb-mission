import 'package:flutter/material.dart';
import '../constants/onboarding_colors.dart';

/// Classe utilitaire pour les styles de boutons dans l'onboarding
class OnboardingButtonStyles {
  /// Style pour les boutons "Suivant" dans l'onboarding
  static ButtonStyle nextButtonStyle() {
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
  
  /// Style pour les boutons "Précédent" dans l'onboarding
  static ButtonStyle previousButtonStyle() {
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
}
