import 'package:flutter/material.dart';
import '../../../core/widgets/home_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

// Provider pour les statistiques de participation communauté
final communityParticipationProvider = FutureProvider<int>((ref) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return 0;
  
  // Ajouter un timestamp pour éviter le cache
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  try {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/community_participations?user_id=$userId&_t=$timestamp'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        return data['communityparticipations'] ?? 0;
      }
    }
    return 0;
  } catch (e) {
    print('Erreur API community_participations: $e');
    return 0;
  }
});

// Provider pour les statistiques de contenus vus
final contentsViewedProvider = FutureProvider<int>((ref) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return 0;
  
  // Ajouter un timestamp pour éviter le cache
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  try {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/contents_viewed?user_id=$userId&_t=$timestamp'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        return data['contentsviewed'] ?? 0;
      }
    }
    return 0;
  } catch (e) {
    print('Erreur API contents_viewed: $e');
    return 0;
  }
});

// Provider pour les statistiques de temps d'écoute
final listeningTimeProvider = FutureProvider<String>((ref) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return '0h 0m';
  
  // Ajouter un timestamp pour éviter le cache
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  try {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/listening_time?user_id=$userId&_t=$timestamp'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        return data['listeningtime'] ?? '0h 0m';
      }
    }
    return '0h 0m';
  } catch (e) {
    print('Erreur API listening_time: $e');
    return '0h 0m';
  }
});

