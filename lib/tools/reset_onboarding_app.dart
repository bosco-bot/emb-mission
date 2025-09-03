import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ResetOnboardingApp());
}

class ResetOnboardingApp extends StatelessWidget {
  const ResetOnboardingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Réinitialiser Onboarding',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ResetOnboardingScreen(),
    );
  }
}

class ResetOnboardingScreen extends StatefulWidget {
  const ResetOnboardingScreen({super.key});

  @override
  State<ResetOnboardingScreen> createState() => _ResetOnboardingScreenState();
}

class _ResetOnboardingScreenState extends State<ResetOnboardingScreen> {
  bool? _onboardingCompleted;
  String _prefsContent = '';

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed');
    
    // Récupérer toutes les clés pour débogage
    final keys = prefs.getKeys();
    final prefsContent = StringBuffer();
    for (var key in keys) {
      prefsContent.writeln('$key: ${prefs.get(key)}');
    }
    
    setState(() {
      _onboardingCompleted = onboardingCompleted;
      _prefsContent = prefsContent.toString();
    });
  }

  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Onboarding réinitialisé avec succès!')),
    );
    
    await _checkOnboardingStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réinitialiser Onboarding'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'État actuel de l\'onboarding:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_onboardingCompleted == null)
                      const Text('Chargement...')
                    else
                      Text(
                        'onboarding_completed: $_onboardingCompleted',
                        style: TextStyle(
                          fontSize: 16,
                          color: _onboardingCompleted == true ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _onboardingCompleted == true
                          ? 'L\'onboarding est marqué comme terminé. Vous ne verrez pas l\'écran d\'onboarding au démarrage.'
                          : 'L\'onboarding est marqué comme non terminé. Vous verrez l\'écran d\'onboarding au démarrage.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
              child: const Text('Réinitialiser l\'onboarding'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Contenu de SharedPreferences:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_prefsContent.isEmpty ? 'Aucune donnée' : _prefsContent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
