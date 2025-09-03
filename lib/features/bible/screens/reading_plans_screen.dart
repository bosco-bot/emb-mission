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

// 1. Ajouter un modèle pour l'avatar actif
class ActiveReaderAvatar {
  final String idUser;
  final String avatarUrl;
  ActiveReaderAvatar({required this.idUser, required this.avatarUrl});
  factory ActiveReaderAvatar.fromJson(Map<String, dynamic> json) {
    return ActiveReaderAvatar(
      idUser: json['id_user'],
      avatarUrl: json['avatar_url'],
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

  // État de chargement global
  bool _isLoading = true;

  // Variables pour la recherche
  bool _isSearching = false;
  String _searchQuery = '';

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
      await Future.wait([
        _loadReadingPlans(),
        _loadCurrentUserPlan(),
      ]);
    } catch (e) {
      print('❌ Erreur lors du chargement initial: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReadingPlans() async {
    try {
      _readingPlansFuture = fetchReadingPlans();
      await _readingPlansFuture; // Attendre que les plans soient chargés
    } catch (e) {
      print('❌ Erreur lors du chargement des plans: $e');
      // Créer une future vide en cas d'erreur
      _readingPlansFuture = Future.value(<ReadingPlan>[]);
    }
  }

  Future<void> _loadCurrentUserPlan() async {
    try {
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
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un plan de lecture…',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text(
                'Plans de Lecture',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
    
    if (_currentPlanId == null) {
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
        if (snapshot.hasError) {
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
          // Filtrer les plans selon la recherche
          final allPlans = snapshot.data!;
          final filteredPlans = _searchQuery.isEmpty
              ? allPlans
              : allPlans.where((plan) {
                  final searchQuery = _searchQuery.toLowerCase();
                  return plan.title.toLowerCase().contains(searchQuery) ||
                         plan.subtitle.toLowerCase().contains(searchQuery) ||
                         (plan.description?.toLowerCase().contains(searchQuery) ?? false);
                }).toList();

          if (filteredPlans.isEmpty && _searchQuery.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun plan trouvé pour "$_searchQuery"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

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
              ...filteredPlans.map((plan) => _buildProgramItem(
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
      print('📥 Réponse plan_contents - Status:  [32m${response.statusCode} [0m');
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

  // Remettre la fonction pour récupérer le nombre de lecteurs actifs aujourd'hui
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

  // 2. Fonction pour récupérer dynamiquement les avatars actifs aujourd'hui
  Future<List<ActiveReaderAvatar>> fetchActiveReaderAvatarsToday() async {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/view_avatar_active_readers_today'),
    );
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['status'] == 'success' && jsonBody['datareadingdaysactive'] != null) {
        final List<dynamic> data = jsonBody['datareadingdaysactive'];
        // On a une liste de {"avatar": [ ... ]}
        final List<ActiveReaderAvatar> avatars = [];
        for (final item in data) {
          if (item['avatar'] != null && item['avatar'] is List) {
            for (final avatarJson in item['avatar']) {
              avatars.add(ActiveReaderAvatar.fromJson(avatarJson));
            }
          }
        }
        return avatars;
      }
    }
    return [];
  }

  // 3. Widget dynamique pour afficher les avatars actifs
  Widget _buildActiveAvatars() {
    return FutureBuilder<List<ActiveReaderAvatar>>(
      future: fetchActiveReaderAvatarsToday(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 36,
            child: Center(child: Text('...')),
          );
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 36,
            child: Center(child: Text('Aucun avatar')),
          );
        } else {
          final avatars = snapshot.data!;
          final int maxAvatars = 3;
          final int extra = avatars.length > maxAvatars ? avatars.length - maxAvatars : 0;
          // Largeur = (nombre d'avatars affichés * 24.0) + 36.0 (pour le dernier cercle ou +N)
          final int displayed = avatars.length > maxAvatars ? maxAvatars : avatars.length;
          final double width = (displayed * 24.0) + 36.0;
          return SizedBox(
            height: 36,
            width: width,
            child: Stack(
              children: [
                for (int i = 0; i < avatars.length && i < maxAvatars; i++)
                  Positioned(
                    left: i * 24.0,
                    child: _buildAvatarCircleNetwork(avatars[i].avatarUrl),
                  ),
                if (extra > 0)
                  Positioned(
                    left: maxAvatars * 24.0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '+$extra',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      },
    );
  }

  // 4. Widget pour afficher un avatar réseau
  Widget _buildAvatarCircleNetwork(String imageUrl) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // 5. Remplacer le bloc statique d'avatars dans _buildCommunity par le widget dynamique
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
                      _buildActiveReaders(), // <-- Affiche le nombre
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActiveAvatars(), // <-- Affiche les avatars dynamiques
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        print('🔄 Clic sur "Rejoindre le groupe"');
                        try {
                          // Essayer d'abord avec GoRouter
                          context.go('/community');
                          print('✅ Navigation GoRouter réussie');
                        } catch (e) {
                          print('❌ Erreur GoRouter: $e');
                          // Fallback avec Navigator
                          Navigator.pushNamed(context, '/community');
                          print('✅ Navigation Navigator réussie');
                        }
                      },
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
}