// Provider pour l'historique de temps d'écoute (7 derniers jours)
final listeningHistoryProvider = FutureProvider<List<int>>((ref) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return List.filled(7, 0);
  
  // Ajouter un timestamp pour éviter le cache
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  try {
    final response = await http.get(
      Uri.parse('https://embmission.com/mobileappebm/api/listening_history?user_id=$userId&_t=$timestamp'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['listening_history'] != null) {
        final List<dynamic> history = data['listening_history'];
        return history.map((value) {
          if (value is int) return value;
          if (value is String) return int.tryParse(value) ?? 0;
          return 0;
        }).toList();
      }
    }
    return List.filled(7, 0);
  } catch (e) {
    print('Erreur API listening_history: $e');
    return List.filled(7, 0);
  }
});

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Timer? _refreshTimer;

  // État de chargement global
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Refresh automatique toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        ref.invalidate(listeningTimeProvider);
        ref.invalidate(contentsViewedProvider);
        ref.invalidate(communityParticipationProvider);
        ref.invalidate(listeningHistoryProvider);
      }
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Charger toutes les données en parallèle
      final userId = ref.read(userIdProvider);
      if (userId != null) {
        await Future.wait([
          // Précharger les statistiques de participation communauté
          _preloadCommunityParticipation(userId),
          // Précharger les statistiques de contenus vus
          _preloadContentsViewed(userId),
          // Précharger les statistiques de temps d'écoute
          _preloadListeningTime(userId),
          // Précharger l'historique de temps d'écoute
          _preloadListeningHistory(userId),
          // Précharger les contenus récents
          _preloadRecentContents(userId),
        ]);
      }
      
      // Invalider les providers pour forcer leur rechargement
      ref.invalidate(listeningTimeProvider);
      ref.invalidate(contentsViewedProvider);
      ref.invalidate(communityParticipationProvider);
      ref.invalidate(listeningHistoryProvider);
      
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

  Future<void> _preloadCommunityParticipation(String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/community_participations?user_id=$userId&_t=$timestamp'),
      );
      print('✅ Participation communauté préchargée');
    } catch (e) {
      print('❌ Erreur préchargement participation communauté: $e');
    }
  }

  Future<void> _preloadContentsViewed(String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/contents_viewed?user_id=$userId&_t=$timestamp'),
      );
      print('✅ Contenus vus préchargés');
    } catch (e) {
      print('❌ Erreur préchargement contenus vus: $e');
    }
  }

  Future<void> _preloadListeningTime(String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/listening_time?user_id=$userId&_t=$timestamp'),
      );
      print('✅ Temps d\'écoute préchargé');
    } catch (e) {
      print('❌ Erreur préchargement temps d\'écoute: $e');
    }
  }

  Future<void> _preloadListeningHistory(String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/listening_history?user_id=$userId&_t=$timestamp'),
      );
      print('✅ Historique d\'écoute préchargé');
    } catch (e) {
      print('❌ Erreur préchargement historique d\'écoute: $e');
    }
  }

  Future<void> _preloadRecentContents(String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('https://embmission.com/mobileappebm/api/listening_contents_stats?userId=$userId&_t=$timestamp'),
      );
      print('✅ Contenus récents préchargés');
    } catch (e) {
      print('❌ Erreur préchargement contenus récents: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ref.watch(userAvatarProvider);
    
    // Récupération des données dynamiques
    final listeningTimeAsync = ref.watch(listeningTimeProvider);
    final contentsViewedAsync = ref.watch(contentsViewedProvider);
    final communityParticipationAsync = ref.watch(communityParticipationProvider);
    final listeningHistoryAsync = ref.watch(listeningHistoryProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB6FF),
        elevation: 0,
        leading: const HomeBackButton(color: Colors.white),
        title: const Text(
          'Historique & Stats',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Force le rafraîchissement des providers
              ref.invalidate(listeningTimeProvider);
              ref.invalidate(contentsViewedProvider);
              ref.invalidate(communityParticipationProvider);
              ref.invalidate(listeningHistoryProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              radius: 20,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCards(
                    listeningTimeAsync,
                    contentsViewedAsync,
                    communityParticipationAsync,
                  ),
                  _buildDivider(),
                  _buildListeningTimeSection(listeningHistoryAsync),
                  _buildDivider(),
                  _buildRecentContentsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCards(
    AsyncValue<String> listeningTimeAsync,
    AsyncValue<int> contentsViewedAsync,
    AsyncValue<int> communityParticipationAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  color: const Color(0xFFE3F2FD),
                  iconColor: const Color(0xFF4CB6FF),
                  icon: Icons.access_time,
                  value: listeningTimeAsync.when(
                    data: (time) => time,
                    loading: () => '0h 0m', // Plus de loading ici
                    error: (_, __) => '0h 0m',
                  ),
                  label: 'Temps d\'écoute',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  color: const Color(0xFFE8F5E9),
                  iconColor: Colors.green,
                  icon: Icons.visibility,
                  value: contentsViewedAsync.when(
                    data: (count) => count.toString(),
                    loading: () => '0', // Plus de loading ici
                    error: (_, __) => '0',
                  ),
                  label: 'Contenus vus',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _buildStatCard(
              color: const Color(0xFFF3E5F5),
              iconColor: Colors.purple,
              icon: Icons.people,
              value: communityParticipationAsync.when(
                data: (count) => count.toString(),
                loading: () => '0', // Plus de loading ici
                error: (_, __) => '0',
              ),
              label: 'Participations communauté',
              fullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String value,
    required String label,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFEEEEEE), width: 1),
        ),
      ),
      height: 8,
    );
  }

  Widget _buildListeningTimeSection(AsyncValue<List<int>> listeningHistoryAsync) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temps d\'écoute (7 derniers jours)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          listeningHistoryAsync.when(
            data: (historyData) {
              if (historyData.isEmpty || historyData.every((value) => value == 0)) {
                return Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Aucune donnée d\'écoute disponible',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              
              return Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                ),
                child: Column(
                  children: [
                    // Graphique en courbe
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                return touchedBarSpots.map((barSpot) {
                                  return LineTooltipItem(
                                    '${barSpot.y.toInt()} min',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.withOpacity(0.2),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  const dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                                  if (value.toInt() >= 0 && value.toInt() < dayNames.length) {
                                    return Text(
                                      dayNames[value.toInt()],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: false,
                          ),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _buildLineChartSpots(historyData),
                              isCurved: true,
                              color: const Color(0xFF4CB6FF),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: const Color(0xFF4CB6FF),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF4CB6FF).withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(), // Plus de loading ici
            error: (_, __) => Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Erreur de chargement',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _buildLineChartSpots(List<int> data) {
    return List.generate(7, (index) {
      final value = data[index];
      return FlSpot(index.toDouble(), value.toDouble());
    });
  }

  Widget _buildRecentContentsSection() {
    final userId = ref.read(userIdProvider) ?? '';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contenus récents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<http.Response>(
            future: http.get(Uri.parse('https://embmission.com/mobileappebm/api/listening_contents_stats?userId=$userId&_t=${DateTime.now().millisecondsSinceEpoch}')),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink(); // Plus de loading ici
              }
              final response = snapshot.data!;
              if (response.statusCode != 200) {
                return const Text('Erreur de chargement des contenus.');
              }
              final data = jsonDecode(response.body);
              if (data['statDatalistening'] != 'success' || data['datalistening'] == null || (data['datalistening'] as List).isEmpty) {
                return const Text('Aucun contenu récent.');
              }
              final item = data['datalistening'][0];
              final int position = item['position'] ?? 0;
              final int duration = item['duration'] ?? 0;
              String status = 'En cours';
              if (duration > 0 && position >= duration - 5) {
                status = 'Terminé';
              }
              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildContentItem(
                      color: const Color(0xFF4CB6FF),
                      icon: Icons.mic,
                      title: item['title'] ?? 'Prière du matin',
                      subtitle: _formatRelativeDate(item['created_at']) + ' - ' + _formatDuration(duration),
                      status: status,
                    ),
                  ),
                  const SizedBox(height: 16),
//                   Container(
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFF5F5F5),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: _buildContentItem(
//                       color: Colors.green,
//                       icon: Icons.book,
//                       title: 'Étude biblique',
//                       subtitle: 'Il y a 2 jours - 45 min',
//                       status: 'Terminé',
//                     ),
//                   ),
//                   const SizedBox(height: 16),
                  // Tu peux ajouter d'autres contenus dynamiques ici si besoin
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds s';
    } else {
      final mins = (seconds / 60).round();
      return '$mins min';
    }
  }

  String _formatRelativeDate(dynamic createdAt) {
    if (createdAt == null) return '';
    DateTime? date;
    if (createdAt is String) {
      date = DateTime.tryParse(createdAt);
    } else if (createdAt is DateTime) {
      date = createdAt;
    }
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return "Hier";
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildContentItem({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
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
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
