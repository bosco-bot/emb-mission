import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class RadioConnectionTester extends StatefulWidget {
  const RadioConnectionTester({super.key});

  @override
  State<RadioConnectionTester> createState() => _RadioConnectionTesterState();
}

class _RadioConnectionTesterState extends State<RadioConnectionTester> {
  final AudioPlayer _player = AudioPlayer();
  String _status = 'Prêt';
  String _error = '';
  bool _isTesting = false;
  List<String> _logs = [];

  final List<Map<String, String>> _testUrls = [
    {
      'name': 'EMB Mission Radio',
      'url': 'https://stream.zeno.fm/rxi8n979ui1tv',
    },
    {
      'name': 'Radio France FIP',
      'url': 'https://icecast.radiofrance.fr/fip-hifi.aac',
    },
    {
      'name': 'SomaFM Groove Salad',
      'url': 'https://ice1.somafm.com/groovesalad-128-mp3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  void _setupPlayer() {
    _player.playerStateStream.listen((state) {
      setState(() {
        _status = 'État: ${state.processingState}, Lecture: ${state.playing}';
        _addLog('État changé: ${state.processingState} - Lecture: ${state.playing}');
      });
    });

    _player.positionStream.listen((position) {
      _addLog('Position: ${position.inSeconds}s');
    });

    _player.bufferedPositionStream.listen((buffered) {
      _addLog('Buffer: ${buffered.inSeconds}s');
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 20) {
        _logs.removeAt(0);
      }
    });
  }

  Future<void> _testUrl(String name, String url) async {
    setState(() {
      _isTesting = true;
      _error = '';
      _addLog('Test de $name: $url');
    });

    try {
      // Test de connectivité HTTP
      _addLog('Test de connectivité HTTP...');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout HTTP');
        },
      );
      _addLog('HTTP Status: ${response.statusCode}');

      // Test de lecture audio
      _addLog('Test de lecture audio...');
      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: false,
      );
      await _player.play();

      // Attendre 10 secondes pour voir si la lecture continue
      await Future.delayed(const Duration(seconds: 10));

      if (_player.playing) {
        _addLog('✅ Test réussi: $name fonctionne correctement');
        setState(() {
          _status = 'Test réussi: $name';
        });
      } else {
        throw Exception('La lecture s\'est arrêtée après 10 secondes');
      }

    } catch (e) {
      _addLog('❌ Erreur: $e');
      setState(() {
        _error = 'Erreur: $e';
        _status = 'Test échoué: $name';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Connexion Radio'),
        backgroundColor: const Color(0xFF4CB6FF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _error.isNotEmpty ? Colors.red.shade50 : Colors.green.shade50,
                border: Border.all(
                  color: _error.isNotEmpty ? Colors.red.shade200 : Colors.green.shade200,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statut: $_status',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // URLs de test
            const Text(
              'URLs de Test:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            ..._testUrls.map((test) => Card(
              child: ListTile(
                title: Text(test['name']!),
                subtitle: Text(test['url']!),
                trailing: _isTesting 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () => _testUrl(test['name']!, test['url']!),
                      child: const Text('Tester'),
                    ),
              ),
            )),
            
            const SizedBox(height: 16),
            
            // Logs
            const Text(
              'Logs:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[_logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
} 