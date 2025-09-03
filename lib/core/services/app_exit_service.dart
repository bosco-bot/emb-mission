import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/providers/radio_player_provider.dart';

/// Service centralisé pour gérer la sortie de l'application
/// Empêche la fermeture accidentelle et gère les confirmations de sortie
class AppExitService {
  static final AppExitService _instance = AppExitService._internal();
  factory AppExitService() => _instance;
  AppExitService._internal();

  /// Vérifie si l'utilisateur peut quitter l'application
  /// Retourne true si la sortie est autorisée, false sinon
  Future<bool> canExitApp(BuildContext context, WidgetRef ref) async {
    try {
      // 1. Vérifier si la radio est en cours de lecture
      if (await _isRadioPlaying(ref)) {
        final shouldExit = await _showRadioPlayingExitDialog(context);
        if (!shouldExit) return false;
      }

      // 2. Vérifier s'il y a des données non sauvegardées
      if (await _hasUnsavedData()) {
        final shouldExit = await _showUnsavedDataExitDialog(context);
        if (!shouldExit) return false;
      }

      // 3. Vérifier s'il y a des téléchargements en cours
      if (await _hasActiveDownloads()) {
        final shouldExit = await _showDownloadsExitDialog(context);
        if (!shouldExit) return false;
      }

      // 4. Vérifier s'il y a des tâches en arrière-plan
      if (await _hasBackgroundTasks()) {
        final shouldExit = await _showBackgroundTasksExitDialog(context);
        if (!shouldExit) return false;
      }

      // Toutes les vérifications sont passées, autoriser la sortie
      return true;
    } catch (e) {
      print('[APP_EXIT] ❌ Erreur lors de la vérification de sortie: $e');
      // En cas d'erreur, autoriser la sortie pour ne pas bloquer l'utilisateur
      return true;
    }
  }

  /// Vérifie si la radio est en cours de lecture
  Future<bool> _isRadioPlaying(WidgetRef ref) async {
    try {
      // Utiliser le provider radio pour vérifier l'état
      final radioPlaying = ref.read(radioPlayingProvider);
      final radioStopAll = ref.read(radioStopAllProvider);
      
      // La radio est en cours si radioPlaying est true ET radioStopAll est false
      final isPlaying = radioPlaying && !radioStopAll;
      
      print('[APP_EXIT] 📻 État radio - Playing: $radioPlaying, StopAll: $radioStopAll, IsPlaying: $isPlaying');
      
      return isPlaying;
    } catch (e) {
      print('[APP_EXIT] ❌ Erreur vérification radio: $e');
      return false;
    }
  }

  /// Vérifie s'il y a des données non sauvegardées
  Future<bool> _hasUnsavedData() async {
    try {
      // Vérifier les formulaires en cours d'édition
      // Vérifier les commentaires non envoyés
      // Vérifier les préférences non sauvegardées
      return false; // Placeholder - sera implémenté selon les besoins
    } catch (e) {
      print('[APP_EXIT] ❌ Erreur vérification données: $e');
      return false;
    }
  }

  /// Vérifie s'il y a des téléchargements en cours
  Future<bool> _hasActiveDownloads() async {
    try {
      // Vérifier les téléchargements de contenu
      // Vérifier les mises à jour en cours
      return false; // Placeholder - sera implémenté selon les besoins
    } catch (e) {
      print('[APP_EXIT] ❌ Erreur vérification téléchargements: $e');
      return false;
    }
  }

  /// Vérifie s'il y a des tâches en arrière-plan
  Future<bool> _hasBackgroundTasks() async {
    try {
      // Vérifier la synchronisation des données
      // Vérifier les notifications en cours
      return false; // Placeholder - sera implémenté selon les besoins
    } catch (e) {
      print('[APP_EXIT] ❌ Erreur vérification tâches: $e');
      return false;
    }
  }

  /// Dialogue de confirmation si la radio est en cours de lecture
  Future<bool> _showRadioPlayingExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.radio, color: Colors.orange),
            SizedBox(width: 8),
            Text('Radio en cours de lecture'),
          ],
        ),
        content: Text(
          'La radio est actuellement en cours de lecture. '
          'Voulez-vous vraiment quitter l\'application ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Continuer à écouter'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Quitter quand même'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Dialogue de confirmation s'il y a des données non sauvegardées
  Future<bool> _showUnsavedDataExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.save, color: Colors.blue),
            SizedBox(width: 8),
            Text('Données non sauvegardées'),
          ],
        ),
        content: Text(
          'Vous avez des données non sauvegardées. '
          'Voulez-vous vraiment quitter sans sauvegarder ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Sauvegarder d\'abord'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Quitter sans sauvegarder'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Dialogue de confirmation s'il y a des téléchargements en cours
  Future<bool> _showDownloadsExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 8),
            Text('Téléchargements en cours'),
          ],
        ),
        content: Text(
          'Vous avez des téléchargements en cours. '
          'Voulez-vous vraiment quitter l\'application ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Attendre la fin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Quitter quand même'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Dialogue de confirmation s'il y a des tâches en arrière-plan
  Future<bool> _showBackgroundTasksExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sync, color: Colors.purple),
            SizedBox(width: 8),
            Text('Tâches en cours'),
          ],
        ),
        content: Text(
          'Des tâches sont en cours d\'exécution en arrière-plan. '
          'Voulez-vous vraiment quitter l\'application ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Attendre la fin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Quitter quand même'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Méthode pour forcer la sortie (utilisée dans les cas d'urgence)
  Future<bool> forceExit(BuildContext context) async {
    print('[APP_EXIT] 🚨 Sortie forcée de l\'application');
    return true;
  }
}

/// Provider pour le service de sortie d'application
final appExitServiceProvider = Provider<AppExitService>((ref) {
  return AppExitService();
});
