import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class BatteryOptimizationService {
  static Timer? _checkTimer;
  static bool _hasShownDialog = false;

  static Future<void> requestBatteryOptimizationPermission(BuildContext context) async {
    // Vérifier si l'optimisation de la batterie est activée
    final status = await Permission.ignoreBatteryOptimizations.status;
    
    if (status.isDenied && !_hasShownDialog) {
      _hasShownDialog = true;
      
      // Option 1: Afficher d'abord le message personnalisé
      final shouldShowSystemDialog = await _showCustomPermissionDialog(context);
      
      if (shouldShowSystemDialog && context.mounted) {
        // Ensuite afficher le dialogue système Android
        final result = await Permission.ignoreBatteryOptimizations.request();
        
        if (result.isDenied && context.mounted) {
          _showBatteryOptimizationDialog(context);
        }
      }
    }
    
    // Démarrer la vérification périodique
    _startPeriodicCheck(context);
  }

  static void _startPeriodicCheck(BuildContext context) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isDenied && context.mounted) {
        print('[BATTERY] Optimisation de la batterie activée - peut affecter la radio en arrière-plan');
        // Ne pas montrer le dialogue à chaque fois, juste logger
      }
    });
  }

  // Afficher le message personnalisé en premier
  static Future<bool> _showCustomPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.radio, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Permission requise',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Veuillez autorisez la lecture en arrière plan pour écouter la radio même si l\'écran est éteint. Appuyez sur OK',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Ne pas afficher le dialogue système
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Afficher le dialogue système
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CB6FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    ) ?? false; // Retourner false si l'utilisateur ferme le dialogue
  }



  static void _showBatteryOptimizationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.battery_charging_full, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Autorisez la lecture de la radio en arrière plan.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: const SizedBox.shrink(),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _hasShownDialog = false; // Permettre de redemander plus tard
              },
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openBatteryOptimizationSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CB6FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Autoriser'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _openBatteryOptimizationSettings() async {
    try {
      // Ouvrir les paramètres d'optimisation de la batterie
      await openAppSettings();
    } catch (e) {
      print('[BATTERY] Erreur lors de l\'ouverture des paramètres: $e');
    }
  }

  static Future<bool> isBatteryOptimizationEnabled() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      print('[BATTERY] Erreur lors de la vérification: $e');
      return false;
    }
  }

  static Future<void> checkAndRequestPermission(BuildContext context) async {
    final isEnabled = await isBatteryOptimizationEnabled();
    if (!isEnabled && context.mounted) {
      await requestBatteryOptimizationPermission(context);
    }
  }

  static void dispose() {
    _checkTimer?.cancel();
    _hasShownDialog = false;
  }
} 