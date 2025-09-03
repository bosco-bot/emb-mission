import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/bible/screens/bible_screen.dart';

class ReadingPlansScreen extends ConsumerStatefulWidget {
  const ReadingPlansScreen({super.key});

  @override
  ConsumerState<ReadingPlansScreen> createState() => _ReadingPlansScreenState();
}

class ReadingPlan {
  final int id;
  final String title;
  final String subtitle;
  final String? description;
  final String? icon;
  final String? color;

  ReadingPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    this.description,
    this.icon,
    this.color,
  });

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    return ReadingPlan(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      description: json['description'],
      icon: json['icon'],
      color: json['color'],
    );
  }
}

class PlanContent {
  final int id;
  final int dayNumber;
  final String reference;

  PlanContent({
    required this.id,
    required this.dayNumber,
    required this.reference,
  });

  factory PlanContent.fromJson(Map<String, dynamic> json) {
    return PlanContent(
      id: json['id'],
      dayNumber: json['daynumber'],
      reference: json['reference'],
    );
  }
}



class _ReadingPlansScreenState extends ConsumerState<ReadingPlansScreen> {
  final Color bibleBlueColor = const Color(0xFF64B5F6);

  late Future<List<ReadingPlan>> _readingPlansFuture;
  int? _currentPlanId; // Variable pour stocker le plan actuel
  bool _isLoadingCurrentPlan = true;

  // Champs pour la progression du plan actuel
  double? _planProgression;
  int? _planCurrentDay;
  int? _planTotalDays;
  String? _currentPlanTitle;
  String? _currentDayReference;

  @override
  void initState() {
    super.initState();
    _readingPlansFuture = fetchReadingPlans();
    _loadCurrentUserPlan();
  }

