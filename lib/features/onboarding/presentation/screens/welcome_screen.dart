import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/register_screen.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/login_screen.dart';
import 'package:flutter/services.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color embBlue = const Color(0xFF64B5F6); // même bleu que sur la home

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu principal centré
            Column(
          children: [
            const Spacer(flex: 2),
            // Logo dans un cercle bleu clair, style page d'accueil
            Container(
              width: 200,
              height: 200,
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Message de bienvenue
            const Text(
              'Bienvenue sur EMB Mission',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Matthieu 28:19-20',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const Spacer(flex: 2),
            // Boutons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: embBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: embBlue,
                        side: BorderSide(color: embBlue, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text("S'inscrire", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Texte d'information en bas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
              child: Text(
                "En continuant vous confirmez avoir lu et accepté les conditions d'utilisation ainsi que la politique de confidentialité de EMB Mission.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            // Bouton croix en haut à gauche
            Positioned(
              top: 12,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, size: 32, color: Colors.black),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                tooltip: 'Fermer',
              ),
            ),
          ],
        ),
      ),
    );
  }
} 