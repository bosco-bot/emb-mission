import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Écran de modification du profil utilisateur
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Contrôleurs pour les champs de texte
  TextEditingController? _nameController;
  TextEditingController? _firstNameController;
  TextEditingController? _lastNameController;
  final TextEditingController _bioController = TextEditingController(
    text: 'Servante de Dieu, passionnée par la prière et l\'évangélisation.',
  );
  
  // États des switches
  bool _prayerNotificationsEnabled = true;
  bool _bibleStudyRemindersEnabled = false;
  XFile? _avatarFile;
  String? _avatarUrl;
  bool? _communityPrayers;
  bool? _rapelEtudeBiblique;
  bool _spiritualLoading = false;

  // Ajoute les variables d'état pour stocker les valeurs à sauvegarder
  bool? _pendingCommunityPrayers;
  bool? _pendingRapelEtudeBiblique;
  bool? _pendingPublicProfile;
  String? _pendingAvatarBase64;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _fetchAndSetNameFields();
    _loadExistingAvatar(); // ✅ NOUVEAU: Charger l'avatar existant
  }

  // ✅ NOUVELLE MÉTHODE: Charger l'avatar existant
  Future<void> _loadExistingAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingAvatar = prefs.getString('user_avatar');
      if (existingAvatar != null && existingAvatar.isNotEmpty) {
        setState(() {
          _avatarUrl = existingAvatar;
        });
        print('✅ Avatar existant chargé depuis le stockage local');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement de l\'avatar existant: $e');
    }
  }

  // ✅ NOUVEAU: Widget réutilisable pour l'avatar
  Widget _buildAvatarWidget(String? avatarUrl, {double size = 120}) {
    ImageProvider imageProvider;
    
    if (_avatarFile != null) {
      // ✅ Nouvel avatar sélectionné
      imageProvider = FileImage(File(_avatarFile!.path));
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
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

  Future<void> _fetchAndSetNameFields() async {
    final user = AuthService().currentUser;
    final userId = user?.uid;
    if (userId == null) return;
    try {
      final url = Uri.parse('https://embmission.com/mobileappebm/api/nom_prenom_profil?id_user=$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _lastNameController?.text = data['nom'] ?? '';
          _firstNameController?.text = data['prenom'] ?? '';
          _bioController.text = data['bio'] ?? '';
        }
      }
    } catch (e) {
      // ignore erreur, laisse vide
    }
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController?.dispose();
    _lastNameController?.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () async {
                final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                Navigator.pop(context, photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () async {
                final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                Navigator.pop(context, photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );
    if (pickedFile != null) {
      setState(() {
        _avatarFile = pickedFile;
      });
    }
  }

  Future<String?> _uploadAvatarToFirebase(String uid) async {
    if (_avatarFile == null) return null;
    final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
    try {
      await ref.putData(await _avatarFile!.readAsBytes());
      return await ref.getDownloadURL();
    } catch (e, stack) {
      print('Erreur lors de l\'upload ou updatePhotoURL: $e');
      print('Stacktrace: $stack');
      return null;
    }
  }

  // Modifie le bouton Sauvegarder pour tout envoyer à l'API globale
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Modifier le profil',
          style: TextStyle(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _savingProfile ? null : () async {
              setState(() { _savingProfile = true; });
              final user = AuthService().currentUser;
              final userId = user?.uid;
              if (userId == null) return;
              // Avatar en base64
              String? avatarBase64;
              if (_avatarFile != null) {
                final bytes = await _avatarFile!.readAsBytes();
                final ext = _avatarFile!.path.split('.').last.toLowerCase();
                final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
                avatarBase64 = 'data:$mime;base64,' + base64Encode(bytes);
              } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
                avatarBase64 = _avatarUrl;
              } else {
                // Charger l'avatar par défaut depuis les assets
                final byteData = await DefaultAssetBundle.of(context).load('assets/images/default_avatar.png');
                final bytes = byteData.buffer.asUint8List();
                avatarBase64 = 'data:image/png;base64,' + base64Encode(bytes);
              }
              // Prépare le body
              final body = {
                'id_user': userId,
                'rapel_etude_biblique': (_pendingRapelEtudeBiblique ?? false) ? 1 : 0,
                'community_prayers': (_pendingCommunityPrayers ?? false) ? 1 : 0,
                'public_profile': (_pendingPublicProfile ?? false) ? 1 : 0,
                'avatar': avatarBase64,
                'bio': _bioController.text,
              };
              try {
                final url = Uri.parse('https://embmission.com/mobileappebm/api/misajour_global_profil');
                final response = await http.post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                );
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  if (data['success'] == 'true') {
                    // ✅ NOUVEAU: Mettre à jour le provider d'avatar
                    if (avatarBase64 != null) {
                      ref.read(userAvatarProvider.notifier).state = avatarBase64;
                      
                      // ✅ NOUVEAU: Sauvegarder localement
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('user_avatar', avatarBase64);
                      
                      // ✅ NOUVEAU: Mettre à jour Firebase Auth si c'est une URL
                      if (avatarBase64.startsWith('http')) {
                        try {
                          await user?.updatePhotoURL(avatarBase64);
                          print('✅ Avatar mis à jour dans Firebase Auth');
                        } catch (e) {
                          print('⚠️ Erreur mise à jour Firebase Auth: $e');
                        }
                      }
                      
                      print('✅ Avatar mis à jour dans le provider et localement');
                    }
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil mis à jour !'), backgroundColor: Colors.green),
                      );
                      Navigator.pop(context);
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erreur lors de la mise à jour.'), backgroundColor: Colors.red),
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
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() { _savingProfile = false; });
              }
            },
            child: _savingProfile
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text(
                    'Sauvegarder',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfilePhotoSection(),
            _buildNameSection(),
            _buildBioSection(),
            _buildPreferencesSection(),
            _buildConfidentialitySection(),
            const SizedBox(height: 50), // Marge en bas plus grande
          ],
        ),
      ),
    );
  }

  // Section de la photo de profil
  Widget _buildProfilePhotoSection() {
    final user = AuthService().currentUser;
    final userId = user?.uid;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
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
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Section des noms
  Widget _buildNameSection() {
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
              'Informations personnelles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Section de la bio
  Widget _buildBioSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              'Bio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Parlez-nous de vous...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Section des préférences
  Widget _buildPreferencesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              'Préférences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Rappels d\'étude biblique'),
            subtitle: const Text('Recevoir des notifications pour vos études bibliques'),
            value: _pendingRapelEtudeBiblique ?? false,
            onChanged: (value) {
              setState(() {
                _pendingRapelEtudeBiblique = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Prières communautaires'),
            subtitle: const Text('Recevoir des notifications pour les prières communautaires'),
            value: _pendingCommunityPrayers ?? false,
            onChanged: (value) {
              setState(() {
                _pendingCommunityPrayers = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // Section de la confidentialité
  Widget _buildConfidentialitySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              'Confidentialité',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Profil public'),
            subtitle: const Text('Permettre aux autres utilisateurs de voir votre profil'),
            value: _pendingPublicProfile ?? false,
            onChanged: (value) {
              setState(() {
                _pendingPublicProfile = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