  Future<List<ReadingPlan>> fetchReadingPlans() async {
    final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/reading_plans'));
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['statreadingplans'] == 'success') {
        final List<dynamic> plansJson = jsonBody['datareadingplans'];
        return plansJson.map((plan) => ReadingPlan.fromJson(plan)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des plans');
      }
    } else {
      throw Exception('Erreur réseau');
    }
  }

  Future<void> _loadCurrentUserPlan() async {
    final userId = ref.read(userIdProvider);
    print('🔍 Vérification du plan actuel pour userId: $userId');
    
    if (userId == null) {
      print('❌ Aucun userId trouvé');
      setState(() {
        _currentPlanId = null;
        _isLoadingCurrentPlan = false;
        // Réinitialiser la progression
        _planProgression = null;
        _planCurrentDay = null;
        _planTotalDays = null;
      });
      return;
    }

    try {
      print('📡 Appel API user_reading_plan...');
      final response = await http.post(
        Uri.parse('https://embmission.com/mobileappebm/api/user_reading_plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      print('📥 Réponse API - Status: ${response.statusCode}');
      print('📥 Réponse API - Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        print('📋 JSON décodé: $jsonBody');
        
        // Vérifier les deux formats possibles de réponse
        if (jsonBody['status'] == 'success' || jsonBody['success'] == 'success') {
          final planId = jsonBody['plan_id'];
          print('✅ Plan trouvé: $planId');
          setState(() {
            _currentPlanId = planId;
            _isLoadingCurrentPlan = false;
          });
          print('🔄 État mis à jour - _currentPlanId: $_currentPlanId');

          // Mettre à jour le title du plan courant si possible
          if (_readingPlansFuture != null) {
            _readingPlansFuture.then((plans) {
              ReadingPlan? plan;
              try {
                plan = plans.firstWhere((p) => p.id == planId);
              } catch (_) {
                plan = null;
              }
              if (plan != null) {
                setState(() {
                  _currentPlanTitle = plan?.title;
                });
              }
            });
          }

          // Appel API progression du plan dès le chargement
          await _loadPlanProgression(planId, userId);
        } else {
          print('❌ Status non success: ${jsonBody['status'] ?? jsonBody['success']}');
          setState(() {
            _currentPlanId = null;
            _isLoadingCurrentPlan = false;
            _planProgression = null;
            _planCurrentDay = null;
            _planTotalDays = null;
          });
        }
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        setState(() {
          _currentPlanId = null;
          _isLoadingCurrentPlan = false;
          _planProgression = null;
          _planCurrentDay = null;
          _planTotalDays = null;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération du plan actuel: $e');
      setState(() {
        _currentPlanId = null;
        _isLoadingCurrentPlan = false;
        _planProgression = null;
        _planCurrentDay = null;
        _planTotalDays = null;
      });
    }
  }

  Future<void> _loadPlanProgression(int planId, String userId) async {
    try {
      final body = jsonEncode({
        'plan_id': planId,
        'content_id': null,
        'user_id': userId,
      });
      final response = await http.post(
        Uri.parse('https://embmission.com/mobileappebm/api/readingplan/content'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      print('📥 Réponse progression plan - Status: ${response.statusCode}');
      print('📥 Réponse progression plan - Body: ${response.body}');
      final data = json.decode(response.body);
      print('📋 JSON progression décodé: $data');
      if (response.statusCode == 200) {
        setState(() {
          double? rawProgression;
          if (data['progression'] is num) {
            rawProgression = (data['progression'] as num).toDouble();
          } else {
            rawProgression = double.tryParse(data['progression']?.toString() ?? '');
          }
          // Conversion pourcentage -> ratio si besoin
          if (rawProgression != null && rawProgression > 1) {
            _planProgression = rawProgression / 100;
          } else {
            _planProgression = rawProgression;
          }
          _planCurrentDay = data['current_day'] is int
            ? data['current_day']
            : int.tryParse(data['current_day']?.toString() ?? '');
          _planTotalDays = data['total_days'] is int
            ? data['total_days']
            : int.tryParse(data['total_days']?.toString() ?? '');
          _currentDayReference = data['reference']?.toString();
          print('Valeur de reference reçue : $_currentDayReference');
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la progression du plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: bibleBlueColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Plans de Lecture',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentPlan(),
            const SizedBox(height: 24),
            _buildStructuredPrograms(),
            const SizedBox(height: 24),
            _buildCommunity(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlan() {
    print('🏗️ Construction du bloc plan actuel - _isLoadingCurrentPlan: $_isLoadingCurrentPlan, _currentPlanId: $_currentPlanId');
    
    if (_isLoadingCurrentPlan) {
      print('⏳ Affichage du loader...');
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_currentPlanId == null) {
      // Aucun plan actuel, ne rien afficher
      print('❌ Aucun plan actuel, ne rien afficher');
      return const SizedBox.shrink();
    } else {
      // Plan actuel trouvé, afficher le bloc
      print('✅ Affichage du bloc plan actuel pour planId: $_currentPlanId');
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Plan actuel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_planCurrentDay != null && _planTotalDays != null)
                    Text(
                        'Jour $_planCurrentDay/$_planTotalDays',
                      style: TextStyle(
                        color: bibleBlueColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_currentPlanTitle != null && _currentPlanTitle!.isNotEmpty)
                  Text(
                    _currentPlanTitle!,
                    style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_planProgression != null && _planCurrentDay != null && _planTotalDays != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Jour $_planCurrentDay/$_planTotalDays',
                      style: TextStyle(
                          color: bibleBlueColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(_planProgression! * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _planProgression!.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(bibleBlueColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 12),
                if (_currentDayReference != null && _currentDayReference!.isNotEmpty)
                  Text(
                    "Aujourd'hui: $_currentDayReference",
                    style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPlanId != null) {
                      _loadPlanContents(_currentPlanId!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Aucun plan sélectionné'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bibleBlueColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Lire'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStructuredPrograms() {
    return FutureBuilder<List<ReadingPlan>>(
      future: _readingPlansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Erreur lors du chargement des plans :\n${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Aucun plan de lecture disponible.'),
          );
        } else {
          final plans = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Programmes structurés',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...plans.map((plan) => _buildProgramItem(
                icon: Icons.book, // Par défaut, car l'API ne fournit pas d'icône
                color: Colors.blue, // Par défaut, car l'API ne fournit pas de couleur
                title: plan.title,
                subtitle: plan.subtitle,
                onTap: () => _showPlanDialog(plan),
              )),
            ],
          );
        }
      },
    );
  }

  Widget _buildProgramItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showPlanDialog(ReadingPlan plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(plan.title),
          content: Text(
            (plan.description != null && plan.description!.isNotEmpty)
                ? plan.description!
                : (plan.subtitle.isNotEmpty ? plan.subtitle : "Aucune description disponible."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Ferme le dialogue
                setState(() {
                  _currentPlanTitle = plan?.title;
                });
                await _selectPlan(plan.id);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectPlan(int planId) async {
    final userId = ref.read(userIdProvider);
    print('🎯 Sélection du plan $planId pour userId: $userId');
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur non connecté.')),
      );
      return;
    }
    try {
      print('📡 Appel API select_plan...');
      final response = await http.post(
        Uri.parse('https://embmission.com/mobileappebm/api/select_plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'plan_id': planId}),
      );
      
      print('📥 Réponse select_plan - Status: ${response.statusCode}');
      print('📥 Réponse select_plan - Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        // Vérifier les deux formats possibles de réponse
        if (jsonBody['status'] == 'success' || jsonBody['success'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan sélectionné avec succès !')),
          );
          // Mettre à jour directement le plan actuel avec le plan_id sélectionné
          print('✅ Plan sélectionné avec succès, mise à jour de _currentPlanId: $planId');
          setState(() {
            _currentPlanId = planId;
          });
          print('🔄 État mis à jour - _currentPlanId: $_currentPlanId');

          // Mise à jour de la progression du plan après sélection
          if (userId != null && userId.isNotEmpty) {
            await _loadPlanProgression(planId, userId);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonBody['message'] ?? 'Erreur lors de la sélection du plan.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau lors de la sélection du plan.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _loadPlanContents(int planId) async {
    print('📚 Chargement des contenus pour le plan $planId');
    try {
      final url = Uri.parse('https://embmission.com/mobileappebm/api/plan_contents');
      final body = jsonEncode({'plan_id': planId});
      print('📡 URL: $url');
      print('📡 Body: $body');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      print('📥 Réponse plan_contents - Status: [32m${response.statusCode}[0m');
      print('📥 Réponse plan_contents - Body: ${response.body}');
      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        print('📋 JSON décodé: $jsonBody');
        if (jsonBody['statevents'] == 'success') {
          final List<dynamic> contentsJson = jsonBody['dataevents'] ?? [];
          print('📋 dataevents: $contentsJson');
          final List<PlanContent> contents = contentsJson
              .map((content) => PlanContent.fromJson(content))
              .toList();
          print('✅ ${contents.length} contenus chargés');
          _showContentsDialog(contents);
        } else {
          print('❌ statevents non success: ${jsonBody['statevents']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonBody['message'] ?? 'Erreur lors du chargement des contenus')),
          );
        }
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau (${response.statusCode}) lors du chargement des contenus')),
        );
      }
    } catch (e) {
      print('❌ Exception lors du chargement des contenus: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    }
  }

  void _showContentsDialog(List<PlanContent> contents) {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contenus du plan'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: contents.length,
              itemBuilder: (context, index) {
                final content = contents[index];
                return ListTile(
                  leading: const Icon(Icons.book),
                  title: Text('Jour ${content.dayNumber}'),
                  subtitle: Text(content.reference),
                  onTap: () async {
                    Navigator.of(context).pop();
                    print('📖 Contenu sélectionné: ${content.reference} (id: ${content.id})');
                    final userId = ref.read(userIdProvider);
                    if (userId == null || userId.isEmpty) {
                      print('❌ user_id manquant, requête non envoyée');
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('Utilisateur non connecté.')),
                      );
                      return;
                    }
                    final planId = _currentPlanId;
                    if (planId == null) {
                      print('❌ plan_id manquant, requête non envoyée');
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('Aucun plan sélectionné.')),
                      );
                      return;
                    }
                    final body = jsonEncode({
                      'plan_id': planId,
                      'content_id': content.id,
                      'user_id': userId,
                    });
                    print("Body envoyé à l'API: $body");
                    try {
                      final response = await http.post(
                        Uri.parse('https://embmission.com/mobileappebm/api/readingplan/content'),
                        headers: {'Content-Type': 'application/json'},
                        body: body,
                      );
                      print('Réponse API: ${response.body}');
                      if (response.statusCode == 200) {
                        final data = jsonDecode(response.body);
                        if (data['success'] == 'true') {
                          final String book = (data['book'] ?? 'Matthieu').toString();
                          final dynamic chapterRaw = data['chapter'];
                          final int chapter = chapterRaw is int
                              ? chapterRaw
                              : int.tryParse(chapterRaw?.toString() ?? '1') ?? 1;
                          final String? range = data['range']?.toString();
                          // Récupération de la progression
                          setState(() {
                            double? rawProgression;
                            if (data['progression'] is num) {
                              rawProgression = (data['progression'] as num).toDouble();
                            } else {
                              rawProgression = double.tryParse(data['progression']?.toString() ?? '');
                            }
                            // Conversion pourcentage -> ratio si besoin
                            if (rawProgression != null && rawProgression > 1) {
                              _planProgression = rawProgression / 100;
                            } else {
                              _planProgression = rawProgression;
                            }
                            _planCurrentDay = data['current_day'] is int
                              ? data['current_day']
                              : int.tryParse(data['current_day']?.toString() ?? '');
                            _planTotalDays = data['total_days'] is int
                              ? data['total_days']
                              : int.tryParse(data['total_days']?.toString() ?? '');
                          });
                          print('Navigation vers BibleScreen avec: book=$book, chapter=$chapter, range=$range');
                          Navigator.push(
                            parentContext,
                            MaterialPageRoute(
                              builder: (context) => BibleScreen(
                                book: book,
                                chapter: chapter,
                                range: range,
                              ),
                            ),
                          );
                        } else {
                          print('API a répondu mais success != true');
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text('Impossible de charger ce contenu.')),
                          );
                        }
                      } else {
                        print('Erreur réseau: statusCode != 200');
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Erreur réseau.')),
                        );
                      }
                    } catch (e) {
                      print('Exception attrapée: $e');
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text('Erreur : $e')),
                      );
                    }
                  },
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
        );
      },
    );
  }

  // Fonction pour récupérer le nombre de lecteurs actifs aujourd'hui
  Future<int?> fetchActiveReadersToday() async {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/active_readers_today'),
    );
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['success'] == 'true' && jsonBody['active_readers'] != null) {
        return int.tryParse(jsonBody['active_readers'].toString());
      }
    }
    return null;
  }

  // Widget pour afficher dynamiquement le nombre de lecteurs actifs
  Widget _buildActiveReaders() {
    return FutureBuilder<int?>(
      future: fetchActiveReadersToday(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('...');
        } else if (snapshot.hasError || !snapshot.hasData) {
          return const Text('N/A');
        } else {
          return Text(
            '${snapshot.data}',
            style: TextStyle(
              color: bibleBlueColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          );
        }
      },
    );
  }

  // Supprime la méthode _buildActiveReadersAvatars et remets l'appel statique ou le code d'origine à l'endroit où il était utilisé.
  // Si le bloc était vide ou n'existait pas avant, laisse simplement l'espace vide ou le widget d'origine (ex: SizedBox.shrink() ou Container()).
  // Si le bloc était vide ou n'existait pas avant, laisse simplement l'espace vide ou le widget d'origine (ex: SizedBox.shrink() ou Container()).
  Widget _buildCommunity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Communauté de lecteurs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lecteurs actifs aujourd\'hui',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Affichage du nombre de lecteurs actifs
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: AssetImage('assets/images/default_avatar.png'),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: AssetImage('assets/images/default_avatar.png'),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: AssetImage('assets/images/default_avatar.png'),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: AssetImage('assets/images/default_avatar.png'),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              '+5',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: _buildAvatarCircle('assets/images/avatar1.jpg'),
                        ),
                        Positioned(
                          left: 24, // 36 - 12 (overlap)
                          child: _buildAvatarCircle('assets/images/avatar2.jpg'),
                        ),
                        Positioned(
                          left: 48, // 24 + 24
                          child: _buildAvatarCircle('assets/images/avatar3.jpg'),
                        ),
                        Positioned(
                          left: 72, // 48 + 24
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                '+5',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: bibleBlueColor,
                        elevation: 0,
                        side: BorderSide(color: bibleBlueColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Rejoindre le groupe'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAvatarCircle(String imagePath) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
