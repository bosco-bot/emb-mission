import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outil pour réinitialiser l'état de l'onboarding
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // Afficher l'état actuel
  final bool currentState = prefs.getBool('onboarding_completed') ?? false;
  print('État actuel de onboarding_completed: $currentState');
  
  // Réinitialiser l'état de l'onboarding
  await prefs.setBool('onboarding_completed', false);
  
  // Vérifier que la réinitialisation a fonctionné
  final bool newState = prefs.getBool('onboarding_completed') ?? false;
  print('Nouvel état de onboarding_completed: $newState');
  
  if (newState == false) {
    print('✅ Onboarding réinitialisé avec succès !');
    print('Vous verrez maintenant l\'écran d\'onboarding au prochain démarrage de l\'application.');
  } else {
    print('❌ Échec de la réinitialisation de l\'onboarding.');
  }
  
  // Afficher tous les éléments dans SharedPreferences pour débogage
  print('\nContenu de SharedPreferences:');
  final keys = prefs.getKeys();
  for (var key in keys) {
    print('$key: ${prefs.get(key)}');
  }
}
