import 'package:flutter/material.dart';
import '../../../core/widgets/home_back_button.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:permission_handler/permission_handler.dart';


class ActionsScreen extends ConsumerStatefulWidget {
  const ActionsScreen({super.key});

  @override
  ConsumerState<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends ConsumerState<ActionsScreen> {
  String? _dernierMessagePartage;
  int _nbContenusTelecharges = 0;
  bool _isExporting = false;
  String _exportStatus = '';
  int? _currentJobId;

  @override
  void initState() {
    super.initState();
    _loadDernierMessagePartage();
    _loadNbContenusTelecharges();
  }

  // Méthode pour vérifier et demander les permissions de stockage
  Future<bool> _checkStoragePermissions() async {
    try {
      print('🔍 DEBUG: Vérification des permissions de stockage...');
      
      // Vérifier les permissions selon la version d'Android
      var hasPermission = false;
      
      // Essayer d'abord les permissions modernes (Android 13+)
      try {
        var mediaImagesStatus = await Permission.photos.status;
        var mediaVideoStatus = await Permission.videos.status;
        var mediaAudioStatus = await Permission.audio.status;
        
        print('🔍 DEBUG: Permission photos: $mediaImagesStatus');
        print('🔍 DEBUG: Permission videos: $mediaVideoStatus');
        print('🔍 DEBUG: Permission audio: $mediaAudioStatus');
        
        if (mediaImagesStatus.isGranted || mediaVideoStatus.isGranted || mediaAudioStatus.isGranted) {
          hasPermission = true;
          print('✅ Permissions médias accordées');
        }
      } catch (e) {
        print('⚠️ Permissions médias non disponibles: $e');
      }
      
      // Si pas de permissions médias, essayer les permissions de stockage classiques
      if (!hasPermission) {
        try {
          var storageStatus = await Permission.storage.status;
          print('🔍 DEBUG: Permission storage: $storageStatus');
          
          if (storageStatus.isDenied) {
            print('🔍 DEBUG: Demande de permission storage...');
            storageStatus = await Permission.storage.request();
            print('🔍 DEBUG: Permission storage après demande: $storageStatus');
          }
          
          if (storageStatus.isGranted) {
            hasPermission = true;
            print('✅ Permission storage accordée');
          }
        } catch (e) {
          print('⚠️ Permission storage non disponible: $e');
        }
      }
      
      // Dernier recours : permission de gestion du stockage externe
      if (!hasPermission) {
        try {
          var externalStorageStatus = await Permission.manageExternalStorage.status;
          print('🔍 DEBUG: Permission external storage: $externalStorageStatus');
          
          if (externalStorageStatus.isDenied) {
            print('🔍 DEBUG: Demande de permission external storage...');
            externalStorageStatus = await Permission.manageExternalStorage.request();
            print('🔍 DEBUG: Permission external storage après demande: $externalStorageStatus');
          }
          
          if (externalStorageStatus.isGranted) {
            hasPermission = true;
            print('✅ Permission external storage accordée');
          }
        } catch (e) {
          print('⚠️ Permission external storage non disponible: $e');
        }
      }
      
      print('🔍 DEBUG: Résultat final des permissions: $hasPermission');
      return hasPermission;
      
    } catch (e) {
      print('❌ Erreur lors de la vérification des permissions: $e');
      return false;
    }
  }

  // Méthode pour demander un export
  Future<void> _requestExport() async {
    // Vérifier si l'utilisateur est connecté
    final user = AuthService().currentUser;
    if (user == null) {
      // L'utilisateur n'est pas connecté, rediriger vers la welcome screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ),
        );
      }
      return;
    }

