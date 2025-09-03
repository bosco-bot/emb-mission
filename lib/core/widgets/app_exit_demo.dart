import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/widgets/app_exit_protection.dart';

/// Écran de démonstration pour tester la protection de sortie
class AppExitDemoScreen extends ConsumerWidget {
  const AppExitDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppExitProtection(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Démo Protection de Sortie'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête informatif
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Protection de Sortie Active',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cette démo montre comment la protection de sortie fonctionne. '
                      'Appuyez sur le bouton retour de votre téléphone pour tester.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Section de test
              Text(
                'Test de Protection',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Bouton pour simuler une activité en cours
              ElevatedButton.icon(
                onPressed: () {
                  _showTestDialog(context);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Simuler Radio en Cours'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Bouton pour tester la protection conditionnelle
              ElevatedButton.icon(
                onPressed: () {
                  _showConditionalProtectionDemo(context);
                },
                icon: const Icon(Icons.settings),
                label: const Text('Protection Conditionnelle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              Text(
                'Instructions de Test',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildInstructionItem(
                '1',
                'Appuyez sur le bouton retour de votre téléphone',
                Icons.arrow_back,
                Colors.red,
              ),
              
              _buildInstructionItem(
                '2',
                'Observez le dialogue de confirmation',
                Icons.dialog,
                Colors.blue,
              ),
              
              _buildInstructionItem(
                '3',
                'Choisissez de continuer ou quitter',
                Icons.choice,
                Colors.green,
              ),
              
              const Spacer(),
              
              // Note importante
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La protection est active au niveau global ET au niveau de cet écran. '
                        'Testez les deux niveaux !',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.radio, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Test de Protection'),
          ],
        ),
        content: const Text(
          'Ce dialogue simule une activité en cours. '
          'Maintenant, testez le bouton retour de votre téléphone !'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConditionalProtectionDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Protection Conditionnelle'),
          ],
        ),
        content: const Text(
          'Cette fonctionnalité permet d\'activer/désactiver la protection '
          'selon certaines conditions (ex: mode développement, tests, etc.).'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

