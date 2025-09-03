import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
    setState(() {
      _rememberMe = rememberMe;
    });
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remembered_email', _emailController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remembered_email');
        await prefs.setBool('remember_me', false);
      }
      if (userCredential.user != null) {
        final container = ProviderScope.containerOf(context, listen: false);
        container.read(userIdProvider.notifier).state = userCredential.user!.uid;
        
        // Sauvegarder l'ID utilisateur dans SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userCredential.user!.uid);
        
        final result = await fetchUserAvatarAndNameFromApi(userCredential.user!.uid);
        print('AVATAR URL FROM API: ' + (result['avatar'] ?? 'null'));
        print('NAMEUSER FROM API: ' + (result['name'] ?? 'null'));
        container.read(userAvatarProvider.notifier).state = result['avatar'];
        container.read(userNameProvider.notifier).state = result['name'];
        final token = await userCredential.user!.getIdToken();
        print('TOKEN DEBUG: $token');
        if (token != null) {
          await notifyTokenToBackend(userCredential.user!.uid, token);
        }
        
        // Récupérer et envoyer le token FCM
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('FCM TOKEN DEBUG: $fcmToken');
        if (fcmToken != null) {
          await updateFcmTokenOnBackend(userCredential.user!.uid, fcmToken);
        }
        if (mounted) {
          Navigator.of(context).pop();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = "Aucun utilisateur trouvé avec cet email.";
          break;
        case 'wrong-password':
          message = "Mot de passe incorrect.";
          break;
        case 'invalid-email':
          message = "Adresse email invalide.";
          break;
        default:
          if ((e.message ?? '').contains('auth credential is incorrect') ||
              (e.message ?? '').contains('password is invalid') ||
              (e.message ?? '').contains('has expired')) {
            message = "Adresse email ou mot de passe incorrect.";
          } else {
            message = e.message ?? "Erreur de connexion.";
          }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur inattendue : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un email valide.'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé !'), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Erreur lors de la réinitialisation.';
      if (e.code == 'user-not-found') {
        message = "Aucun utilisateur trouvé avec cet email.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur inattendue : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Map<String, String?>> fetchUserAvatarAndNameFromApi(String uid) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/avatar_userconnect');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        return {
          'avatar': data['urlavatar'] as String?,
          'name': data['nameuser'] as String?,
        };
      }
    }
    return {'avatar': null, 'name': null};
  }

  Future<void> notifyTokenToBackend(String iud, String token) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/recuperertoken?iud=$iud&token=$token');
    try {
      final response = await http.get(url);
      print('RETOUR API TOKEN: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        print('Token envoyé au backend avec succès');
      } else {
        print('Erreur lors de l\'envoi du token au backend');
      }
    } catch (e) {
      print('Erreur réseau lors de l\'envoi du token : $e');
    }
  }

  Future<void> updateFcmTokenOnBackend(String userId, String fcmToken) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/update_fcm_token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'fcm_token': fcmToken,
        }),
      );
      print('RETOUR API FCM TOKEN: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        print('Token FCM envoyé au backend avec succès');
      } else {
        print('Erreur lors de l\'envoi du token FCM au backend');
      }
    } catch (e) {
      print('Erreur réseau lors de l\'envoi du token FCM : $e');
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
                'Connexion',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ravi de vous revoir !',
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
                            return 'Veuillez entrer votre mot de passe';
                          }
                          if (value.length < 6) {
                            return 'Le mot de passe doit contenir au moins 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (val) {
                                  setState(() {
                                    _rememberMe = val ?? false;
                                  });
                                },
                                activeColor: embBlue,
                              ),
                              const Text('Se souvenir de moi'),
                            ],
                          ),
                          TextButton(
                            onPressed: _resetPassword,
                            child: Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(color: embBlue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Bouton Se connecter
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
                          onPressed: _isLoading ? null : _loginUser,
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Se connecter', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bouton S'inscrire
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
                              builder: (context) => const RegisterScreen(),
                            );
                          },
                          child: const Text("S'inscrire", style: TextStyle(fontSize: 16)),
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
} 