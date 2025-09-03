import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/widgets/home_back_button.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class NotificationPreferences {
  final bool liveBroadcasts;
  final bool newContent;
  final bool communityPrayers;
  final bool privateMessages;

  NotificationPreferences({
    this.liveBroadcasts = true,
    this.newContent = true,
    this.communityPrayers = false,
    this.privateMessages = false,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      liveBroadcasts: json['live_broadcasts'] == 1,
      newContent: json['new_content'] == 1,
      communityPrayers: json['community_prayers'] == 1,
      privateMessages: json['private_messages'] == 1,
    );
  }
}

final notificationPreferencesProvider = FutureProvider.family<NotificationPreferences, String>((ref, userId) async {
  final url = Uri.parse('https://embmission.com/mobileappebm/api/notification_preferences?id_user=$userId');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['statnotify'] == 'success' && data['datanotify'] is List && data['datanotify'].isNotEmpty) {
      return NotificationPreferences.fromJson(data['datanotify'][0]);
    }
  }
  return NotificationPreferences();
});

class DeviceUser {
  final int id;
  final String deviceName;
  final String deviceType;
  final String deviceIdentifier;
  final String lastSeen;
  final String createdAt;

  DeviceUser({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.deviceIdentifier,
    required this.lastSeen,
    required this.createdAt,
  });

  factory DeviceUser.fromJson(Map<String, dynamic> json) {
    return DeviceUser(
      id: json['id'] ?? 0,
      deviceName: json['device_name'] ?? '',
      deviceType: json['device_type'] ?? '',
      deviceIdentifier: json['device_identifier'] ?? '',
      lastSeen: json['last_seen'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

final devicesUserProvider = FutureProvider.family<List<DeviceUser>, String>((ref, userId) async {
  final url = Uri.parse('https://embmission.com/mobileappebm/api/call_device_user?id_user=$userId');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['statdevicesuser'] == 'success' && data['datadevicesuser'] is List) {
      return (data['datadevicesuser'] as List)
          .map((e) => DeviceUser.fromJson(e))
          .toList();
    }
  }
  return [];
});

final rgpdPreferencesProvider = FutureProvider.family<Map<String, bool>, String>((ref, userId) async {
  return await fetchRgpdPreferences(userId);
});

Future<Map<String, bool>> fetchRgpdPreferences(String userId) async {
  final url = Uri.parse('https://embmission.com/mobileappebm/api/get_préférences_rgpd');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'id_user': userId}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['statrgpd'] == 'success' && data['datargpd'] is List && data['datargpd'].isNotEmpty) {
      final prefs = data['datargpd'][0];
      return {
        'collecte_anonyme': prefs['collecte_anonyme'] == 1,
        'partage_statistiques': prefs['partage_statistiques'] == 1,
      };
    } else {
      throw Exception('Aucune préférence RGPD trouvée');
    }
  } else {
    throw Exception('Erreur lors de la récupération des préférences RGPD');
  }
}

Future<bool> saveRgpdPreferences({
  required String userId,
  required bool collecteAnonyme,
  required bool partageStatistiques,
}) async {
  final url = Uri.parse('https://embmission.com/mobileappebm/api/save_préférences_rgpd');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'id_user': userId,
      'collecte_anonyme': collecteAnonyme ? 1 : 0,
      'partage_statistiques': partageStatistiques ? 1 : 0,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['success'] == "true";
  } else {
    throw Exception('Erreur lors de la sauvegarde des préférences RGPD');
  }
}

Future<bool> deleteUserData(String userId) async {
  final url = Uri.parse('https://embmission.com/mobileappebm/api/gdpr_delete_user');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'id_user': userId}),
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['success'] == "true";
  } else {
    throw Exception('Erreur lors de la suppression des données');
  }
}

