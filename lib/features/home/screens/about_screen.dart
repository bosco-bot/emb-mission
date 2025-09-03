import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color embBlue = Color(0xFF64B5F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: embBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'À propos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
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
              const Text(
                'EMB-Mission',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Matthieu 28:19-20',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                textAlign: TextAlign.left,
                text: const TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black, height: 1.5),
                  children: [
                    TextSpan(
                      text: 'EMB-Mission Inc.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' (L\'Éternel est Mon Berger - Mission) est une\n',
                    ),
                    TextSpan(
                      text: 'organisation chrétienne sans but lucratif, enraciné dans l\'Évangile de la\n',
                    ),
                    TextSpan(
                      text: 'bonne nouvelle de Jésus-Christ.\n',
                    ),
                    TextSpan(
                      text: 'Nous répondons à l\'appel de ',
                    ),
                    TextSpan(
                      text: 'Matthieu 28 :19-20',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '.\n',
                    ),
                    TextSpan(
                      text: 'Notre mission principale : ',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'Évangélisation. Faire de tout un chacun un\n',
                    ),
                    TextSpan(
                      text: 'disciple de Jésus-Christ, à travers la diffusion de sa parole via les médias.\n',
                    ),
                    TextSpan(
                      text: 'Notre engagement : ',
                    ),
                    TextSpan(
                      text: 'Toucher les cœurs, fortifier les croyants et élargir la portée de l\'Évangile au sein des communautés.\n',
                    ),
                    TextSpan(
                      text: 'Notre devise : ',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'Amour, Sainteté et Engagement.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Valeurs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildValueIcon(Icons.favorite, 'Amour', Colors.red),
                  _buildValueIcon(Icons.auto_awesome, 'Sainteté', Colors.purple),
                  _buildValueIcon(Icons.commit, 'Engagement', Colors.orange),
                ],
              ),
              const SizedBox(height: 32),
              // Équipe
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notre équipe',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: embBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildTeamMember('Tshoule KAFUKA', 'Président Fondateur', 'jean.dupont@email.com'),
              _buildTeamMember('Sandra NYABOLIA', 'Administratrice', 'marie.dubois@email.com'),
              const SizedBox(height: 32),
              // Contact
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: embBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.email, color: Colors.black54),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _showContactBottomSheet(context);
                    },
                    onLongPress: () async {
                      await Clipboard.setData(const ClipboardData(text: 'contact@embmission.com'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse copiée dans le presse-papier')),
                      );
                    },
                    child: const Text(
                      'contact@embmission.com',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.language, color: Colors.black54),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      const raw = 'https://embmission.com/';
                      final uri = Uri.parse(raw);
                      try {
                        // Ouvrir dans une webview intégrée si possible
                        bool ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
                        if (!ok) {
                          // Fallback: navigateur externe
                          ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                        if (!ok) {
                          throw Exception('Impossible d\'ouvrir l\'URL');
                        }
                      } catch (_) {
                        // Rien d'autre à faire; on garde le tap silencieux si aucune app ne peut ouvrir
                      }
                    },
                    child: const Text(
                      'embmission.com',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final formKey = GlobalKey<FormState>();
            final nameController = TextEditingController();
            final emailController = TextEditingController();
            final subjectController = TextEditingController(text: 'Contact EMB');
            final messageController = TextEditingController(text: 'Bonjour,');
            bool isSending = false;
            return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.mail_outline, color: Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contacter EMB-Mission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text('Envoyez-nous un message', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      // Form
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Votre nom',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Adresse e-mail',
                                    hintText: 'ex: nom@domaine.com',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'E-mail requis';
                                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                                    if (!ok) return 'E-mail invalide';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: subjectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Sujet',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Sujet requis' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: messageController,
                                  minLines: 5,
                                  maxLines: 10,
                                  decoration: const InputDecoration(
                                    labelText: 'Message',
                                    hintText: 'Votre message…',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Message requis' : null,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Annuler'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isSending
                                            ? null
                                            : () async {
                                                if (!formKey.currentState!.validate()) return;
                                                setState(() => isSending = true);
                                                final uri = Uri.parse('https://embmission.com/mobileappebm/api/contact_apropos');
                                                final payload = {
                                                  'name': nameController.text.trim(),
                                                  'email': emailController.text.trim(),
                                                  'sujet': subjectController.text.trim(),
                                                  'message': messageController.text.trim(),
                                                };
                                                try {
                                                  final resp = await http
                                                      .post(
                                                        uri,
                                                        headers: {'Content-Type': 'application/json'},
                                                        body: jsonEncode(payload),
                                                      )
                                                      .timeout(const Duration(seconds: 20));
                                                  if (resp.statusCode == 200) {
                                                    final data = jsonDecode(resp.body);
                                                    final ok = (data['statutmail'] == 'success');
                                                    if (ok) {
                                                      if (context.mounted) {
                                                        Navigator.of(context).pop();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Message envoyé avec succès')),
                                                        );
                                                      }
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Échec de l\'envoi: ${data['statutmail'] ?? 'inconnu'}')),
                                                      );
                                                    }
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Erreur réseau: ${resp.statusCode}')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Erreur: $e')),
                                                  );
                                                } finally {
                                                  setState(() => isSending = false);
                                                }
                                              },
                                        child: isSending
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Text('Envoyer'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildValueIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.black87)),
      ],
    );
  }

  Widget _buildTeamMember(String name, String role, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF64B5F6),
            radius: 18,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  role,
                  style: TextStyle(
                    color: (role == 'Président Fondateur' || role == 'Administratrice') ? embBlue : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.email, color: Colors.black26, size: 18),
        ],
      ),
    );
  }
} 