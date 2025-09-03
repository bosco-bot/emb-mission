import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/login_screen.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  XFile? _avatarFile;
  String? _avatarUrl;

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

  @override
  Widget build(BuildContext context) {
    final Color embBlue = const Color(0xFF64B5F6);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
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
                'Créer un compte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Rejoignez EMB Mission',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Champ avatar
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: embBlue, width: 4),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _avatarFile != null
                                    ? FileImage(File(_avatarFile!.path))
                                    : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: embBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Prénom',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre prénom';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Nom',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre nom';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Adresse email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre adresse email';
                          }
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                            return 'Adresse email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un mot de passe';
                          }
                          if (value.length < 6) {
                            return 'Le mot de passe doit contenir au moins 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Bouton S'inscrire
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: embBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isLoading ? null : () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              await _registerUser();
                            }
                          },
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text("S'inscrire", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bouton Se connecter
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: embBlue,
                            side: BorderSide(color: embBlue, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const LoginScreen(),
                            );
                          },
                          child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Méthode pour gérer l'inscription de l'utilisateur
  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Appeler le service d'authentification pour créer le compte
      final userCredential = await _authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('userCredential: ' + userCredential.toString());
      print('userCredential.user: ' + userCredential.user.toString());

      // VÉRIFIER SI L'INSCRIPTION A RÉUSSI
      if (userCredential.user != null) {
        String? avatarUrl;
        bool avatarError = false;
        if (_avatarFile != null) {
          try {
            avatarUrl = await _uploadAvatarToFirebase(userCredential.user!.uid);
            print('URL AVATAR ENVOYEE A FIREBASE AUTH: ' + (avatarUrl ?? 'null'));
            await userCredential.user!.updatePhotoURL(avatarUrl);
            ref.read(userAvatarProvider.notifier).state = avatarUrl;
          } catch (e, stack) {
            avatarError = true;
            print('Erreur lors de l\'upload ou updatePhotoURL: $e');
            print('Stacktrace: $stack');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur avatar: $e'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 8),
                ),
              );
            }
          }
        } else {
          try {
            await userCredential.user!.updatePhotoURL(
              'https://img.icons8.com/ios-filled/100/000000/user-male-circle.png'
            );
            ref.read(userAvatarProvider.notifier).state = 'https://img.icons8.com/ios-filled/100/000000/user-male-circle.png';
          } catch (e) {
            print('Erreur lors de l\'updatePhotoURL par défaut: $e');
          }
        }
        try {
          final backendResponse = await registerUserToBackend(
            uid: userCredential.user!.uid,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: _emailController.text.trim(),
            avatarFile: _avatarFile,
          );
          print('Réponse backend : ' + backendResponse.toString());
        } catch (e) {
          print('Erreur backend : $e');
        }
        // Afficher un message de succès
        if (mounted) {
          // Afficher le message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Inscription réussie ! Redirection vers la connexion...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Attendre 3 secondes puis rediriger
          await Future.delayed(Duration(seconds: 3));

          // Rediriger vers la page de connexion
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'inscription : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> registerUserToBackend({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    XFile? avatarFile,
  }) async {
    String? avatarBase64;
    if (avatarFile != null) {
      final bytes = await avatarFile.readAsBytes();
      final ext = avatarFile.path.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
      avatarBase64 = 'data:$mime;base64,' + base64Encode(bytes);
    } else {
      // Charger l'avatar par défaut depuis les assets
      final byteData = await rootBundle.load('assets/images/default_avatar.png');
      final bytes = byteData.buffer.asUint8List();
      avatarBase64 = 'data:image/png;base64,' + base64Encode(bytes);
    }
    final url = Uri.parse('https://embmission.com/mobileappebm/api/saveusersebm');
    final body = {
      'uid': uid,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'avatar': avatarBase64,
    };
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de l\'enregistrement sur le backend');
    }
  }
} 