class RgpdPreferencesSection extends ConsumerStatefulWidget {
  final String userId;
  const RgpdPreferencesSection({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<RgpdPreferencesSection> createState() => _RgpdPreferencesSectionState();
}

class _RgpdPreferencesSectionState extends ConsumerState<RgpdPreferencesSection> {
  bool? collecteAnonyme;
  bool? partageStatistiques;
  bool isLoading = false;

  Future<void> _updatePreference({bool? collecte, bool? partage}) async {
    setState(() => isLoading = true);
    try {
      await saveRgpdPreferences(
        userId: widget.userId,
        collecteAnonyme: collecte ?? collecteAnonyme ?? true,
        partageStatistiques: partage ?? partageStatistiques ?? true,
      );
      if (collecte != null) collecteAnonyme = collecte;
      if (partage != null) partageStatistiques = partage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Préférence enregistrée !')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde')), 
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(rgpdPreferencesProvider(widget.userId));
    return prefsAsync.when(
      loading: () => const SizedBox.shrink(), // Plus de loading ici
      error: (err, _) => Center(child: Text('Erreur: $err')),
      data: (prefs) {
        collecteAnonyme ??= prefs['collecte_anonyme']!;
        partageStatistiques ??= prefs['partage_statistiques']!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text('Collecte anonyme'),
              value: collecteAnonyme!,
              activeColor: Colors.white,
              activeTrackColor: Color(0xFF4CB6FF),
              onChanged: isLoading
                  ? null
                  : (val) => _updatePreference(collecte: val),
            ),
            SwitchListTile(
              title: Text('Partage avec partenaires'),
              value: partageStatistiques!,
              activeColor: Colors.white,
              activeTrackColor: Color(0xFF4CB6FF),
              onChanged: isLoading
                  ? null
                  : (val) => _updatePreference(partage: val),
            ),
          ],
        );
      },
    );
  }
}

class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  ConsumerState<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends ConsumerState<AdvancedSettingsScreen> {
  // État des switches RGPD et synchronisation (local seulement)
  bool collecteAnonymeEnabled = false;
  bool partageStatistiquesEnabled = true;

  // Ajout : état de chargement pour chaque switch de notification
  bool _loadingLive = false;
  bool _loadingContent = false;
  bool _loadingPrayers = false;
  bool _loadingMessages = false;
  bool _addingDevice = false;

  // État de chargement global
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Charger toutes les données en parallèle
      final userId = 'CbmPcejiGNdm6ly4ndskTtjdQy33';
      await Future.wait([
        // Précharger les préférences de notifications
        _preloadNotificationPreferences(userId),
        // Précharger les préférences RGPD
        _preloadRgpdPreferences(userId),
        // Précharger la liste des appareils
        _preloadDevices(userId),
      ]);
      
      // Invalider les providers pour forcer leur rechargement
      ref.invalidate(notificationPreferencesProvider(userId));
      ref.invalidate(rgpdPreferencesProvider(userId));
      ref.invalidate(devicesUserProvider(userId));
      