    final userId = user.uid;
    if (userId.isEmpty) {
      // L'utilisateur n'est pas connecté, rediriger vers la welcome screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ),
        );
      }
      return;
    }

    setState(() {
      _isExporting = true;
      _exportStatus = 'Demande d\'export en cours...';
    });

    try {
      print('🔄 Début de la demande d\'export pour userId: $userId');
      
      // Vérifier d'abord si l'API est accessible
      print('🔍 Test de connectivité API...');
      try {
        final testResponse = await http.get(
          Uri.parse('https://embmission.com/mobileappebm/api/health'),
        ).timeout(const Duration(seconds: 10));
        
        print('🔍 Test de connectivité API - Status: ${testResponse.statusCode}');
        print('🔍 Test de connectivité API - Body: "${testResponse.body}"');
        
        if (testResponse.statusCode != 200) {
          print('⚠️ L\'endpoint /health retourne une erreur ${testResponse.statusCode}');
          print('⚠️ Cela indique un problème côté serveur');
        }
      } catch (e) {
        print('❌ Erreur lors du test de connectivité: $e');
      }
      
      // API 1: Demander un export
      final requestBody = {'user_id': userId};
      print('📤 Envoi de la demande d\'export avec le body: $requestBody');
      
      final response = await http.post(
        Uri.parse('https://embmission.com/mobileappebm/api/export/request'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Réponse reçue - Status: ${response.statusCode}');
      print('📥 Body de la réponse: "${response.body}"');
      print('📥 Headers de la réponse: ${response.headers}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Données reçues: $data');
        
        if (data['job_id'] != null) {
          _currentJobId = data['job_id'];
          print('🎯 Job ID reçu: $_currentJobId');
          
          if (mounted) {
            setState(() {
              _exportStatus = 'Export en cours de préparation...';
            });
          }
          
          // Mettre à jour le compteur des contenus téléchargés car l'export a commencé
          await _loadNbContenusTelecharges();
          
          // Commencer le polling du statut
          await _pollExportStatus();
        } else {
          throw Exception('Réponse invalide de l\'API: job_id manquant dans la réponse');
        }
      } else if (response.statusCode == 500) {
        // Erreur serveur spécifique
        final errorBody = response.body;
        print('❌ Erreur serveur (500): "$errorBody"');
        
        // Analyser la réponse pour diagnostiquer le problème
        String errorMessage = 'Erreur serveur interne';
        String diagnosticInfo = '';
        
        if (errorBody.isEmpty) {
          errorMessage = 'Erreur serveur: Réponse vide du serveur';
          diagnosticInfo = 'Le serveur a retourné une erreur 500 sans message d\'erreur. Cela indique généralement un problème critique côté serveur.';
        } else {
          try {
            final errorData = jsonDecode(errorBody);
            if (errorData['message'] != null) {
              errorMessage = errorData['message'];
            } else if (errorData['error'] != null) {
              errorMessage = errorData['error'];
            }
          } catch (e) {
            print('⚠️ Impossible de parser le message d\'erreur: $e');
            errorMessage = 'Erreur serveur: Réponse non-JSON reçue';
            diagnosticInfo = 'Le serveur a retourné une réponse non-JSON: "$errorBody"';
          }
        }
        
        // Afficher des informations de diagnostic
        print('🔍 Diagnostic de l\'erreur 500:');
        print('   - Status: ${response.statusCode}');
        print('   - Body vide: ${errorBody.isEmpty}');
        print('   - Content-Type: ${response.headers['content-type']}');
        print('   - Content-Length: ${response.headers['content-length']}');
        
        throw Exception('$errorMessage\n\n$diagnosticInfo');
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('💥 Exception lors de la demande d\'export: $e');
      
      setState(() {
        _isExporting = false;
        _exportStatus = '';
      });
      
      // Afficher un message d'erreur plus informatif
      String errorMessage = 'Erreur lors de la demande d\'export';
      String detailedMessage = '';
      
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Délai d\'attente dépassé';
        detailedMessage = 'Vérifiez votre connexion internet et réessayez.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Impossible de se connecter au serveur';
        detailedMessage = 'Vérifiez votre connexion internet.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Erreur temporaire du serveur';
        detailedMessage = 'Le serveur rencontre des difficultés techniques. Veuillez réessayer dans quelques minutes ou contacter le support.';
      } else {
        errorMessage = 'Erreur technique';
        detailedMessage = e.toString();
      }
      
      // Afficher une boîte de dialogue d'erreur plus détaillée
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Erreur de synchronisation'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  if (detailedMessage.isNotEmpty)
                    Text(
                      detailedMessage,
                      style: TextStyle(fontSize: 14),
                    ),
                  SizedBox(height: 8),
                  Text(
                    'Code d\'erreur: 500',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Fermer'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _requestExport();
                  },
                  child: Text('Réessayer'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  // Méthode pour vérifier le statut de l'export
  Future<void> _pollExportStatus() async {
    if (_currentJobId == null) return;

    int attempts = 0;
    const maxAttempts = 60; // 5 minutes max (5s * 60)
    
    while (attempts < maxAttempts) {
      try {
        await Future.delayed(const Duration(seconds: 5));
        
        // API 2: Vérifier le statut
        final response = await http.get(
          Uri.parse('https://embmission.com/mobileappebm/api/export/status/$_currentJobId'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          
          if (status == 'completed') {
            final downloadUrl = data['download_url'];
            if (downloadUrl != null) {
              if (mounted) {
                setState(() {
                  _exportStatus = 'Téléchargement en cours...';
                });
              }
              
              // Mettre à jour le compteur des contenus téléchargés car l'export est prêt
              await _loadNbContenusTelecharges();
              
              // Télécharger le fichier
              await _downloadExportFile(downloadUrl);
              return;
            } else {
              throw Exception('URL de téléchargement manquante');
            }
          } else if (status == 'error') {
            throw Exception('Erreur lors de la préparation de l\'export');
          } else {
            // Status: queued, processing, etc.
            if (mounted) {
              setState(() {
                _exportStatus = 'Préparation de l\'export... (tentative ${attempts + 1})';
              });
            }
          }
        } else {
          throw Exception('Erreur HTTP: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Erreur lors du polling: $e');
        if (attempts >= maxAttempts - 1) {
          throw Exception('Délai d\'attente dépassé');
        }
      }
      attempts++;
    }
    
    throw Exception('Délai d\'attente dépassé');
  }

  // Méthode pour télécharger le fichier d'export
  Future<void> _downloadExportFile(String downloadUrl) async {
    try {
      // Vérifier les permissions de stockage avant de commencer
      print('🔍 DEBUG: Vérification des permissions de stockage...');
      final hasPermissions = await _checkStoragePermissions();
      if (!hasPermissions) {
        print('❌ ERREUR: Permissions de stockage non accordées');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Permissions de stockage requises pour télécharger le fichier.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      print('✅ Permissions de stockage accordées');

      // Corriger l'URL si nécessaire (enlever le slash en trop)
      String cleanUrl = downloadUrl;
      if (cleanUrl.startsWith('/https://')) {
        cleanUrl = cleanUrl.substring(1);
      }

      setState(() {
        _exportStatus = 'Téléchargement en cours...';
      });

      // Télécharger le fichier
      final response = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(minutes: 10));
      
      if (response.statusCode == 200) {
        // FORCER l'utilisation du dossier PUBLIC des téléchargements du téléphone
        Directory? downloadsDir;
        try {
          // Essayer d'abord getDownloadsDirectory()
          downloadsDir = await getDownloadsDirectory();
          
          // Vérifier si c'est le bon dossier (pas le dossier privé de l'app)
          if (downloadsDir != null && downloadsDir.path.contains('Android/data')) {
            print('⚠️ WARNING: getDownloadsDirectory() retourne le dossier privé de l\'app');
            print('🔍 DEBUG: Tentative d\'accès au dossier public des téléchargements...');
            
            // Essayer d'accéder directement au dossier public
            final publicDownloadsDir = Directory('/storage/emulated/0/Download');
            if (await publicDownloadsDir.exists()) {
              downloadsDir = publicDownloadsDir;
              print('✅ Dossier public des téléchargements trouvé: ${downloadsDir.path}');
            } else {
              print('⚠️ Dossier public des téléchargements non trouvé');
              
              // Essayer le dossier Documents publics
              final publicDocumentsDir = Directory('/storage/emulated/0/Documents');
              if (await publicDocumentsDir.exists()) {
                downloadsDir = publicDocumentsDir;
                print('✅ Dossier Documents publics trouvé: ${downloadsDir.path}');
              } else {
                print('⚠️ Dossier Documents publics non trouvé, utilisation du dossier privé');
              }
            }
          }
          
          if (downloadsDir == null) {
            throw Exception('Impossible d\'accéder au dossier Téléchargements');
          }
        } catch (e) {
          print('❌ ERREUR: Impossible d\'accéder au dossier Téléchargements: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: Impossible d\'accéder au dossier Téléchargements. Vérifiez les permissions.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return; // Arrêter le processus
        }
        
        // Créer le sous-dossier EMB_Exports dans Téléchargements
        final embExportsDir = Directory('${downloadsDir.path}/EMB_Exports');
        print('🔍 DEBUG: Chemin du dossier téléchargements: ${downloadsDir.path}');
        print('🔍 DEBUG: Chemin du sous-dossier EMB_Exports: ${embExportsDir.path}');
        
        if (!await embExportsDir.exists()) {
          await embExportsDir.create(recursive: true);
          print('✅ Dossier EMB_Exports créé dans Téléchargements: ${embExportsDir.path}');
        } else {
          print('✅ Dossier EMB_Exports existe déjà: ${embExportsDir.path}');
        }

        // Nom du fichier PDF avec timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'emb_export_$timestamp.pdf';
        final file = File('${embExportsDir.path}/$fileName');
        print('🔍 DEBUG: Fichier à créer: ${file.path}');

        // Écrire le fichier
        await file.writeAsBytes(response.bodyBytes);
        print('✅ Fichier écrit avec succès: ${file.path}');
        print('🔍 DEBUG: Taille du fichier: ${response.bodyBytes.length} bytes');
        print('🔍 DEBUG: Le fichier existe: ${await file.exists()}');
        print('🔍 DEBUG: Taille du fichier sur disque: ${await file.length()} bytes');
        
        // Vérifications supplémentaires
        print('🔍 DEBUG: === VÉRIFICATIONS APPROFONDIES ===');
        print('🔍 DEBUG: Chemin absolu du fichier: ${file.absolute.path}');
        
        // Vérifier si le fichier est lisible
        try {
          final stat = await file.stat();
          final isReadable = stat.modeString().contains('r');
          print('🔍 DEBUG: Le fichier est lisible: $isReadable');
        } catch (e) {
          print('🔍 DEBUG: Erreur lors de la vérification de la lisibilité du fichier: $e');
        }
        
        // Vérifier si le dossier parent est accessible
        final parentDir = file.parent;
        print('🔍 DEBUG: Dossier parent existe: ${await parentDir.exists()}');
        
        try {
          final parentStat = await parentDir.stat();
          final parentIsReadable = parentStat.modeString().contains('r');
          print('🔍 DEBUG: Dossier parent est lisible: $parentIsReadable');
        } catch (e) {
          print('🔍 DEBUG: Erreur lors de la vérification de la lisibilité du dossier parent: $e');
        }
        
        // Lister les fichiers dans le dossier
        try {
          final files = await parentDir.list().toList();
          print('🔍 DEBUG: Fichiers dans le dossier: ${files.map((f) => f.path.split('/').last).join(', ')}');
        } catch (e) {
          print('🔍 DEBUG: Erreur lors de la liste des fichiers: $e');
        }
        
        // Essayer d'ouvrir le fichier pour vérifier l'accès
        try {
          final fileContent = await file.readAsBytes();
          print('🔍 DEBUG: Fichier lisible, taille: ${fileContent.length} bytes');
        } catch (e) {
          print('🔍 DEBUG: Erreur lors de la lecture du fichier: $e');
        }

        if (mounted) {
          setState(() {
            _isExporting = false;
            _exportStatus = '';
            _currentJobId = null;
          });

          // Mettre à jour le compteur des contenus téléchargés
          await _loadNbContenusTelecharges();

          // Afficher le succès avec dialogue détaillé
          String locationMessage = 'Fichier PDF sauvegardé dans vos Téléchargements/EMB_Exports';
          
          // Afficher d'abord le SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export téléchargé avec succès: $fileName'),
                  Text(
                    locationMessage,
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Ouvrir',
                onPressed: () => _openExportsFolder(),
              ),
            ),
          );
          
          // Afficher un dialogue avec l'emplacement exact
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _showFileLocationDialog(file.path, fileName);
            });
          }
        }
      } else {
        throw Exception('Erreur lors du téléchargement: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
          _currentJobId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Méthode pour ouvrir le dossier des exports
  Future<void> _openExportsFolder() async {
    try {
      // Utiliser le même dossier que celui utilisé pour le téléchargement
      Directory? downloadsDir = await getDownloadsDirectory();
      
      // Vérifier si c'est le bon dossier (pas le dossier privé de l'app)
      if (downloadsDir != null && downloadsDir.path.contains('Android/data')) {
        print('⚠️ WARNING: getDownloadsDirectory() retourne le dossier privé de l\'app');
        print('🔍 DEBUG: Tentative d\'accès au dossier public des téléchargements...');
        
        // Essayer d'accéder directement au dossier public
        final publicDownloadsDir = Directory('/storage/emulated/0/Download');
        if (await publicDownloadsDir.exists()) {
          downloadsDir = publicDownloadsDir;
          print('✅ Dossier public des téléchargements trouvé: ${downloadsDir.path}');
        } else {
          print('⚠️ Dossier public des téléchargements non trouvé, utilisation du dossier privé');
        }
      }
      
      if (downloadsDir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'accéder au dossier Téléchargements'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Ouvrir le sous-dossier EMB_Exports dans Téléchargements
      final embExportsDir = Directory('${downloadsDir.path}/EMB_Exports');
      if (await embExportsDir.exists()) {
        // Lister les fichiers d'export
        final files = await embExportsDir.list().where((entity) => entity is File).toList();
        
        if (files.isNotEmpty) {
          // Trier par date de modification (plus récent en premier)
          files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          
          // Afficher le dialogue de sélection
          if (mounted) {
            _showExportFilesDialog(files);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun fichier d\'export trouvé')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ouverture du dossier: $e')),
      );
    }
  }

  // Dialogue pour afficher les fichiers d'export
  void _showExportFilesDialog(List<FileSystemEntity> files) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fichiers d\'export disponibles'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              final fileName = file.path.split('/').last;
              final fileSize = (file.lengthSync() / 1024 / 1024).toStringAsFixed(2);
              final modified = file.statSync().modified;
              
                              return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(fileName),
                  subtitle: Text('$fileSize MB • ${_formatDate(modified)}'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareExportFile(file);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _shareExportFile(file);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Méthode pour afficher l'emplacement exact du fichier
  void _showFileLocationDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('Fichier sauvegardé'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votre fichier PDF a été sauvegardé avec succès !',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Text(
              '📁 Emplacement exact :',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                filePath,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              '💡 Pour le trouver sur votre téléphone :',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text('• Ouvrez l\'app "Fichiers" ou "Gestionnaire de fichiers"'),
            Text('• Allez dans "Téléchargements" ou "Documents"'),
            Text('• Cherchez le dossier "EMB_Exports"'),
            Text('• Votre fichier : $fileName'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _openExportsFolder();
            },
            icon: Icon(Icons.folder_open),
            label: Text('Ouvrir le dossier'),
          ),
        ],
      ),
    );
  }

  // Méthode pour partager le fichier d'export
  Future<void> _shareExportFile(File file) async {
    try {
      // Utiliser le package share_plus pour partager le fichier
      // Note: Il faudra ajouter share_plus aux dépendances
      // await Share.shareXFiles([XFile(file.path)], text: 'Export EMB Mission');
      
      // Pour l'instant, afficher un message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier prêt: ${file.path.split('/').last}'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du partage: $e')),
      );
    }
  }

  // Méthode pour formater la date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Méthode pour annuler l'export
  void _cancelExport() {
    setState(() {
      _isExporting = false;
      _exportStatus = '';
      _currentJobId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export annulé'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Méthode pour rafraîchir manuellement les données
  Future<void> _refreshData() async {
    setState(() {
      _exportStatus = 'Actualisation en cours...';
    });
    
    try {
      // Mettre à jour le dernier message partagé
      await _loadDernierMessagePartage();
      
      // Mettre à jour le nombre de contenus téléchargés
      await _loadNbContenusTelecharges();
      
      if (mounted) {
        setState(() {
          _exportStatus = 'Données actualisées avec succès';
        });
        
        // Effacer le message de succès après 2 secondes
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _exportStatus = '';
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportStatus = 'Erreur lors de l\'actualisation: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    // Nettoyer les ressources si nécessaire
    super.dispose();
  }

  Future<void> _loadDernierMessagePartage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dernierMessagePartage = prefs.getString('dernier_message_partage');
    });
  }

  Future<void> _saveDernierMessagePartage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dernier_message_partage', message);
    setState(() {
      _dernierMessagePartage = message;
    });
  }

  Future<void> _loadNbContenusTelecharges() async {
    try {
      // Compter les fichiers d'export dans le dossier des téléchargements
      Directory? downloadsDir;
      try {
        downloadsDir = await getDownloadsDirectory();
      } catch (e) {
        try {
          downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            downloadsDir = Directory('${downloadsDir.path}/EMB_Exports');
          }
        } catch (e2) {
          downloadsDir = await getApplicationDocumentsDirectory();
          downloadsDir = Directory('${downloadsDir.path}/exports');
        }
      }
      
      int total = 0;
      if (downloadsDir != null && await downloadsDir.exists()) {
        final files = await downloadsDir.list().where((entity) => entity is File).toList();
        total = files.length;
      }
      
      // Ajouter aussi les contenus en cache si disponibles
      final prefs = await SharedPreferences.getInstance();
      final todayJson = prefs.getString('CACHED_TODAY_CONTENT');
      if (todayJson != null) {
        try {
          final List<dynamic> todayList = jsonDecode(todayJson);
          total += todayList.length;
        } catch (e) {
          print('⚠️ Erreur lors du parsing de CACHED_TODAY_CONTENT: $e');
        }
      }
      final popularJson = prefs.getString('CACHED_POPULAR_CONTENT');
      if (popularJson != null) {
        try {
          final List<dynamic> popularList = jsonDecode(popularJson);
          total += popularList.length;
        } catch (e) {
          print('⚠️ Erreur lors du parsing de CACHED_POPULAR_CONTENT: $e');
        }
      }
      
      setState(() {
        _nbContenusTelecharges = total;
      });
      
      print('📊 Contenus téléchargés mis à jour: $total éléments');
    } catch (e) {
      print('❌ Erreur lors du chargement du nombre de contenus téléchargés: $e');
      setState(() {
        _nbContenusTelecharges = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB6FF),
        elevation: 0,
        leading: const HomeBackButton(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red,
              child: Text(
                'emb',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Actions Rapides',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildUrgencePriereCard(context),
            const SizedBox(height: 16),
            _buildPartageRapideCard(context),
            const SizedBox(height: 16),
            _buildModeHorsLigneCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencePriereCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFFFEEAEA), // Fond rose pâle
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Urgence Prière',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                      Text(
                        'Accès direct depuis\nn\'importe où',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showUrgentPrayerBottomSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_objects, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Demander une prière\nd\'urgence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUrgentPrayerBottomSheet(BuildContext context) {
    final TextEditingController _messageController = TextEditingController();
    bool isLoading = false;
    String? errorMsg;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                    'Session urgence prière',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CB6FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Décris brièvement ta situation ou ton besoin de prière. La communauté sera alertée immédiatement.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ex : Priez pour ma famille, situation urgente...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4CB6FF)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CB6FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text(
                        'Envoyer la demande',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() { isLoading = true; errorMsg = null; });
                              try {
                                final user = AuthService().currentUser;
                                final userId = user?.uid;
                                if (userId == null || _messageController.text.trim().isEmpty) {
                                  setState(() {
                                    isLoading = false;
                                    errorMsg = 'Veuillez saisir un message.';
                                  });
                                  return;
                                }
                                final url = Uri.parse('https://embmission.com/mobileappebm/api/demande_prayer_urgence');
                                final response = await http.post(
                                  url,
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'id_user': userId,
                                    'message': _messageController.text.trim(),
                                  }),
                                );
                                if (response.statusCode == 200) {
                                  final data = jsonDecode(response.body);
                                  if (data['success'] == 'true') {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Demande d\'urgence envoyée à la communauté !'),
                                          backgroundColor: Color(0xFF4CB6FF),
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() { errorMsg = 'Erreur lors de l\'envoi.'; });
                                  }
                                } else {
                                  setState(() { errorMsg = 'Erreur réseau.'; });
                                }
                              } catch (e) {
                                setState(() { errorMsg = 'Erreur : $e'; });
                              } finally {
                                setState(() { isLoading = false; });
                              }
                            },
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

  Widget _buildPartageRapideCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFFE3F2FD), // Fond bleu pâle
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue,
                  child: Icon(
                    Icons.share,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partage Rapide',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      if (_dernierMessagePartage != null && _dernierMessagePartage!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _dernierMessagePartage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_dernierMessagePartage == null || _dernierMessagePartage!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Aucun partage récent',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showQuickShareBottomSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Partager',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _dernierMessagePartage == null || _dernierMessagePartage!.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _dernierMessagePartage!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Texte copié dans le presse-papiers !'),
                                backgroundColor: Color(0xFF4CB6FF),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Copier',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickShareBottomSheet(BuildContext context) {
    final TextEditingController _shareController = TextEditingController();
    bool isLoading = false;
    String? errorMsg;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                    'Partage Rapide',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CB6FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Partage un message, une prière ou un encouragement à la communauté.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _shareController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ex : Dieu est fidèle, ne crains rien !',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4CB6FF)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CB6FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text(
                        'Partager',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() { isLoading = true; errorMsg = null; });
                              try {
                                final user = AuthService().currentUser;
                                final userId = user?.uid;
                                if (userId == null || _shareController.text.trim().isEmpty) {
                                  setState(() {
                                    isLoading = false;
                                    errorMsg = 'Veuillez saisir un message.';
                                  });
                                  return;
                                }
                                final url = Uri.parse('https://embmission.com/mobileappebm/api/partage_rapide');
                                final response = await http.post(
                                  url,
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'id_user': userId,
                                    'message': _shareController.text.trim(),
                                  }),
                                );
                                if (response.statusCode == 200) {
                                  final data = jsonDecode(response.body);
                                  if (data['success'] == 'true') {
                                    await _saveDernierMessagePartage(_shareController.text);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Message partagé à la communauté !'),
                                          backgroundColor: Color(0xFF4CB6FF),
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() { errorMsg = 'Erreur lors du partage.'; });
                                  }
                                } else {
                                  setState(() { errorMsg = 'Erreur réseau.'; });
                                }
                              } catch (e) {
                                setState(() { errorMsg = 'Erreur : $e'; });
                              } finally {
                                setState(() { isLoading = false; });
                              }
                            },
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

  Widget _buildModeHorsLigneCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFFE8F5E9), // Fond vert pâle
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green,
                  child: Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Hors-ligne',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'Synchronisation\ndisponible',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    color: Colors.green.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contenus téléchargés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_nbContenusTelecharges élément${_nbContenusTelecharges > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _refreshData,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.green.shade800,
                      size: 20,
                    ),
                    tooltip: 'Actualiser les données',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Affichage du statut d'export
            if (_isExporting || _exportStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isExporting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        else
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _exportStatus,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isExporting)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _cancelExport,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: Colors.red.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            
            ElevatedButton(
              onPressed: _isExporting ? null : _requestExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isExporting ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isExporting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Synchronisation...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Synchroniser maintenant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
