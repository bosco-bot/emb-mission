import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:emb_mission/core/services/content_service.dart';
import 'package:emb_mission/core/models/testimony.dart';
import 'package:emb_mission/features/testimonies/screens/testimonies_screen.dart';
import 'package:emb_mission/core/services/auth_service.dart';

/// Écran pour ajouter un nouveau témoignage
class NewTestimonyScreen extends ConsumerStatefulWidget {
  const NewTestimonyScreen({super.key});

  @override
  ConsumerState<NewTestimonyScreen> createState() => _NewTestimonyScreenState();
}

class _NewTestimonyScreenState extends ConsumerState<NewTestimonyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  
  InputMode _selectedInputMode = InputMode.text;
  bool _isSubmitting = false;
  int _characterCount = 0;
  
  // Données utilisateur (à récupérer depuis un provider dans une vraie application)
  final String _userName = "Marie Dubois";
  final String _userAvatar = "assets/images/avatar.png";
  
  final Map<TestimonyCategory, Map<String, dynamic>> _categoryData = {
    TestimonyCategory.healing: {
      'icon': 'assets/images/coeur.svg',
      'color': const Color(0xFF64B5F6),
      'label': 'Guérison',
    },
    TestimonyCategory.prayer: {
      'icon': 'assets/images/priere.svg',
      'color': const Color(0xFF9E9E9E),
      'label': 'Prière',
    },
    TestimonyCategory.family: {
      'icon': 'assets/images/famille.svg',
      'color': const Color(0xFF9E9E9E),
      'label': 'Famille',
    },
    TestimonyCategory.work: {
      'icon': 'assets/images/travail.svg',
      'color': const Color(0xFF9E9E9E),
      'label': 'Travail',
    },
  };
  
  final Map<InputMode, Map<String, dynamic>> _inputModeData = {
    InputMode.text: {
      'icon': Icons.keyboard,
      'label': 'Texte',
    },
    InputMode.audio: {
      'icon': Icons.mic,
      'label': 'Audio',
    },
  };
  
  // Audio recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    print('FICHIER new_testimony_screen.dart CHARGE');
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onDurationChanged.listen((d) {
      setState(() => _audioDuration = d);
    });
    _audioPlayer!.onPositionChanged.listen((p) {
      setState(() => _audioPosition = p);
    });
    _audioPlayer!.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _audioPosition = Duration.zero;
      });
    });
  }
  
  @override
  void dispose() {
    _contentController.dispose();
    _audioRecorder.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final lightBlue = const Color(0xFF64B5F6);
    final categoriesAsync = ref.watch(testimonyCategoriesProvider);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: lightBlue,
        elevation: 0,
        title: const Text('Nouveau Message', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            // Ajout d'un espace entre l'AppBar et le mode de saisie
            const SizedBox(height: 24),
            // Mode de saisie
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mode de saisie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInputModeButton(InputMode.text),
                      const SizedBox(width: 8),
                      _buildInputModeButton(InputMode.audio),
                    ],
                  ),
                ],
              ),
            ),
            
            // Contenu du témoignage
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Votre témoignage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  if (_selectedInputMode == InputMode.text)
                    TextField(
                      controller: _contentController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Votre témoignage',
                        hintText: 'Partagez votre expérience...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (_selectedInputMode == InputMode.audio)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _toggleRecording,
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: _isRecording ? Colors.red : Colors.purple[200],
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isRecording
                                  ? 'Enregistrement en cours...'
                                  : (_audioPath != null ? 'Enregistrement prêt !' : 'Appuyez pour enregistrer'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            if (_audioPath != null && !_isRecording)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                                    onPressed: _deleteAudio,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            ),
            
            // Aperçu
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Aperçu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildPreviewAvatar(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedInputMode == InputMode.text && _contentController.text.trim().isNotEmpty)
                          Text(
                            _contentController.text,
                            style: const TextStyle(fontSize: 15),
                          )
                        else if (_selectedInputMode == InputMode.audio && _audioPath != null && !_isRecording)
                          Row(
                            children: [
                              const Icon(Icons.mic, color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              const Text('Un audio est prêt !', style: TextStyle(fontSize: 15)),
                              if (_audioPath != null)
                                IconButton(
                                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.purple),
                                  onPressed: _isPlaying ? _stopAudio : _playAudio,
                                ),
                            ],
                          )
                        else
                          Text('Votre témoignage apparaîtra ici...', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bouton de publication
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTestimony,
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Publier le message',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),

    );
  }
  

  
  // Méthode pour construire un bouton de mode de saisie
  Widget _buildInputModeButton(InputMode mode) {
    final isSelected = _selectedInputMode == mode;
    final data = _inputModeData[mode]!;
    final color = isSelected ? const Color(0xFF64B5F6) : Colors.grey.shade100;
    final textColor = isSelected ? Colors.white : Colors.grey.shade700;
    final iconColor = isSelected ? Colors.white : Colors.grey.shade700;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedInputMode = mode;
          });
        },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                data['icon'] as IconData,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Text(
                data['label'] as String,
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
  

  
  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(
      10,
      (index) => chars[random.nextInt(chars.length)],
      growable: false,
    ).join();
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      String filePath = await getApplicationDocumentsDirectory()
          .then((value) => '${value.path}/${_generateRandomId()}.m4a');
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
      setState(() {
        _isRecording = true;
        _audioPath = filePath;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission micro refusée. Activez-la dans les paramètres du téléphone.')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }
  
  void _submitTestimony() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      // Récupérer l'ID utilisateur (à adapter selon ton provider ou méthode d'auth)
      final userId = ref.read(userIdProvider);
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez vous connecter.')),
          );
        }
        setState(() { _isSubmitting = false; });
        return;
      }
      
      // ✅ VALIDATION DES CHAMPS SELON LE MODE DE SAISIE
      if (_selectedInputMode == InputMode.text) {
        // Mode texte : vérifier que le contenu n'est pas vide
        if (_contentController.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Veuillez saisir votre témoignage avant de publier.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() { _isSubmitting = false; });
          return;
        }
      } else if (_selectedInputMode == InputMode.audio) {
        // Mode audio : vérifier qu'un audio est enregistré
        if (_audioPath == null || !File(_audioPath!).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Veuillez enregistrer un audio avant de publier.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() { _isSubmitting = false; });
          return;
        }
      }
      
      String? audioBase64;
      String content = '';
      if (_selectedInputMode == InputMode.audio && _audioPath != null && File(_audioPath!).existsSync()) {
        final audioFile = File(_audioPath!);
        final audioBytes = await audioFile.readAsBytes();
        audioBase64 = 'data:audio/mp3;base64,' + base64Encode(audioBytes);
        content = '';
      } else if (_selectedInputMode == InputMode.text) {
        content = _contentController.text.trim();
        audioBase64 = null;
      }
      final uri = Uri.parse('https://embmission.com/mobileappebm/api/postforums');
      Map<String, dynamic> requestData = {
        'id_user': userId,
        'content': content,
        'audio_url': audioBase64 ?? '',
      };
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['success'] == 'true') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message publié avec succès!')),
            );
            context.pop();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: ${data['message'] ?? 'Échec de l\'envoi.'}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur réseau: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath == null) return;
    _audioPlayer ??= AudioPlayer();
    await _audioPlayer!.play(DeviceFileSource(_audioPath!));
    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _stopAudio() async {
    await _audioPlayer?.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  void _deleteAudio() {
    setState(() {
      _audioPath = null;
      _isPlaying = false;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget buildPreviewAvatar() {
    final avatarUrl = ref.watch(userAvatarProvider);
    print('DEBUG AVATAR URL: ' + (avatarUrl ?? 'null'));
    return CircleAvatar(
      radius: 32,
      backgroundColor: Colors.transparent,
      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? NetworkImage(avatarUrl)
          : const AssetImage('assets/images/avatar.png') as ImageProvider,
    );
  }
}
