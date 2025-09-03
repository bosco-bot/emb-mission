import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/widgets/home_back_button.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../features/onboarding/presentation/screens/welcome_screen.dart';
import 'dart:async';
import '../../../core/providers/radio_player_provider.dart';
import 'package:flutter/services.dart';

class RadioScreen extends ConsumerStatefulWidget {
  final String? streamUrl;
  final String radioName;
  final Function(bool)? onPlayStateChanged;
  final bool autoStart;

  const RadioScreen({
    super.key,
    this.streamUrl,
    required this.radioName,
    this.onPlayStateChanged,
    this.autoStart = true,
  });

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> with WidgetsBindingObserver {
  late AudioPlayer _audioPlayer;
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  Timer? _onlineUsersTimer;
  
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  bool _isSendingMessage = false;
  int _onlineUsers = 0;
  double _volume = 0.5;
  
  static const String embMissionRadioUrl = 'https://stream.zeno.fm/rxi8n979ui1tv';
  static const MethodChannel _notificationChannel = MethodChannel('com.embmission.android_background');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _audioPlayer = AudioPlayer();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    
    // ✅ SUPPRIMÉ: Démarrage automatique au lancement de l'app
    print('[RADIO] 🚫 Démarrage automatique supprimé au lancement de l\'app');
    
    // Charger les messages du chat
    ref.read(chatMessagesProvider.notifier).loadMessages();
    ref.read(chatMessagesProvider.notifier).startAutoRefresh();
    
    // Charger les utilisateurs en ligne
    _loadOnlineUsers();
    _startOnlineUsersRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _onlineUsersTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // ✅ NOUVEAU: Démarrage automatique SEULEMENT quand l'utilisateur est sur la page
    if (!_isInitialized && widget.autoStart) {
      print('[RADIO] 🚀 Utilisateur sur la page radio - Démarrage automatique activé');
      _isInitialized = true;
      
      // Démarrer la radio automatiquement APRÈS que l'utilisateur soit sur la page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startRadioAutomatically();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        print('[RADIO] App en arrière-plan - Radio continue de jouer');
        break;
      case AppLifecycleState.detached:
        _stopRadioWhenDetached();
        break;
      case AppLifecycleState.resumed:
        print('[RADIO] App au premier plan - Pas de vérification automatique');
        break;
    }
  }

  void _stopRadioWhenDetached() {
    final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
    final isCurrentlyPlaying = ref.read(radioPlayingProvider);
    
    if (isCurrentlyPlaying) {
      print('[RADIO] App détachée - Arrêt de la radio');
      radioPlayingNotifier.stopRadio();
      widget.onPlayStateChanged?.call(false);
    }
  }

  /// 🎵 Gestionnaire centralisé des notifications
  Future<void> _manageNotification(bool shouldShow) async {
    try {
      print('[RADIO] 🎵 Gestion notification: ${shouldShow ? "AFFICHER" : "MASQUER"}');
      
      if (shouldShow) {
        await _notificationChannel.invokeMethod('startRadioBackgroundService');
        await _notificationChannel.invokeMethod('updateRadioState', true);
        await _notificationChannel.invokeMethod('forceShowNotification');
      } else {
        await _notificationChannel.invokeMethod('updateRadioState', false);
        await _notificationChannel.invokeMethod('forceHideNotification');
        await _notificationChannel.invokeMethod('stopRadioBackgroundService');
      }
    } catch (e) {
      print('[RADIO] ❌ Erreur gestion notification: $e');
    }
  }

  /// 🚀 Démarrer la radio automatiquement au chargement de la page (AVEC notification)
  Future<void> _startRadioAutomatically() async {
    final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
    final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
    
    print('[RADIO] 🔍 DEBUG: widget.autoStart = ${widget.autoStart}');
    print('[RADIO] 🔍 DEBUG: ref.read(radioPlayingProvider) = ${ref.read(radioPlayingProvider)}');
    
    if (widget.autoStart && !ref.read(radioPlayingProvider)) {
      print('[RADIO] 🚀 Démarrage automatique de la radio...');
      
      try {
        await _startRadioFast(radioUrl);
        print('[RADIO] ✅ Radio démarrée automatiquement');
      } catch (e) {
        print('[RADIO] ❌ Erreur lors du démarrage automatique: $e');
      }
    } else {
      print('[RADIO] ⚠️ Démarrage automatique ignoré: autoStart=${widget.autoStart}, isPlaying=${ref.read(radioPlayingProvider)}');
    }
  }

