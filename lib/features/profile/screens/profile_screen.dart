import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/features/profile/screens/edit_profile_screen.dart';
import 'package:emb_mission/core/widgets/home_back_button.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/services/app_usage_service.dart';
import 'package:emb_mission/core/services/preferences_service.dart';
import 'package:emb_mission/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Écran de profil utilisateur
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // État des switches (seulement notifications si besoin)
  bool _notificationsEnabled = true;
  Timer? _timer;
  int _hours = 0;

  @override
  void initState() {
    super.initState();
    _updateHours();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updateHours());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _updateHours() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('app_usage_seconds') ?? 0;
    int sessionSeconds = 0;
    if (AppUsageService.sessionStart != null) {
      sessionSeconds = DateTime.now().difference(AppUsageService.sessionStart!).inSeconds;
    }
    setState(() {
      _hours = ((seconds + sessionSeconds) / 3600).floor();
    });
  }

  // ✅ NOUVEAU: Widget réutilisable pour l'avatar
  Widget _buildAvatarWidget(String? avatarUrl, {double size = 80}) {
    ImageProvider imageProvider;
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        // ✅ Gestion des images base64
        try {
          final bytes = base64Decode(avatarUrl.split(',')[1]);
          imageProvider = MemoryImage(bytes);
        } catch (e) {
          print('❌ Erreur décodage base64: $e');
          imageProvider = const AssetImage('assets/images/default_avatar.png');
        }
      } else if (avatarUrl.startsWith('http')) {
        // ✅ URL réseau
        imageProvider = NetworkImage(avatarUrl);
      } else {
        // ✅ Fallback vers l'avatar par défaut
        imageProvider = const AssetImage('assets/images/default_avatar.png');
      }
    } else {
      // ✅ Aucun avatar défini
      imageProvider = const AssetImage('assets/images/default_avatar.png');
    }
    
    return Image(
      image: imageProvider,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // ✅ Gestion d'erreur si l'image ne peut pas être chargée
        print('❌ Erreur chargement avatar: $error');
        return Image.asset(
          'assets/images/default_avatar.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: const HomeBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              context.go('/profile/edit');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            _buildStatistics(),
            const SizedBox(height: 16),
            _buildAccountSection(),
            const SizedBox(height: 16),
            _buildSettingsSection(),
            // Marge en bas pour séparer de la barre de menus
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // En-tête du profil avec photo et informations
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Consumer(
                builder: (context, ref, _) {
                  final avatarUrl = ref.watch(userAvatarProvider) ?? '';
                  return _buildAvatarWidget(avatarUrl);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  // Affiche le nom de l'utilisateur connecté
                  // ignore: prefer_const_constructors
                  '',
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final userName = ref.watch(userNameProvider) ?? 'Utilisateur';
                    // Récupère la date de création du compte
                    final user = AuthService().currentUser;
                    final creationDate = user?.metadata.creationTime;
                    String formattedDate = '';
                    if (creationDate != null) {
                      // Formatage en 'MMMM yyyy' (ex: janvier 2022)
                      formattedDate = '${_monthName(creationDate.month)} ${creationDate.year}';
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate.isNotEmpty
                              ? 'Membre depuis $formattedDate'
                              : 'Membre',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Fidèle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section des statistiques
  Widget _buildStatistics() {
    final userId = ref.watch(userIdProvider) ?? '';
    return FutureBuilder<Map<String, int>>(
      future: AppUsageService.fetchProfileStats(userId),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'prieres': 0, 'temoignages': 0};
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatItem('${stats['prieres']}', 'Prières', Colors.blue),
              _buildStatItem('${stats['temoignages']}', 'Témoignages', Colors.green),
              _buildStatItem(_hours.toString(), 'Heures', Colors.purple),
            ],
          ),
        );
      },
    );
  }

  // Item de statistique
  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section du compte
  Widget _buildAccountSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mon Compte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildAccountItem(
            'Informations personnelles',
            Icons.person_outline,
            _showPersonalInfoBottomSheet,
          ),
          _buildAccountItem(
            'Préférences de contenu',
            Icons.tune,
            _showContentPreferencesBottomSheet,
          ),
        ],
      ),
    );
  }

  // Item de la section compte
  Widget _buildAccountItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // Section des paramètres
  Widget _buildSettingsSection() {
    final prefsService = ref.watch(preferencesServiceProvider);
    final isDarkMode = prefsService.isDarkMode();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Paramètres',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSettingsSwitchItem(
            'Notifications push',
            _notificationsEnabled,
            (value) async {
              final userId = ref.read(userIdProvider) ?? '';
              print('userId envoyé: $userId');
              print('notifypush envoyé: ${value ? 1 : 0}');
              final url = Uri.parse('https://embmission.com/mobileappebm/api/save_param_user');
              final response = await http.post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id_user': userId,
                  'notifypush': value ? 1 : 0,
                }),
              );
              print('Status: ${response.statusCode}, Body: ${response.body}');
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['success'] == 'true') {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Préférence notification enregistrée !'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de la sauvegarde.'), backgroundColor: Colors.red),
                    );
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erreur réseau.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          _buildSettingsSwitchItem(
            'Mode sombre',
            isDarkMode,
            (value) async {
              await prefsService.setDarkMode(value);
              setState(() {});
              ref.invalidate(preferencesServiceProvider);
              ref.invalidate(themeProvider);
            },
          ),
        ],
      ),
    );
  }

  // Item de paramètre avec switch
  Widget _buildSettingsSwitchItem(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  void _showPersonalInfoBottomSheet() {
    final userName = ref.read(userNameProvider) ?? 'Utilisateur';
    final user = AuthService().currentUser;
    final email = user?.email ?? 'Non renseigné';
    final creationDate = user?.metadata.creationTime;
    String formattedDate = '';
    if (creationDate != null) {
      formattedDate = '${_monthName(creationDate.month)} ${creationDate.year}';
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Informations personnelles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(userName, style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.email, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    email.replaceRange(3, email.indexOf('@'), '***'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate.isNotEmpty
                        ? 'Inscrit depuis $formattedDate'
                        : 'Date d’inscription inconnue',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

            ],
          ),
        );
      },
    );
  }

  void _showContentPreferencesBottomSheet() async {
    final userId = ref.read(userIdProvider) ?? '';
    List<String> allCategories = ['Bible', 'Prières', 'Témoignages'];
    Set<String> selectedCategories = {};
    bool isLoading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> fetchPrefs() async {
              final url = Uri.parse('https://embmission.com/mobileappebm/api/user_content_preferences?user_id=$userId');
              final response = await http.get(url);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['stat'] == 'success') {
                  final List prefs = data['data'] ?? [];
                  setState(() {
                    selectedCategories = prefs.map<String>((e) => e['categorie_preferences'].toString()).toSet();
                    isLoading = false;
                  });
                } else {
                  setState(() { isLoading = false; });
                }
              } else {
                setState(() { isLoading = false; });
              }
            }

            if (isLoading) {
              fetchPrefs();
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Text('Catégories préférées', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...allCategories.map((cat) => CheckboxListTile(
                              value: selectedCategories.contains(cat),
                              title: Text(cat),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedCategories.add(cat);
                                  } else {
                                    selectedCategories.remove(cat);
                                  }
                                });
                              },
                            )),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse('https://embmission.com/mobileappebm/api/save_user_content_preferences');
                              final response = await http.post(
                                url,
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'id_user': userId,
                                  'categories': selectedCategories.toList(),
                                  'langue': 'fr',
                                }),
                              );
                              final data = jsonDecode(response.body);
                              if (response.statusCode == 200 && data['success'] == 'true') {
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Préférences enregistrées !')),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Erreur lors de la sauvegarde.'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }


}

String _monthName(int month) {
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  return (month >= 1 && month <= 12) ? months[month - 1] : '';
}
