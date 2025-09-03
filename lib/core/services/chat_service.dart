import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String username;
  final String message;
  final DateTime timestamp;
  final String? userAvatar;
  final bool isSystemMessage;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.userAvatar,
    this.isSystemMessage = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Extraire les informations de l'avatar
    String username = '';
    String? userAvatar;
    
    if (json['avatar'] != null && json['avatar'] is List && (json['avatar'] as List).isNotEmpty) {
      final avatarData = json['avatar'][0];
      username = avatarData['username'] ?? '';
      userAvatar = avatarData['urlavatar'];
    }

    return ChatMessage(
      id: json['id'].toString(),
      userId: json['userId'] ?? '',
      username: username,
      message: json['message'] ?? '',
      timestamp: DateTime.parse(json['created_at']),
      userAvatar: userAvatar,
      isSystemMessage: false, // Pas de messages système dans cette API
    );
  }
}

class ChatService {
  static const String baseUrl = 'https://embmission.com/mobileappebm/api';

  /// Envoyer un message dans le chat radio
  static Future<bool> sendRadioMessage(String message) async {
    try {
      // Récupérer l'ID utilisateur depuis SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        print('❌ Utilisateur non connecté pour envoyer un message');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat_send_message_radio'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_user': userId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 'true') {
          print('✅ Message envoyé avec succès');
          return true;
        } else {
          print('❌ Erreur API: ${data['message']}');
          return false;
        }
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du message: $e');
      return false;
    }
  }

  /// Récupérer les messages du chat radio
  static Future<List<ChatMessage>> getRadioMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat_messages_radio'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📨 Réponse API chat: $data');
        
        if (data['status'] == 'true') {
          final List<dynamic> messagesJson = data['alldataradiolive'] ?? [];
          final messages = messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
          print('✅ ${messages.length} messages récupérés');
          return messages;
        } else {
          print('❌ API retourne status false');
        }
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des messages: $e');
      return [];
    }
  }


} 