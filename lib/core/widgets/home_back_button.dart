import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bouton de retour personnalisé qui ramène toujours à l'écran d'accueil
class HomeBackButton extends StatelessWidget {
  /// Couleur de l'icône du bouton
  final Color? color;

  /// Constructeur
  const HomeBackButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      color: color,
      onPressed: () => context.go('/home'),
      tooltip: 'Retour à l\'accueil',
    );
  }
}
