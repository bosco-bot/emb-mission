import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/app_exit_service.dart';

/// Widget wrapper qui protège l'application contre la fermeture accidentelle
/// Utilise WillPopScope pour intercepter le bouton retour du téléphone
class AppExitProtection extends ConsumerWidget {
  final Widget child;
  final bool enableProtection;

  const AppExitProtection({
    super.key,
    required this.child,
    this.enableProtection = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enableProtection) {
      return child;
    }

    return WillPopScope(
      onWillPop: () async {
        print('🔙 Bouton retour pressé - vérification de sortie...');
        
        // Utiliser le service centralisé pour vérifier si la sortie est autorisée
        final appExitService = ref.read(appExitServiceProvider);
        final canExit = await appExitService.canExitApp(context, ref);
        
        if (canExit) {
          print('✅ Sortie autorisée - l\'app va en arrière-plan');
          // ✅ CRITIQUE: Ne pas fermer complètement l'app, juste la mettre en arrière-plan
          // L'app restera active grâce aux services en arrière-plan
        } else {
          print('❌ Sortie bloquée - l\'app reste active');
        }
        
        return canExit;
      },
      child: child,
    );
  }
}

/// Version avancée avec protection conditionnelle
class ConditionalAppExitProtection extends ConsumerWidget {
  final Widget child;
  final Future<bool> Function()? customExitCheck;
  final bool Function()? shouldProtect;

  const ConditionalAppExitProtection({
    super.key,
    required this.child,
    this.customExitCheck,
    this.shouldProtect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WillPopScope(
      onWillPop: () async {
        // 1. Vérifier si la protection doit être active
        if (shouldProtect != null && !shouldProtect!()) {
          return true; // Pas de protection, autoriser la sortie
        }

        // 2. Utiliser une vérification personnalisée si fournie
        if (customExitCheck != null) {
          return await customExitCheck!();
        }

        // 3. Utiliser le service centralisé par défaut
        final appExitService = ref.read(appExitServiceProvider);
        return await appExitService.canExitApp(context, ref);
      },
      child: child,
    );
  }
}

/// Hook pour utiliser la protection de sortie dans n'importe quel widget
mixin AppExitProtectionMixin<T extends StatefulWidget> on State<T> {
  Future<bool> onWillPop() async {
    // Cette méthode peut être override par les widgets enfants
    // pour implémenter une logique de protection spécifique
    return true;
  }

  Widget wrapWithExitProtection(Widget child) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: child,
    );
  }
}
