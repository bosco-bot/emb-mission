import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/chat_service.dart';
import 'dart:async';

/// Provider pour les messages du chat radio
final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

/// Provider pour le statut de chargement des messages
final chatLoadingProvider = StateProvider<bool>((ref) => false);



/// Notifier pour gérer les messages du chat
class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);
  
  Timer? _refreshTimer;
  
  /// Charger les messages depuis l'API
  Future<void> loadMessages() async {
    try {
      // 🚨 PROTECTION MAXIMALE : Vérifier si le notifier est encore valide
      if (!mounted) {
        print('[CHAT] ⚠️ Notifier détruit, arrêt du chargement des messages');
        return;
      }
      
      final messages = await ChatService.getRadioMessages();
      
      // 🚨 DOUBLE VÉRIFICATION : Vérifier à nouveau après l'API
      if (!mounted) {
        print('[CHAT] ⚠️ Notifier détruit pendant l\'API, arrêt de la mise à jour');
        return;
      }
      
      // ✅ Mise à jour sécurisée de l'état
      state = messages;
      print('[CHAT] ✅ Messages mis à jour avec succès (${messages.length} messages)');
      
    } catch (e) {
      print('[CHAT] ❌ Erreur lors du chargement des messages: $e');
      
      // 🚨 Vérifier encore une fois en cas d'erreur
      if (!mounted) {
        print('[CHAT] ⚠️ Notifier détruit après erreur, arrêt du traitement');
        return;
      }
    }
  }
  
  /// Ajouter un nouveau message (après envoi réussi)
  void addMessage(ChatMessage message) {
    state = [message, ...state];
  }
  
  /// Démarrer le rafraîchissement automatique
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // 🚨 PROTECTION : Vérifier si le notifier est encore valide avant chaque appel
      if (mounted) {
        loadMessages();
      } else {
        print('[CHAT] ⚠️ Timer détecte notifier détruit, arrêt automatique');
        timer.cancel();
        _refreshTimer = null;
      }
    });
  }
  
  /// Arrêter le rafraîchissement automatique
  void stopAutoRefresh() {
    print('[CHAT] 🛑 Arrêt du rafraîchissement automatique');
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

 