      // Attendre un peu pour s'assurer que les providers sont prêts
      await Future.delayed(const Duration(milliseconds: 200));
      
    } catch (e) {
      print('❌ Erreur lors du chargement initial: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _preloadNotificationPreferences(String userId) async {
    try {
      final url = Uri.parse('https://embmission.com/mobileappebm/api/notification_preferences?id_user=$userId');
      final response = await http.get(url);
      print('✅ Préférences notifications préchargées');
    } catch (e) {
      print('❌ Erreur préchargement notifications: $e');
    }
  }

  Future<void> _preloadRgpdPreferences(String userId) async {
    try {
      final url = Uri.parse('https://embmission.com/mobileappebm/api/get_préférences_rgpd');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_user': userId}),
      );
      print('✅ Préférences RGPD préchargées');
    } catch (e) {
      print('❌ Erreur préchargement RGPD: $e');
    }
  }

  Future<void> _preloadDevices(String userId) async {
    try {
      final url = Uri.parse('https://embmission.com/mobileappebm/api/call_device_user?id_user=$userId');
      final response = await http.get(url);
      print('✅ Appareils préchargés');
    } catch (e) {
      print('❌ Erreur préchargement appareils: $e');
    }
  }

  // Fonction pour mettre à jour les préférences via l'API
  Future<void> _updateNotificationPrefs({
    required String userId,
    required NotificationPreferences prefs,
    required String key,
    required bool newValue,
    required WidgetRef ref,
  }) async {
    setState(() {
      if (key == 'live_broadcasts') _loadingLive = true;
      if (key == 'new_content') _loadingContent = true;
      if (key == 'community_prayers') _loadingPrayers = true;
      if (key == 'private_messages') _loadingMessages = true;
    });
    final url = Uri.parse('https://embmission.com/mobileappebm/api/misajour_notify_preferences');
    final body = {
      'id_user': userId,
      'live_broadcasts': key == 'live_broadcasts' ? (newValue ? 1 : 0) : (prefs.liveBroadcasts ? 1 : 0),
      'new_content': key == 'new_content' ? (newValue ? 1 : 0) : (prefs.newContent ? 1 : 0),
      'community_prayers': key == 'community_prayers' ? (newValue ? 1 : 0) : (prefs.communityPrayers ? 1 : 0),
      'private_messages': key == 'private_messages' ? (newValue ? 1 : 0) : (prefs.privateMessages ? 1 : 0),
    };
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        // Rafraîchir le provider
        ref.invalidate(notificationPreferencesProvider(userId));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour des préférences.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    } finally {
      setState(() {
        if (key == 'live_broadcasts') _loadingLive = false;
        if (key == 'new_content') _loadingContent = false;
        if (key == 'community_prayers') _loadingPrayers = false;
        if (key == 'private_messages') _loadingMessages = false;
      });
    }
  }

  Future<void> _addDevice(String userId) async {
    setState(() { _addingDevice = true; });
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = '';
    String deviceType = '';
    String deviceId = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model ?? 'Android';
        deviceType = 'Android';
        deviceId = androidInfo.id ?? '';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.utsname.machine ?? 'iPhone';
        deviceType = 'iOS';
        deviceId = iosInfo.identifierForVendor ?? '';
      } else {
        deviceName = 'Unknown';
        deviceType = 'Unknown';
        deviceId = '';
      }

      final url = Uri.parse('https://embmission.com/mobileappebm/api/add_device');
      final body = {
        'user_id': userId,
        'device_name': deviceName,
        'device_type': deviceType,
        'device_identifier': deviceId,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appareil ajouté avec succès !')),
        );
        // TODO: Rafraîchir la liste des appareils ici si elle devient dynamique
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'ajout de l\'appareil.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    } finally {
      setState(() { _addingDevice = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remplace par l'ID utilisateur réel dans ton app !
    final userId = 'CbmPcejiGNdm6ly4ndskTtjdQy33';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB6FF),
        elevation: 0,
        leading: const HomeBackButton(color: Colors.white),
        title: const Text(
          'Paramètres Avancés',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    icon: Icons.shield_outlined,
                    iconColor: Colors.blue,
                    title: 'Gestion des données (RGPD)',
                  ),
                  RgpdPreferencesSection(userId: userId),
                  _buildDeleteDataButton(),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildSectionHeader(
                    icon: Icons.notifications_outlined,
                    iconColor: Colors.green,
                    title: 'Préférences notifications',
                  ),
                  // Section dynamique Riverpod pour les notifications
                  Builder(
                    builder: (context) {
                      final notificationPrefsAsync = ref.watch(notificationPreferencesProvider(userId));
                      return notificationPrefsAsync.when(
                        loading: () => const SizedBox.shrink(), // Plus de loading ici
                        error: (error, stack) => Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Erreur de chargement des préférences'),
                        )),
                        data: (prefs) => Column(
                          children: [
                            _buildToggleOption(
                              title: 'Diffusions en direct',
                              subtitle: '',
                              value: prefs.liveBroadcasts,
                              onChanged: (val) => _updateNotificationPrefs(
                                userId: userId,
                                prefs: prefs,
                                key: 'live_broadcasts',
                                newValue: val,
                                ref: ref,
                              ),
                              loading: _loadingLive,
                            ),
                            _buildToggleOption(
                              title: 'Nouveaux contenus',
                              subtitle: '',
                              value: prefs.newContent,
                              onChanged: (val) => _updateNotificationPrefs(
                                userId: userId,
                                prefs: prefs,
                                key: 'new_content',
                                newValue: val,
                                ref: ref,
                              ),
                              loading: _loadingContent,
                            ),
                            _buildToggleOption(
                              title: 'Prières communautaires',
                              subtitle: '',
                              value: prefs.communityPrayers,
                              onChanged: (val) => _updateNotificationPrefs(
                                userId: userId,
                                prefs: prefs,
                                key: 'community_prayers',
                                newValue: val,
                                ref: ref,
                              ),
                              loading: _loadingPrayers,
                            ),
                            _buildToggleOption(
                              title: 'Messages privés',
                              subtitle: '',
                              value: prefs.privateMessages,
                              onChanged: (val) => _updateNotificationPrefs(
                                userId: userId,
                                prefs: prefs,
                                key: 'private_messages',
                                newValue: val,
                                ref: ref,
                              ),
                              loading: _loadingMessages,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildSectionHeader(
                    icon: Icons.sync_outlined,
                    iconColor: Colors.blue,
                    title: 'Synchronisation multi-appareils',
                  ),
                  _buildDevicesList(),
                  _buildAddDeviceButton(),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildSectionHeader(
                    icon: Icons.gavel_outlined,
                    iconColor: Colors.indigo,
                    title: 'Informations légales',
                  ),
                  _buildLegalPagesButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool loading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF4CB6FF),
                ),
        ],
      ),
    );
  }

  Widget _buildDeleteDataButton() {
    final userId = 'CbmPcejiGNdm6ly4ndskTtjdQy33'; // Remplace par l'ID réel si besoin
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Confirmation'),
                content: Text('Voulez-vous vraiment supprimer toutes vos données ? Cette action est irréversible.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Supprimer')),
                ],
              ),
            );
            if (confirmed == true) {
              try {
                final success = await deleteUserData(userId);
                if (success) {
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Toutes vos données ont été supprimées.')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur lors de la suppression des données.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la suppression des données.')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEE8E8),
            foregroundColor: Colors.red,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Supprimer toutes mes données',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    final userId = 'CbmPcejiGNdm6ly4ndskTtjdQy33';
    return Builder(
      builder: (context) {
        final devicesAsync = ref.watch(devicesUserProvider(userId));
        return FutureBuilder<String>(
          future: _getCurrentDeviceIdentifier(),
          builder: (context, snapshot) {
            final currentDeviceId = snapshot.data ?? '';
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: devicesAsync.when(
                  loading: () => const SizedBox.shrink(), // Plus de loading ici
                  error: (error, stack) => const Center(child: Text('Erreur de chargement des appareils')),
                  data: (devices) {
                    if (devices.isEmpty) {
                      return const Center(child: Text('Aucun appareil connecté'));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Appareils connectés',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '${devices.length}/5',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...devices.map((device) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDeviceItem(
                            icon: device.deviceType.toLowerCase().contains('ios')
                                ? Icons.phone_iphone
                                : Icons.android,
                            name: device.deviceName,
                            status: device.deviceIdentifier == currentDeviceId ? 'Actuel' : 'Synchronisé',
                          ),
                        )),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _getCurrentDeviceIdentifier() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? '';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? '';
    }
    return '';
  }

  Widget _buildDeviceItem({
    required IconData icon,
    required String name,
    required String status,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey.shade600,
          size: 24,
        ),
        const SizedBox(width: 16),
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '- $status',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddDeviceButton() {
    // Remplace par l'ID utilisateur réel dans ton app !
    final userId = 'CbmPcejiGNdm6ly4ndskTtjdQy33';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _addingDevice ? null : () => _addDevice(userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CB6FF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _addingDevice
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Ajouter un appareil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLegalPagesButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go('/settings/legal'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pages légales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Confidentialité, conditions, contact',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