  /// ⚡ Démarrer la radio en mode FAST
  Future<void> _startRadioFast(String radioUrl) async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      
      print('[RADIO] ⚡ Démarrage FAST de la radio: $radioUrl');
      await radioPlayingNotifier.startRadioFast(radioUrl, widget.radioName);
      print('[RADIO] ✅ Radio démarrée en mode FAST');
      
      // ✅ Attendre que la radio soit réellement en cours de lecture
      print('[RADIO] 🔍 DEBUG: Attente que la radio soit réellement démarrée...');
      int attempts = 0;
      const maxAttempts = 10;
      
      while (attempts < maxAttempts && !ref.read(radioPlayingProvider)) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
        print('[RADIO] 🔍 DEBUG: Tentative $attempts/$maxAttempts - Radio joue: ${ref.read(radioPlayingProvider)}');
      }
      
      if (ref.read(radioPlayingProvider)) {
        print('[RADIO] ✅ Radio confirmée en cours de lecture - Affichage de la notification');
        await _manageNotification(true);
        print('[RADIO] ✅ Notification affichée après confirmation de lecture');
      } else {
        print('[RADIO] ⚠️ Radio non confirmée en cours de lecture - Pas de notification');
      }
      
    } catch (e) {
      print('[RADIO] ❌ Erreur lors du démarrage FAST: $e');
    }
  }

  /// 🎵 Démarrer la radio en mode normal
  Future<void> _startRadioNormally(String radioUrl) async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      
      print('[RADIO] 🎵 Démarrage normal de la radio: $radioUrl');
      await radioPlayingNotifier.startRadio(radioUrl, widget.radioName);
      print('[RADIO] ✅ Radio démarrée en mode normal');
      
      // ✅ Attendre que la radio soit réellement en cours de lecture
      print('[RADIO] 🔍 DEBUG: Attente que la radio soit réellement démarrée...');
      int attempts = 0;
      const maxAttempts = 10;
      
      while (attempts < maxAttempts && !ref.read(radioPlayingProvider)) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
        print('[RADIO] 🔍 DEBUG: Tentative $attempts/$maxAttempts - Radio joue: ${ref.read(radioPlayingProvider)}');
      }
      
      if (ref.read(radioPlayingProvider)) {
        print('[RADIO] ✅ Radio confirmée en cours de lecture - Affichage de la notification');
        await _manageNotification(true);
        print('[RADIO] ✅ Notification affichée après confirmation de lecture');
      } else {
        print('[RADIO] ⚠️ Radio non confirmée en cours de lecture - Pas de notification');
      }
      
    } catch (e) {
      print('[RADIO] ❌ Erreur lors du démarrage normal: $e');
    }
  }

  /// 🛑 Arrêter la radio
  Future<void> _stopRadio() async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      
      print('[RADIO] 🛑 Arrêt de la radio...');
      await radioPlayingNotifier.stopRadio();
      print('[RADIO] ✅ Radio arrêtée');
      
      await _manageNotification(false);
      print('[RADIO] ✅ Notification masquée');
      
      widget.onPlayStateChanged?.call(false);
      
    } catch (e) {
      print('[RADIO] ❌ Erreur lors de l\'arrêt de la radio: $e');
    }
  }

  /// 🔄 Basculer entre play/pause
  Future<void> _togglePlay() async {
    final isCurrentlyPlaying = ref.read(radioPlayingProvider);
    
    if (isCurrentlyPlaying) {
      print('[RADIO] ⏸️ Mise en pause de la radio...');
      await _stopRadio();
    } else {
      print('[RADIO] ▶️ Reprise de la lecture de la radio...');
      final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
      await _startRadioNormally(radioUrl);
    }
  }



  /// 🚀 Démarrer la radio en mode TURBO
  Future<void> _startRadioTurbo() async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
      
      print('[RADIO] 🚀 Démarrage TURBO de la radio: $radioUrl');
      await radioPlayingNotifier.startRadioTurbo(radioUrl, widget.radioName);
      print('[RADIO] ✅ Radio démarrée en mode TURBO');
      
      await _manageNotification(true);
      print('[RADIO] ✅ Notification gérée via système centralisé (TURBO)');
      
    } catch (e) {
      print('[RADIO] ❌ Erreur lors du démarrage TURBO: $e');
    }
  }

  /// 📤 Partager la radio
  void _shareRadio() {
    final url = widget.streamUrl ?? embMissionRadioUrl;
    Share.share('Écoute la radio ${widget.radioName} en direct : $url');
  }

  /// 🔙 Retour à l'accueil
  void _goHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  /// 📊 Charger les utilisateurs en ligne
  Future<void> _loadOnlineUsers() async {
    if (!mounted) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/online_users'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['online_users'] != null) {
          final onlineUsers = int.tryParse(data['online_users'].toString()) ?? 0;
          setState(() {
            _onlineUsers = onlineUsers;
          });
          print('✅ Utilisateurs en ligne mis à jour: $_onlineUsers');
        }
      }
    } catch (e) {
      print('❌ Erreur chargement utilisateurs en ligne: $e');
      
      // Fallback: utiliser une valeur alternative
      try {
        final response = await http.get(
          Uri.parse('https://embmission.com/mobileappebm/api/online_users_alternative'),
          headers: {'Content-Type': 'application/json'},
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final alternativeOnline = int.tryParse(data['count'].toString()) ?? 0;
          setState(() {
            _onlineUsers = alternativeOnline;
          });
          print('✅ Utilisateurs en ligne récupérés via champ alternatif: $_onlineUsers');
        }
      } catch (fallbackError) {
        print('❌ Échec fallback utilisateurs en ligne: $fallbackError');
      }
    }
  }

  /// 🔄 Démarrer le rafraîchissement automatique des utilisateurs en ligne
  void _startOnlineUsersRefresh() {
    _onlineUsersTimer?.cancel();
    _onlineUsersTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadOnlineUsers();
      } else {
        timer.cancel();
        _onlineUsersTimer = null;
      }
    });
  }

  /// 📨 Envoyer un message
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    try {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(),
          ),
        );
      }
      
      setState(() {
        _isSendingMessage = true;
      });
      
      final message = _messageController.text.trim();
      final success = await ChatService.sendRadioMessage(message);
      
      if (success) {
        _messageController.clear();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message envoyé avec succès')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'envoi du message')),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentlyPlaying = ref.watch(radioPlayingProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5DADE2),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goHome,
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE74C3C),
              radius: 16,
              child: const Text(
                'emb',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.radioName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareRadio,
          ),
        ],
      ),
      body: Column(
        children: [
          // Section radio principale
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Indicateur d'erreur
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red[700]),
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                
                // Boutons de contrôle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bouton Play/Pause
                    ElevatedButton(
                      onPressed: _isLoading ? null : _togglePlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                              size: 32,
                            ),
                    ),
                    
                    // Bouton Stop
                    ElevatedButton(
                      onPressed: isCurrentlyPlaying ? _stopRadio : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.stop, size: 32),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Boutons de démarrage rapide
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                                         ElevatedButton(
                       onPressed: _isLoading ? null : () => _startRadioFast(widget.streamUrl ?? embMissionRadioUrl),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF2196F3),
                         foregroundColor: Colors.white,
                       ),
                       child: const Text('FAST'),
                     ),
                     
                     ElevatedButton(
                       onPressed: _isLoading ? null : () => _startRadioNormally(widget.streamUrl ?? embMissionRadioUrl),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF9C27B0),
                         foregroundColor: Colors.white,
                       ),
                       child: const Text('NORMAL'),
                     ),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _startRadioTurbo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('TURBO'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Contrôle du volume
                Row(
                  children: [
                    const Icon(Icons.volume_down),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        onChanged: (value) {
                          setState(() {
                            _volume = value;
                          });
                          _audioPlayer.setVolume(_volume);
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up),
                  ],
                ),
                
                // Utilisateurs en ligne
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '$_onlineUsers connectés',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Section chat
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // En-tête du chat
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Chat en direct',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                                     // Messages du chat
                   Expanded(
                     child: Consumer(
                       builder: (context, ref, child) {
                         final messages = ref.watch(chatMessagesProvider);
                         
                         if (messages.isEmpty) {
                           return const Center(
                             child: Text('Aucun message pour le moment'),
                           );
                         }
                         
                         return ListView.builder(
                           controller: _scrollController,
                           padding: const EdgeInsets.all(16),
                           itemCount: messages.length,
                           itemBuilder: (context, index) {
                             final message = messages[index];
                             return _buildChatMessage(message);
                           },
                         );
                       },
                     ),
                   ),
                  
                  // Zone de saisie
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Tapez votre message...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _isSendingMessage 
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.send),
                          onPressed: _isSendingMessage ? null : _sendMessage,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 MÉTHODE: Construire un message de chat
  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.username,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(message.message),
        ],
      ),
    );
  }
} 