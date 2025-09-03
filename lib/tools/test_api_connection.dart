import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestApiConnection extends StatefulWidget {
  const TestApiConnection({super.key});

  @override
  State<TestApiConnection> createState() => _TestApiConnectionState();
}

class _TestApiConnectionState extends State<TestApiConnection> {
  String _status = 'En attente...';
  bool _isLoading = false;
  List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Test en cours...';
      _logs.clear();
    });

    try {
      _addLog('🔄 Début du test de connectivité API');
      
      // Test 1: Endpoint de santé
      _addLog('🔍 Test de l\'endpoint /health');
      try {
        final healthResponse = await http.get(
          Uri.parse('https://embmission.com/mobileappebm/api/health'),
        ).timeout(const Duration(seconds: 10));
        
        _addLog('✅ /health - Status: ${healthResponse.statusCode}');
        _addLog('📥 Body: ${healthResponse.body}');
      } catch (e) {
        _addLog('❌ /health - Erreur: $e');
      }

      // Test 2: Endpoint d'export (sans user_id pour voir la réponse d'erreur)
      _addLog('🔍 Test de l\'endpoint /export/request (sans user_id)');
      try {
        final exportResponse = await http.post(
          Uri.parse('https://embmission.com/mobileappebm/api/export/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        ).timeout(const Duration(seconds: 15));
        
        _addLog('✅ /export/request - Status: ${exportResponse.statusCode}');
        _addLog('📥 Body: ${exportResponse.body}');
      } catch (e) {
        _addLog('❌ /export/request - Erreur: $e');
      }

      // Test 3: Endpoint d'export avec user_id invalide
      _addLog('🔍 Test de l\'endpoint /export/request (avec user_id invalide)');
      try {
        final exportResponse2 = await http.post(
          Uri.parse('https://embmission.com/mobileappebm/api/export/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': 'test_invalid_user'}),
        ).timeout(const Duration(seconds: 15));
        
        _addLog('✅ /export/request (invalid) - Status: ${exportResponse2.statusCode}');
        _addLog('📥 Body: ${exportResponse2.body}');
      } catch (e) {
        _addLog('❌ /export/request (invalid) - Erreur: $e');
      }

      setState(() {
        _status = 'Test terminé';
        _isLoading = false;
      });
      
    } catch (e) {
      _addLog('💥 Erreur générale: $e');
      setState(() {
        _status = 'Erreur lors du test';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test API Export'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bouton de test
            ElevatedButton(
              onPressed: _isLoading ? null : _testApiConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Test en cours...'),
                      ],
                    )
                  : const Text('Tester la connectivité API'),
            ),
            
            const SizedBox(height: 16),
            
            // Statut
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status.contains('Erreur') ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _status.contains('Erreur') ? Colors.red.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                'Statut: $_status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _status.contains('Erreur') ? Colors.red.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logs de test:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

