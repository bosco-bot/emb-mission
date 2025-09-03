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
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../../../core/services/battery_optimization_service.dart';
import '../../../core/services/monitoring_service.dart';

class RadioScreen extends ConsumerStatefulWidget {
  final String? streamUrl;
  final String radioName;
  final Function(bool)? onPlayStateChanged;

  const RadioScreen({
    super.key,
    this.streamUrl,
    required this.radioName,
    this.onPlayStateChanged,
  });

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> with WidgetsBindingObserver {
  // 🚀 GESTION D'ERREUR GLOBALE: Pour éviter les plantages
  static bool _hasGlobalError = false;
  static String? _globalErrorMessage;
  
  // 🚀 OPTIMISATIONS SÉCURISÉES: Cache et pré-initialisation simplifiés
  static final Map<String, bool> _urlCache = {};
  static bool _globalInitialized = false;
  static const Duration _ultraFastTimeout = Duration(milliseconds: 800);
  
  // 🚀 OPTIMISATIONS SÉCURISÉES: Timeouts modérés pour éviter les plantages
  static const Duration _turboTimeout = Duration(milliseconds: 600);
  static const Duration _ultraTurboTimeout = Duration(milliseconds: 400);
  
  // 🚀 OPTIMISATIONS SÉCURISÉES: Cache des players simplifié
  static final Map<String, bool> _playerInitialized = {};
  static bool _playersPreInitialized = false;
  
  late AudioPlayer _audioPlayer;
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  Timer? _onlineUsersTimer;
  
  // 🚨 NOUVEAU: Système de monitoring continu de la santé radio
  Timer? _radioHealthTimer;
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _oneHourThreshold = Duration(hours: 1);
  DateTime? _radioStartTime;
  bool _isRecoveringFromCut = false;
  
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  
  // ✅ Variables manquantes ajoutées
  bool _isSendingMessage = false;
  int _onlineUsers = 0;
  double _volume = 0.5;
  
  // ✅ URL radio principale unique
  static const String embMissionRadioUrl = 'https://stream.zeno.fm/rxi8n979ui1tv';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    
    // 🚀 OPTIMISATION: Pré-initialisation globale une seule fois
    if (!_globalInitialized) {
      _initializeGlobalRadioSystem();
    }
    
    // ✅ LOGIQUE SIMPLE: Initialisation basique
    _initializeBasicRadioSystem();
    
      // ✅ NOUVELLE LOGIQUE: Vérifier et arrêter la radio si elle joue déjà au démarrage
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _checkAndStopRadioIfPlaying();  // ← Vérifier et arrêter la radio si nécessaire
    }
  });
    
    // Charger les messages du chat et démarrer le rafraîchissement automatique
    ref.read(chatMessagesProvider.notifier).loadMessages();
    ref.read(chatMessagesProvider.notifier).startAutoRefresh();
    
    // ✅ VÉRIFICATION DES PERMISSIONS: Afficher les messages de permission
    Future.microtask(() {
      if (mounted) {
        BatteryOptimizationService.checkAndRequestPermission(context);
      }
    });
    
    // CHARGEMENT MANUEL UNIQUEMENT : Charger le nombre d'utilisateurs en ligne une seule fois
    // Utiliser Future.microtask pour éviter les appels trop précoces
    Future.microtask(() {
      if (mounted) {
        _loadOnlineUsers();
        print('[RADIO] ✅ Chargement manuel des utilisateurs en ligne activé');
      }
    });
    
    // ✅ NOUVEAU: Démarrer le timer de rafraîchissement automatique
    Future.microtask(() {
      if (mounted) {
        _startOnlineUsersRefresh();
        print('[RADIO] ✅ Timer de rafraîchissement des utilisateurs en ligne démarré');
      }
    });
    
    // 🚨 NOUVEAU: Démarrer le monitoring de santé radio
    Future.microtask(() {
      if (mounted) {
        _startRadioHealthMonitoring();
        print('[RADIO] 🚨 Monitoring de santé radio démarré');
      }
    });
  }
  
  // 🚀 MÉTHODE SÉCURISÉE: Initialisation globale du système radio avec gestion d'erreur
  Future<void> _initializeGlobalRadioSystem() async {
    try {
      // 🚀 GESTION D'ERREUR GLOBALE: Effacer les erreurs précédentes
      _clearGlobalError();
      
      print('[RADIO] 🚀 Initialisation globale du système radio...');
      
      // 🚀 OPTIMISATION SÉCURISÉE: Vérifier si déjà initialisé
      if (_globalInitialized) {
        print('[RADIO] ✅ Système radio déjà initialisé');
        return;
      }
      
      // 🚀 OPTIMISATION SÉCURISÉE: Initialisation basique sécurisée
      await _initializeBasicRadioSystem();
      
      // 🚀 OPTIMISATION SÉCURISÉE: Pré-initialisation des players
      await _preInitializePlayers();
      
      // 🚀 OPTIMISATION SÉCURISÉE: Marquer comme initialisé
      _globalInitialized = true;
      
      print('[RADIO] 🚀 Système radio global initialisé avec succès');
      
    } catch (e) {
      // 🚀 GESTION D'ERREUR GLOBALE: Capturer et gérer l'erreur
      final errorMessage = 'Erreur initialisation système radio: $e';
      _setGlobalError(errorMessage);
      
      print('[RADIO] ❌ ERREUR CRITIQUE: $errorMessage');
      
      // 🚀 FALLBACK SÉCURISÉ: Essayer l'initialisation basique en cas d'échec
      try {
        print('[RADIO] 🚀 Tentative de récupération via initialisation basique...');
        await _initializeBasicRadioSystem();
        print('[RADIO] ✅ Récupération réussie via initialisation basique');
      } catch (fallbackError) {
        print('[RADIO] ❌ ÉCHEC CRITIQUE DE LA RÉCUPÉRATION: $fallbackError');
        _setGlobalError('Échec critique de la récupération: $fallbackError');
      }
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Pré-initialisation des players pour démarrage instantané
  Future<void> _preInitializePlayers() async {
    try {
      print('[RADIO] 🚀 Pré-initialisation des players pour démarrage instantané...');
      
      // Pré-créer un player pour l'URL principale
      if (!_playerInitialized.containsKey(embMissionRadioUrl)) {
        final player = AudioPlayer();
        
        // Configuration ultra-rapide pour le streaming
        await player.setAudioSource(
          AudioSource.uri(Uri.parse(embMissionRadioUrl)),
          preload: false, // ⚡ Pas de préchargement
        );
        
        // Configuration minimale pour la performance
        await player.setVolume(_volume);
        await player.setLoopMode(LoopMode.off);
        
        // Mettre en cache pour un démarrage instantané
        _playerInitialized[embMissionRadioUrl] = true;
        print('[RADIO] 🚀 Player pré-initialisé et mis en cache: $embMissionRadioUrl');
      }
      
      // Pré-créer un player pour l'URL personnalisée si différente
      if (widget.streamUrl != null && widget.streamUrl != embMissionRadioUrl) {
        if (!_playerInitialized.containsKey(widget.streamUrl!)) {
          final player = AudioPlayer();
          
          // Configuration ultra-rapide pour le streaming
          await player.setAudioSource(
            AudioSource.uri(Uri.parse(widget.streamUrl!)),
            preload: false, // ⚡ Pas de préchargement
          );
          
          // Configuration minimale pour la performance
          await player.setVolume(_volume);
          await player.setLoopMode(LoopMode.off);
          
          // Mettre en cache pour un démarrage instantané
          _playerInitialized[widget.streamUrl!] = true;
          print('[RADIO] 🚀 Player personnalisé pré-initialisé et mis en cache: ${widget.streamUrl}');
        }
      }
      
      _playersPreInitialized = true;
      print('[RADIO] 🚀 Tous les players pré-initialisés avec succès');
      
    } catch (e) {
      print('[RADIO] Erreur pré-initialisation players (non critique): $e');
    }
  }
  
  // ✅ MÉTHODE SIMPLE: Initialisation basique du système radio
  Future<void> _initializeBasicRadioSystem() async {
    try {
      print('[RADIO] Initialisation basique du système radio...');
      
      // ✅ NOUVEAU: Monitoring de performance radio
      final stopwatch = Stopwatch()..start();
      
      // Configuration simple du player principal
      await _audioPlayer.setVolume(_volume);
      
      stopwatch.stop();
      // ✅ NOUVEAU: Monitoring du temps d'initialisation
      await MonitoringService.logPerformanceMetric(
        'radio_init_time_ms', 
        stopwatch.elapsedMilliseconds
      );
      
      // ✅ NOUVEAU: Événement de contenu radio
      await MonitoringService.logContentView(
        'radio', 
        'emb_mission_radio',
        title: 'Radio EMB Mission'
      );
      
      print('[RADIO] ✅ Système radio basique initialisé');
      
    } catch (e) {
      // ✅ NOUVEAU: Monitoring des erreurs radio
      await MonitoringService.logError(e, StackTrace.current, fatal: false);
      
      print('[RADIO] Erreur initialisation basique (non critique): $e');
    }
  }
  
  // 🚀 MÉTHODE SÉCURISÉE: Démarrage ultra-rapide simplifié pour éviter les plantages
  Future<void> _startRadioUltraFast() async {
    try {
      final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
      
      // 🚀 OPTIMISATION SÉCURISÉE: Vérifier le cache en premier
      if (_urlCache.containsKey(radioUrl) && _globalInitialized) {
        print('[RADIO] 🚀 Démarrage ultra-rapide depuis le cache: $radioUrl');
        await _startRadioFromCache(radioUrl);
        return;
      }
      
      // ✅ OPTIMISATION SÉCURISÉE: Essayer le mode TURBO SANS service Android en premier si disponible
      if (_playersPreInitialized && _playerInitialized.containsKey(radioUrl)) {
        print('[RADIO] ✅ Mode TURBO SANS service Android disponible - Démarrage ultra-rapide');
        await _startRadioTurboSilent(radioUrl);
        
        // Mettre en cache pour les prochaines fois
        _urlCache[radioUrl] = true;
        return;
      }
      
      // 🚀 OPTIMISATION SÉCURISÉE: Si pas de mode TURBO, essayer le démarrage automatique
      print('[RADIO] 🚀 Pas de mode TURBO disponible - Fallback vers démarrage automatique');
      await _startRadioAutomatically();
      return;
      
    } catch (e) {
      print('[RADIO] Erreur démarrage ultra-rapide sécurisé: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e is! TimeoutException) {
            _error = 'Erreur de connexion: $e';
          }
        });
      }
      
      // 🚀 CORRECTION CRITIQUE: Démarrage automatique en fallback si l'ultra-rapide échoue
      print('[RADIO] 🚀 Fallback vers démarrage automatique après erreur ultra-rapide');
      try {
        await _startRadioAutomatically();
      } catch (fallbackError) {
        print('[RADIO] ❌ Erreur critique du fallback: $fallbackError');
      }
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Démarrage depuis le cache
  Future<void> _startRadioFromCache(String radioUrl) async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      
      // ✅ OPTIMISATION: Démarrage instantané AVEC service Android depuis le cache
      await radioPlayingNotifier.startRadioFast(radioUrl, widget.radioName);
      
      widget.onPlayStateChanged?.call(true);
      print('[RADIO] 🚀 Radio démarrée instantanément depuis le cache: $radioUrl');
      
      // 🚨 NOUVEAU: Enregistrer l'heure de démarrage pour le monitoring
      _radioStartTime = DateTime.now();
      print('[RADIO HEALTH] ⏰ Heure de démarrage enregistrée (cache): $_radioStartTime');
      
    } catch (e) {
      print('[RADIO] Erreur démarrage depuis cache: $e');
      // Retirer du cache si erreur
      _urlCache.remove(radioUrl);
      // Retomber sur le démarrage normal
      await _startRadioNormally();
    }
  }
  
  // 🚀 MÉTHODE SÉCURISÉE: Démarrage TURBO simplifié pour éviter les plantages
  Future<void> _startRadioTurbo(String radioUrl) async {
    try {
      print('[RADIO] 🚀 Démarrage TURBO sécurisé: $radioUrl');
      
      // Vérifier si on a un player pré-initialisé
      if (_playersPreInitialized && _playerInitialized.containsKey(radioUrl)) {
        print('[RADIO] 🚀 Player pré-initialisé trouvé - Démarrage TURBO sécurisé');
        
        // 🚀 OPTIMISATION SÉCURISÉE: Utiliser le player principal au lieu du cache
        final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
        
        // ✅ Démarrer la lecture AVEC service Android avec timeout modéré pour éviter les plantages
        await radioPlayingNotifier.startRadioFast(radioUrl, widget.radioName)
            .timeout(_ultraTurboTimeout, onTimeout: () {
          print('[RADIO] ⚠️ Timeout TURBO sécurisé AVEC service Android atteint');
          throw TimeoutException('Démarrage TURBO sécurisé AVEC service Android trop long');
        });
        
        // Mettre à jour l'état immédiatement
        widget.onPlayStateChanged?.call(true);
        
        // 🚨 NOUVEAU: Enregistrer l'heure de démarrage pour le monitoring
        _radioStartTime = DateTime.now();
        print('[RADIO HEALTH] ⏰ Heure de démarrage enregistrée (TURBO): $_radioStartTime');
        
        print('[RADIO] 🚀 Radio démarrée en mode TURBO sécurisé: $radioUrl');
        return;
      }
      
      // Fallback vers le démarrage normal si pas de player pré-initialisé
      print('[RADIO] ⚠️ Pas de player pré-initialisé - Fallback vers démarrage normal');
      await _startRadioNormally();
      
    } catch (e) {
      print('[RADIO] Erreur démarrage TURBO sécurisé: $e');
      // Fallback vers le démarrage normal
      await _startRadioNormally();
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Démarrage parallèle
  Future<void> _startRadioParallel(String radioUrl) async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      
      // ✅ OPTIMISATION: Démarrage parallèle AVEC service Android avec timeout ultra-rapide
      await radioPlayingNotifier.startRadioFast(radioUrl, widget.radioName)
          .timeout(_ultraFastTimeout, onTimeout: () {
        print('[RADIO] ⚠️ Timeout démarrage parallèle AVEC service Android atteint');
        throw TimeoutException('Démarrage parallèle AVEC service Android trop long');
      });
      
      widget.onPlayStateChanged?.call(true);
      print('[RADIO] 🚀 Radio démarrée en parallèle: $radioUrl');
      
      // 🚨 NOUVEAU: Enregistrer l'heure de démarrage pour le monitoring
      _radioStartTime = DateTime.now();
      print('[RADIO HEALTH] ⏰ Heure de démarrage enregistrée (parallèle): $_radioStartTime');
      
    } catch (e) {
      print('[RADIO] Erreur démarrage parallèle: $e');
      rethrow;
    }
  }
  
  // 🚀 NOUVELLE MÉTHODE: Initialisation AudioService en parallèle
  Future<void> _initAudioServiceParallel() async {
    try {
      // 🚀 OPTIMISATION: Initialisation AudioService en arrière-plan
      await Future.delayed(const Duration(milliseconds: 100));
      print('[RADIO] 🚀 AudioService initialisé en parallèle');
    } catch (e) {
      print('[RADIO] Erreur init AudioService parallèle (non critique): $e');
    }
  }
  
  // ✅ MÉTHODE SIMPLE: Démarrage normal de la radio (fallback)
  Future<void> _startRadioNormally() async {
    try {
      print('[RADIO] Démarrage normal de la radio (fallback)...');
      
      // Démarrer la radio automatiquement
      await _startRadioAutomatically();
      
    } catch (e) {
      print('[RADIO] Erreur démarrage normal: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // OPTIMISATION: Configuration simplifiée sans préchargement
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(widget.streamUrl ?? embMissionRadioUrl)),
        preload: false, // ⚡ Désactivé pour un démarrage plus rapide
      );
      
      // Configuration minimale pour la lecture en arrière-plan
      await _audioPlayer.setLoopMode(LoopMode.off);
      
      setState(() {
        _isLoading = false;
      });
      
      // ✅ SOLUTION : Démarrage automatique DÉSACTIVÉ
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   if (mounted) {
      //     _startRadioAutomatically(); // ← COMMENTÉ
      //   }
      // });
      
      print('[RADIO] ✅ Player initialisé SANS démarrage automatique');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur de chargement du flux audio.';
      });
    }
  }

  // 🚀 MÉTHODE SÉCURISÉE: Démarrage automatique ultra-rapide avec gestion d'erreur robuste
  Future<void> _startRadioAutomatically() async {
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
      final isCurrentlyPlaying = ref.read(radioPlayingProvider);
      
      // 🚀 OPTIMISATION SÉCURISÉE: Vérification ultra-rapide
      if (!isCurrentlyPlaying) {
        print('[RADIO] 🚀 Démarrage automatique ultra-rapide: $radioUrl');
        
        // ✅ OPTIMISATION SÉCURISÉE: Essayer le mode TURBO SANS service Android en premier
        if (_playersPreInitialized && _playerInitialized.containsKey(radioUrl)) {
          print('[RADIO] ✅ Mode TURBO SANS service Android disponible pour démarrage automatique');
          await _startRadioTurboSilent(radioUrl);
          
          // Mettre en cache immédiatement
          _urlCache[radioUrl] = true;
          return;
        }
        
        setState(() {
          _isLoading = true;
          _error = null;
        });
        
        try {
          // ✅ NOUVELLE LOGIQUE: Démarrage AVEC service Android au démarrage automatique (pour avoir la notification)
          await radioPlayingNotifier.startRadioFast(radioUrl, widget.radioName)
              .timeout(const Duration(seconds: 2), onTimeout: () { // ⚡ Timeout modéré pour la stabilité
            print('[RADIO] ⚠️ Timeout de startRadioFast() après 2 secondes');
            throw TimeoutException('Démarrage ultra-rapide de la radio trop long');
          });
          
          widget.onPlayStateChanged?.call(true);
          print('[RADIO] 🚀 Radio démarrée automatiquement ultra-rapidement AVEC service Android: $radioUrl');
          
          // 🚨 NOUVEAU: Enregistrer l'heure de démarrage pour le monitoring
          _radioStartTime = DateTime.now();
          print('[RADIO HEALTH] ⏰ Heure de démarrage enregistrée: $_radioStartTime');
          
          // 🚀 OPTIMISATION SÉCURISÉE: Mise en cache immédiate
          _urlCache[radioUrl] = true;
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        } catch (startError) {
          print('[RADIO] Erreur lors du démarrage automatique: $startError');
          if (mounted) {
            setState(() {
              _isLoading = false;
              if (startError is! TimeoutException) {
                _error = 'Erreur de connexion: $startError';
              }
            });
          }
          
          // ✅ FALLBACK SÉCURISÉ: Essayer le démarrage SANS service Android en cas d'échec
          print('[RADIO] ✅ Fallback vers démarrage SANS service Android après échec automatique');
          try {
            // ✅ IMPORTANT: Utiliser startRadioFastSilent() même en fallback pour éviter la notification
            await radioPlayingNotifier.startRadioFastSilent(radioUrl, widget.radioName);
            widget.onPlayStateChanged?.call(true);
            
            // 🚨 NOUVEAU: Enregistrer l'heure de démarrage pour le monitoring (fallback)
            _radioStartTime = DateTime.now();
            print('[RADIO HEALTH] ⏰ Heure de démarrage enregistrée (fallback): $_radioStartTime');
            
            print('[RADIO] ✅ Radio démarrée via fallback SANS service Android: $radioUrl');
          } catch (fallbackError) {
            print('[RADIO] ❌ Erreur critique du fallback SANS service Android: $fallbackError');
            if (mounted) {
              setState(() {
                _error = 'Impossible de démarrer la radio';
              });
            }
          }
        }
      } else {
        print('[RADIO] Radio déjà en cours de lecture, pas de démarrage automatique');
      }
    } catch (e) {
      print('[RADIO] ❌ Erreur critique du démarrage automatique: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Erreur critique: $e';
        });
      }
    }
  }

  // ✅ NOUVELLE MÉTHODE: Vérifier et arrêter la radio si elle joue déjà au démarrage
  Future<void> _checkAndStopRadioIfPlaying() async {
    print('[RADIO SCREEN DEBUG] 🔍 _checkAndStopRadioIfPlaying() - Vérification de l\'état de la radio au démarrage...');
    
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      final isCurrentlyPlaying = ref.read(radioPlayingProvider);
      
      if (isCurrentlyPlaying) {
        print('[RADIO SCREEN DEBUG] 🚨 ATTENTION: La radio joue déjà au démarrage de l\'app !');
        print('[RADIO SCREEN DEBUG] 🔇 Arrêt de la radio pour éviter la notification indésirable...');
        
        // Arrêter la radio qui joue déjà
        await radioPlayingNotifier.stopRadio();
        
        print('[RADIO SCREEN DEBUG] ✅ Radio arrêtée avec succès au démarrage de l\'app');
        
        // Maintenant, démarrer la radio AVEC service Android (pour avoir la notification)
        print('[RADIO SCREEN DEBUG] 🚀 Démarrage de la radio AVEC service Android...');
        await _startRadioWithService();
        
      } else {
        print('[RADIO SCREEN DEBUG] ✅ Radio pas en cours de lecture - Démarrage normal AVEC service Android');
        await _startRadioWithService();
      }
      
    } catch (e) {
      print('[RADIO SCREEN DEBUG] ❌ Erreur lors de la vérification/arrêt de la radio: $e');
      // En cas d'erreur, essayer quand même de démarrer la radio AVEC service Android
      try {
        await _startRadioWithService();
      } catch (startError) {
        print('[RADIO SCREEN DEBUG] ❌ Erreur critique du démarrage: $startError');
      }
    }
  }

  // ✅ NOUVELLE MÉTHODE: Mode TURBO SANS service Android (pour démarrage automatique)
  Future<void> _startRadioTurboSilent(String radioUrl) async {
    print('[RADIO SCREEN DEBUG] 🚀 _startRadioTurboSilent() - Mode TURBO SANS service Android...');
    
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      
      // ✅ LOGIQUE TURBO SANS service Android pour le démarrage automatique
      await radioPlayingNotifier.startRadioTurboSilent(radioUrl, widget.radioName);
      
      print('[RADIO SCREEN DEBUG] ✅ Radio démarrée en mode TURBO SANS service Android');
      
    } catch (e) {
      print('[RADIO SCREEN DEBUG] ❌ Erreur mode TURBO SANS service: $e');
    }
  }

  // ✅ NOUVELLE MÉTHODE: Démarrer la radio AVEC service Android (pour navigation manuelle)
  Future<void> _startRadioWithService() async {
    print('[RADIO SCREEN DEBUG] 🎵 _startRadioWithService() - Démarrage AVEC service Android...');
    
    try {
      final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
      final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
      
      // ✅ LOGIQUE NORMALE: Démarrage AVEC service Android pour la navigation manuelle
      await radioPlayingNotifier.startRadioFast(radioUrl, widget.radioName);
      
      print('[RADIO SCREEN DEBUG] ✅ Radio démarrée AVEC service Android');
      
    } catch (e) {
      print('[RADIO SCREEN DEBUG] ❌ Erreur démarrage avec service: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Ne pas détruire l'audioPlayer s'il est partagé (passé en paramètre)
    if (widget.onPlayStateChanged == null) { // Check if onPlayStateChanged is null
      _audioPlayer.dispose();
    }
    _messageController.dispose();
    _scrollController.dispose();
    
    // Arrêter le rafraîchissement automatique du chat
    if (mounted) {
      try {
        ref.read(chatMessagesProvider.notifier).stopAutoRefresh();
      } catch (e) {
        print('[RADIO] Erreur lors de l\'arrêt du chat: $e');
      }
    }
    _onlineUsersTimer?.cancel();
    
    // 🚨 NOUVEAU: Arrêter le monitoring de santé radio
    _radioHealthTimer?.cancel();
    print('[RADIO HEALTH] 🚨 Monitoring de santé radio arrêté');
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // La radio continue de jouer en arrière-plan grâce à AudioService
        print('[RADIO] App en arrière-plan - Radio continue de jouer');
        break;
      case AppLifecycleState.detached:
        // Arrêter la radio seulement quand l'app est complètement fermée
        _stopRadioWhenDetached();
        break;
      case AppLifecycleState.resumed:
        // L'app revient au premier plan - VÉRIFICATION DE SANTÉ RADIO
        print('[RADIO] App au premier plan - Vérification de santé radio');
        // 🚨 NOUVEAU: Vérifier la santé radio lors du retour au premier plan
        Future.microtask(() {
          if (mounted) {
            _checkRadioHealth();
          }
        });
        break;
    }
  }
  


  void _stopRadioWhenDetached() {
    final radioPlayer = ref.read(radioPlayerProvider);
    final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
    final isCurrentlyPlaying = ref.read(radioPlayingProvider);
    
    if (isCurrentlyPlaying) {
      print('[RADIO] App fermée - Arrêt de la radio');
      try {
        radioPlayer.stop();
        radioPlayingNotifier.updatePlayingState(false);
        widget.onPlayStateChanged?.call(false);
        
        // 🚨 NOUVEAU: Réinitialiser l'heure de démarrage lors de l'arrêt
        _radioStartTime = null;
        print('[RADIO HEALTH] ⏰ Heure de démarrage réinitialisée (détaché)');
        
      } catch (e) {
        print('[RADIO] Erreur lors de l\'arrêt: $e');
      }
    }
  }

  Future<void> _togglePlay() async {
    final radioPlayingNotifier = ref.read(radioPlayingProvider.notifier);
    final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
    final isCurrentlyPlaying = ref.read(radioPlayingProvider);
    
    if (isCurrentlyPlaying) {
      try {
        print('[RADIO] Arrêt de la radio en cours...');
        
        // 🚨 CORRECTION CRITIQUE: Arrêter la radio via le provider
        await radioPlayingNotifier.stopRadio();
        
        // 🚨 CORRECTION CRITIQUE: Arrêter aussi le player local
        if (_audioPlayer.playing) {
          await _audioPlayer.stop();
          print('[RADIO] Player local arrêté');
        }
        
        // ✅ LOGIQUE SIMPLE: Pas de players en cache à arrêter
        
        // Mettre à jour l'interface
        widget.onPlayStateChanged?.call(false);
        print('[RADIO] Radio complètement arrêtée');
        
        // 🚨 NOUVEAU: Réinitialiser l'heure de démarrage lors de l'arrêt
        _radioStartTime = null;
        print('[RADIO HEALTH] ⏰ Heure de démarrage réinitialisée (arrêt)');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
          });
        }
        
      } catch (e) {
        print('[RADIO] Erreur lors de l\'arrêt: $e');
        // Forcer l'arrêt même en cas d'erreur
        try {
          await _audioPlayer.stop();
          ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
          widget.onPlayStateChanged?.call(false);
          
          // 🚨 NOUVEAU: Réinitialiser l'heure de démarrage lors de l'arrêt forcé
          _radioStartTime = null;
          print('[RADIO HEALTH] ⏰ Heure de démarrage réinitialisée (arrêt forcé)');
          
        } catch (forceError) {
          print('[RADIO] Erreur lors de l\'arrêt forcé: $forceError');
        }
        
        if (mounted) {
          setState(() {
            _error = 'Erreur lors de l\'arrêt: $e';
          });
        }
      }
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      try {
        print('[RADIO] Démarrage simple de la radio...');
        
        // ✅ NOUVELLE LOGIQUE: Démarrage AVEC service Android quand l'utilisateur démarre manuellement
        await _startRadioWithService();
        
        print('[RADIO DEBUG] startRadio() terminé avec succès');
        
        // 🚨 NOUVEAU: Enregistrer l'heure de démarrage pour le monitoring
        _radioStartTime = DateTime.now();
        print('[RADIO HEALTH] ⏰ Heure de démarrage enregistrée (toggle): $_radioStartTime');
        
        widget.onPlayStateChanged?.call(true);
        print('[RADIO] Radio démarrée avec succès: $radioUrl');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
          });
        }
        print('[RADIO DEBUG] setState _isLoading = false (fin)');
        
      } catch (e) {
        print('[RADIO DEBUG] Erreur dans _togglePlay: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (e is TimeoutException) {
              _error = 'Démarrage de la radio trop long. Vérifiez votre connexion.';
            } else {
              _error = 'Erreur de connexion: $e';
            }
          });
        }
      }
    }
  }

  void _shareRadio() {
    final url = widget.streamUrl ?? embMissionRadioUrl;
    Share.share('Écoute la radio ${widget.radioName} en direct : $url');
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _loadOnlineUsers() async {
    // Vérifier si le widget est encore monté avant l'appel API
    if (!mounted) {
      print('[RADIO] ⚠️ Widget démonté, arrêt du chargement des utilisateurs en ligne');
      return;
    }
    
    try {
      print('[RADIO] 🔄 Chargement des utilisateurs en ligne...');
      final url = 'https://embmission.com/mobileappebm/api/viewstatforum';
      print('[RADIO] 📡 Appel API: $url');
      
      final response = await http.get(Uri.parse(url));
      print('[RADIO] 📡 Réponse API - Status: ${response.statusCode}, Body: ${response.body}');
      
      // Vérifier à nouveau après l'API
      if (!mounted) {
        print('[RADIO] ⚠️ Widget démonté après API, arrêt de la mise à jour');
        return;
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[RADIO] 📊 Données reçues: $data');
        
        if (data['success'] == 'true') {
          final onlineUsers = data['online'] ?? 0;
          setState(() {
            _onlineUsers = onlineUsers;
          });
          print('✅ Utilisateurs en ligne mis à jour: $_onlineUsers');
        } else {
          print('⚠️ API retourne success: false - Données: $data');
          // En cas d'échec, essayer de récupérer d'autres champs possibles
          final alternativeOnline = data['online_users'] ?? data['users_online'] ?? data['count'] ?? 0;
          if (alternativeOnline != 0) {
            setState(() {
              _onlineUsers = alternativeOnline;
            });
            print('✅ Utilisateurs en ligne récupérés via champ alternatif: $_onlineUsers');
          }
        }
      } else {
        print('❌ Erreur HTTP: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des utilisateurs en ligne: $e');
      // En cas d'erreur, essayer de charger depuis le cache local si disponible
      print('[RADIO] 🔄 Tentative de récupération depuis le cache local...');
    }
  }

  void _startOnlineUsersRefresh() {
    // ✅ RÉACTIVÉ : Rafraîchir le nombre d'utilisateurs toutes les 10 secondes
    print('[RADIO] ✅ Timer des utilisateurs en ligne réactivé');
    
    _onlineUsersTimer?.cancel();
    _onlineUsersTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // Vérifier si le widget est encore monté avant d'appeler la fonction
      if (mounted) {
        _loadOnlineUsers();
      } else {
        print('[RADIO] ⚠️ Widget démonté, arrêt du timer des utilisateurs en ligne');
        timer.cancel();
        _onlineUsersTimer = null;
      }
    });
  }

  // 🚨 NOUVELLE MÉTHODE: Vérification continue de la santé radio
  void _startRadioHealthMonitoring() {
    print('[RADIO HEALTH] 🚨 Démarrage du monitoring de santé radio toutes les 30 secondes');
    
    _radioHealthTimer?.cancel();
    _radioHealthTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      if (!mounted) {
        print('[RADIO HEALTH] ⚠️ Widget démonté, arrêt du monitoring');
        timer.cancel();
        _radioHealthTimer = null;
        return;
      }
      
      await _checkRadioHealth();
    });
  }

  // 🚨 NOUVELLE MÉTHODE: Vérification de la santé radio
  Future<void> _checkRadioHealth() async {
    try {
      final isCurrentlyPlaying = ref.read(radioPlayingProvider);
      final radioPlayer = ref.read(radioPlayerProvider);
      
      print('[RADIO HEALTH] 🔍 Vérification santé radio - État: $isCurrentlyPlaying');
      
      // Vérifier si la radio devrait jouer mais ne joue pas
      if (isCurrentlyPlaying && !radioPlayer.playing) {
        print('[RADIO HEALTH] 🚨 COUPURE DÉTECTÉE - Radio marquée comme jouant mais player arrêté');
        await _recoverFromRadioCut();
        return;
      }
      
      // Vérifier la santé après 1 heure de lecture
      if (_radioStartTime != null && isCurrentlyPlaying) {
        final duration = DateTime.now().difference(_radioStartTime!);
        if (duration >= _oneHourThreshold) {
          print('[RADIO HEALTH] ⏰ 1 heure de lecture atteinte - Vérification spéciale de stabilité');
          await _stabilizeAfterOneHour();
        }
      }
      
      print('[RADIO HEALTH] ✅ Santé radio vérifiée - Tout va bien');
      
    } catch (e) {
      print('[RADIO HEALTH] ❌ Erreur lors de la vérification de santé: $e');
    }
  }

  // 🚨 NOUVELLE MÉTHODE: Récupération automatique après coupure
  Future<void> _recoverFromRadioCut() async {
    if (_isRecoveringFromCut) {
      print('[RADIO HEALTH] ⚠️ Récupération déjà en cours, ignoré');
      return;
    }
    
    _isRecoveringFromCut = true;
    print('[RADIO HEALTH] 🚨 DÉBUT RÉCUPÉRATION AUTOMATIQUE après coupure radio');
    
    try {
      // 1. Arrêter complètement l'état actuel
      await ref.read(radioPlayingProvider.notifier).stopRadio();
      
      // 2. Attendre un peu
      await Future.delayed(const Duration(seconds: 2));
      
      // 3. Redémarrer la radio SANS service Android (pour éviter la notification)
      final radioUrl = widget.streamUrl ?? embMissionRadioUrl;
      await ref.read(radioPlayingProvider.notifier).startRadioFastSilent(radioUrl, widget.radioName);
      
      // 4. Mettre à jour l'heure de démarrage
      _radioStartTime = DateTime.now();
      
      print('[RADIO HEALTH] ✅ Récupération automatique réussie - Radio redémarrée');
      
    } catch (e) {
      print('[RADIO HEALTH] ❌ Échec de la récupération automatique: $e');
      
      // En cas d'échec, forcer l'état à false
      ref.read(radioPlayingProvider.notifier).updatePlayingState(false);
    } finally {
      _isRecoveringFromCut = false;
    }
  }

  // 🚨 NOUVELLE MÉTHODE: Stabilisation spéciale après 1 heure
  Future<void> _stabilizeAfterOneHour() async {
    print('[RADIO HEALTH] ⏰ STABILISATION SPÉCIALE après 1 heure de lecture');
    
    try {
      final radioPlayer = ref.read(radioPlayerProvider);
      
      // 1. Vérifier la stabilité du player
      if (radioPlayer.playing) {
        // 2. Nettoyer les ressources et stabiliser
        await _cleanupAndStabilize();
        print('[RADIO HEALTH] ✅ Stabilisation après 1 heure réussie');
      }
      
    } catch (e) {
      print('[RADIO HEALTH] ❌ Erreur lors de la stabilisation: $e');
    }
  }

  // 🚨 NOUVELLE MÉTHODE: Nettoyage et stabilisation
  Future<void> _cleanupAndStabilize() async {
    print('[RADIO HEALTH] 🧹 Nettoyage et stabilisation des ressources radio');
    
    try {
      // 1. Nettoyer les variables statiques
      _urlCache.clear();
      _playerInitialized.clear();
      _globalInitialized = false;
      _playersPreInitialized = false;
      
      // 2. Réinitialiser le système global
      await _initializeGlobalRadioSystem();
      
      // 3. Redémarrer le monitoring de santé
      _startRadioHealthMonitoring();
      
      print('[RADIO HEALTH] ✅ Nettoyage et stabilisation terminés');
      
    } catch (e) {
      print('[RADIO HEALTH] ❌ Erreur lors du nettoyage: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Vérifier si l'utilisateur est connecté
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    print('🔍 Debug chat - user_id dans SharedPreferences: $userId');

    if (userId == null || userId.isEmpty) {
      print('❌ Utilisateur non connecté - redirection vers WelcomeScreen');
      // Utilisateur non connecté, afficher WelcomeScreen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ),
        );
      }
      return;
    }
    
    print('✅ Utilisateur connecté - ID: $userId');

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final message = _messageController.text.trim();
      final success = await ChatService.sendRadioMessage(message);

      if (success) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message envoyé !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi du message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 GESTION D'ERREUR GLOBALE: Vérifier s'il y a une erreur critique
    if (_hasGlobalError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Radio Live'),
          backgroundColor: Colors.red.shade700,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 20),
                Text(
                  'Erreur Critique',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _globalErrorMessage ?? 'Une erreur inattendue s\'est produite',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    // 🚀 GESTION D'ERREUR GLOBALE: Tentative de récupération
                    _clearGlobalError();
                    _globalInitialized = false;
                    _initializeGlobalRadioSystem();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête fixe
          _buildHeader(),
          // Contenu défilable
          Expanded(
            child: ListView(
              children: [
                _buildRadioPlayer(),
                _buildPlayerControls(),
                _buildVolumeControl(),
                _buildChatHeader(),
                _buildChatMessages(),
              ],
            ),
          ),
          // Champ de saisie fixe en bas
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF4CB6FF),
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
          ),
          const Text(
            'Radio Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareRadio,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioPlayer() {
    final isLiveStream = (widget.streamUrl ?? embMissionRadioUrl) == 'https://stream.zeno.fm/rxi8n979ui1tv';
    return Column(
      children: [
        // Section bleue claire avec logo
        Container(
          color: const Color(0xFFE3F2FD),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              // Logo EMB dans un cercle rouge
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF5350),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.radio,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'EMB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'MISSION',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Badge EN DIRECT
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'EN DIRECT',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Section blanche avec titre et barre de progression
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              // Titre et sous-titre
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLiveStream ? 'EMB Mission Radio' : 'Prière du matin',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLiveStream ? 'En direct sur EMB Mission' : 'Avec Pasteur Michel - Matthieu 6:9-13',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Barre de progression (affichée seulement si ce n'est pas un flux live)
              if (!isLiveStream)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: const Color(0xFF4CB6FF),
                          inactiveTrackColor: Colors.grey.shade300,
                          thumbColor: Colors.transparent,
                          thumbShape: SliderComponentShape.noThumb,
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: 0.2,
                          onChanged: (_) {},
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '08:32',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Indicateur d'erreur
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _togglePlay();
                    },
                    child: const Text('Réessayer', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          
          // Contrôles de lecture
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton précédent
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 16),
              // Bouton play/pause
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey : const Color(0xFFEF5350),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : Consumer(
                        builder: (context, ref, child) {
                          final isPlaying = ref.watch(radioPlayingProvider);
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _isLoading ? null : _togglePlay,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 16),
              // Bouton suivant
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          
          // Indicateur de statut
          Consumer(
            builder: (context, ref, child) {
              final isPlaying = ref.watch(radioPlayingProvider);
              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.green.shade50 : Colors.grey.shade50,
                  border: Border.all(
                    color: isPlaying ? Colors.green.shade200 : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPlaying ? Icons.radio : Icons.radio_button_unchecked,
                      color: isPlaying ? Colors.green.shade600 : Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPlaying ? 'Radio en cours de lecture' : 'Radio arrêtée',
                      style: TextStyle(
                        color: isPlaying ? Colors.green.shade700 : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          

        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.volume_down, color: Colors.grey),
          SizedBox(
            width: 120, // Largeur réduite comme sur l'image
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: const Color(0xFF4CB6FF),
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: const Color(0xFF4CB6FF),
                overlayColor: const Color(0xFF4CB6FF).withOpacity(0.2),
              ),
              child: Slider(
                value: _volume,
                onChanged: (value) {
                  setState(() {
                    _volume = value;
                  });
                  _audioPlayer.setVolume(_volume);
                },
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            color: Colors.grey,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Chat en direct',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$_onlineUsers connectés',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    final messages = ref.watch(chatMessagesProvider);
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (messages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Aucun message pour le moment...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            )
          else
            ...messages.map((message) => _buildChatMessageFromData(message)),
          // Ajout d'espace en bas pour que le contenu soit visible au-dessus du champ de saisie
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Écrivez votre message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4CB6FF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSendingMessage 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _isSendingMessage ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage({
    required String name,
    required String message,
    required Color color,
    required String avatarText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Alignement vertical au centre
        children: [
          // Avatar coloré avec initiale
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: Text(
              avatarText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Message avec fond et nom coloré suivi du texte
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "$name: ",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: message,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageFromData(ChatMessage message) {
    final avatarText = message.username.isNotEmpty ? message.username[0].toUpperCase() : '?';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar avec image ou initiale
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: message.userAvatar != null ? NetworkImage(message.userAvatar!) : null,
            child: message.userAvatar == null ? Text(
              avatarText,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ) : null,
          ),
          const SizedBox(width: 10),
          // Message avec fond et nom coloré suivi du texte
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "${message.username}: ",
                      style: const TextStyle(
                        color: Color(0xFF4CB6FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: message.message,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 GESTION D'ERREUR GLOBALE: Méthode de récupération pour éviter les plantages
  static void _setGlobalError(String message) {
    _hasGlobalError = true;
    _globalErrorMessage = message;
    print('[RADIO] ❌ ERREUR GLOBALE: $message');
  }
  
  // 🚀 GESTION D'ERREUR GLOBALE: Méthode de récupération
  static void _clearGlobalError() {
    _hasGlobalError = false;
    _globalErrorMessage = null;
    print('[RADIO] ✅ Erreur globale effacée');
  }
  
  // 🚀 GESTION D'ERREUR GLOBALE: Vérification de l'état
  static bool get hasGlobalError => _hasGlobalError;
  static String? get globalErrorMessage => _globalErrorMessage;


} 