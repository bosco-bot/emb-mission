import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:emb_mission/features/community/screens/forums_list_screen.dart';
import 'package:emb_mission/features/testimonies/screens/testimonies_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:emb_mission/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/features/community/screens/group_viewmsg_screen.dart';
import 'package:emb_mission/core/theme/app_colors.dart';
import 'package:emb_mission/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran de détail d'un groupe spécifique
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupDetailScreen({super.key, this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int? selectedGroupId;
  String groupName = '';
  int memberCount = 0;
  int messageCount = 0;
  String creationDate = '';
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> allGroups = [];
  bool isLoadingGroups = false;
  List<dynamic> groupMembers = [];
  List<dynamic> groupAdmins = [];
  bool loadingMembers = false;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    // On ne charge que l'API principale pour le header
    _fetchGroupInfoFromNewApi();
    // Récupérer l'id utilisateur courant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        currentUserId = ref.read(userIdProvider);
      });
    });
  }

  Future<void> _fetchAllGroups() async {
    setState(() { isLoadingGroups = true; });
    try {
      final userId = ref.read(userIdProvider);
      Uri url;
      if (userId != null) {
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsallgrouge?iud=$userId');
      } else {
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsallgrouge');
      }
      print('URL appelée: ' + url.toString());
      final response = await http.get(url);
      print('Réponse brute API groupes: ' + response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('data[\'status\']: \\${data['status']} (\\${data['status'].runtimeType})');
        print('data[\'alldatagroupe\']: \\${data['alldatagroupe']}');
        if ((data['status'] == true || data['status'] == 'true') && data['alldatagroupe'] != null && data['alldatagroupe'].isNotEmpty) {
          allGroups = List<Map<String, dynamic>>.from(data['alldatagroupe']);
          print('allGroups après parsing: ' + allGroups.toString());
          // Sélectionner le premier groupe par défaut
          selectedGroupId = int.tryParse(allGroups[0]['id'].toString());
          print('DEBUG: Groupe par défaut sélectionné, id: $selectedGroupId');
          await _fetchGroupInfo(selectedGroupId!);
        } else {
          setState(() {
            error = 'Aucun groupe trouvé';
            isLoading = false;
            isLoadingGroups = false;
          });
        }
      } else {
        setState(() {
          error = 'Erreur serveur (groupes)';
          isLoading = false;
          isLoadingGroups = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Erreur réseau (groupes)';
        isLoading = false;
        isLoadingGroups = false;
      });
    }
    setState(() { isLoadingGroups = false; });
  }

  Future<void> _fetchGroupInfo(int groupId) async {
    setState(() { isLoading = true; error = null; });
    try {
      final response = await http.post(
        Uri.parse('https://embmission.com/mobileappebm/api/viewsgrougeselect'),
        body: {'id_groupe': groupId.toString()},
      );
      print('DEBUG: Réponse brute de viewsgrougeselect (POST): ' + response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'true' && data['alldatagroupe'] != null && data['alldatagroupe'].isNotEmpty) {
          final group = data['alldatagroupe'][0];
          setState(() {
            groupName = group['titregroupe'] ?? '';
            memberCount = (group['nbrmenbregroups'] != null && group['nbrmenbregroups'].isNotEmpty)
                ? group['nbrmenbregroups'][0]['nbremenbregroups'] ?? 0
                : 0;
            // Séparation admins/membres si possible
            final all = group['nbrmenbregroups'] ?? [];
            groupAdmins = all.where((m) => (m['role']?.toString().toLowerCase() ?? '').contains('admin')).toList();
            groupMembers = all.where((m) => !(m['role']?.toString().toLowerCase() ?? '').contains('admin')).toList();
            creationDate = group['datecreatedat'] ?? '';
            messageCount = (group['nbrmessagegroups'] != null && group['nbrmessagegroups'].isNotEmpty)
                ? group['nbrmessagegroups'][0]['nbrsmessagegroups'] ?? 0
                : 0;
            selectedGroupId = int.tryParse(groupId.toString());
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Aucune donnée trouvée';
            isLoading = false;
            groupMembers = [];
            groupAdmins = [];
          });
        }
      } else {
        setState(() {
          error = 'Erreur serveur';
          isLoading = false;
          groupMembers = [];
          groupAdmins = [];
        });
      }
    } catch (e) {
      setState(() {
        error = 'Erreur réseau';
        isLoading = false;
        groupMembers = [];
        groupAdmins = [];
      });
    }
  }

  Future<void> _fetchGroupInfoFromNewApi({String? groupId}) async {
    setState(() { isLoading = true; error = null; });
    try {
      final userId = ref.read(userIdProvider);
      print('userId utilisé pour l\'API groupes: $userId');
      Uri url;
      if (groupId == null && userId != null) {
        // Cas du chargement de la page : uniquement iud
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsoneinfogrouge?iud=$userId');
      } else if (groupId != null && userId != null) {
        // Cas explicite où on veut les deux (ex: sélection d'un groupe)
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsoneinfogrouge?id_groupe=$groupId&iud=$userId');
      } else if (groupId != null) {
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsoneinfogrouge?id_groupe=$groupId');
      } else {
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsoneinfogrouge');
      }
      final response = await http.get(url);
      print('DEBUG API viewsoneinfogrouge: ' + response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'false' && (data['dataoneinfogrouge'] == '' || data['dataoneinfogrouge'] == null)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veuillez rejoindre un groupe pour accéder à cette page.')),
            );
            Navigator.of(context).pushReplacementNamed('/community');
          }
          return;
        }
        if ((data['status'] == true || data['status'] == 'true') && data['dataoneinfogrouge'] != null && data['dataoneinfogrouge'].isNotEmpty) {
          final group = data['dataoneinfogrouge'][0];
          setState(() {
            groupName = group['titregroupe'] ?? '';
            memberCount = group['nbrmenbre'] ?? 0;
            creationDate = group['datecreatedat'] ?? '';
            selectedGroupId = int.tryParse(group['id'].toString());
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Aucune donnée trouvée';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Erreur serveur';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Erreur réseau';
        isLoading = false;
      });
    }
  }

  void _showGroupSelector() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Sélectionner un groupe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              if (allGroups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('Aucun groupe disponible')), 
                ),
              ...allGroups.map((g) => ListTile(
                title: Text(g['titregroupe'] ?? ''),
                selected: int.tryParse(g['id'].toString()) == selectedGroupId,
                onTap: () {
                  final int groupId = int.tryParse(g['id'].toString()) ?? 0;
                  print('DEBUG: Sélectionné dans bottom sheet, id: $groupId');
                  Navigator.pop(context);
                  _fetchGroupInfo(groupId);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        '', // index 0 inutilisé
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
      ];
      final day = date.day;
      final month = months[date.month];
      final year = date.year;
      return 'Créé le $day $month $year';
    } catch (e) {
      return 'Créé le $dateStr';
    }
  }

  // Nouvelle méthode pour afficher la liste des groupes et gérer la sélection
  Future<void> _showGroupListAndSelect() async {
    setState(() { isLoadingGroups = true; });
    try {
      final userId = ref.read(userIdProvider);
      print('userId utilisé pour l\'API groupes: $userId');
      Uri url;
      if (userId != null) {
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsallgrouge?iud=$userId');
      } else {
        url = Uri.parse('https://embmission.com/mobileappebm/api/viewsallgrouge');
      }
      final response = await http.get(url);
      print('Réponse brute API groupes (showGroupListAndSelect): ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['status'] == true || data['status'] == 'true') && data['datagroupall'] != null && data['datagroupall'].isNotEmpty) {
          final List groupes = data['datagroupall'];
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: groupes.length,
                    itemBuilder: (context, index) {
                      final groupe = groupes[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: 0,
                        minLeadingWidth: 0,
                        title: Center(
                          child: Text(
                            groupe['titregroupe'] ?? 'Groupe  g${groupe['id']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _fetchGroupInfoFromNewApi(groupId: groupe['id'].toString());
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('Aucun groupe trouvé'),
              content: Text('La liste des groupes est vide.'),
            ),
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Erreur serveur'),
            content: Text('Impossible de récupérer les groupes.'),
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Erreur réseau'),
          content: Text('Vérifiez votre connexion internet.'),
        ),
      );
    }
    setState(() { isLoadingGroups = false; });
  }

  Future<void> fetchMembersAndAdmins(int groupId) async {
    setState(() { loadingMembers = true; });
    try {
      final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/menbre_admin_group?idgroupe=$groupId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'true' && data['menbradmingroup'] != null && data['menbradmingroup'].isNotEmpty) {
          final List all = data['menbradmingroup'][0]['menbreadmin'] ?? [];
          setState(() {
            groupAdmins = all.where((m) => (m['role']?.toString().toLowerCase() ?? '').contains('admin')).toList();
            groupMembers = all.where((m) => (m['role']?.toString().toLowerCase() ?? '').contains('membre')).toList();
            loadingMembers = false;
          });
        } else {
          setState(() {
            groupAdmins = [];
            groupMembers = [];
            loadingMembers = false;
          });
        }
      } else {
        setState(() {
          groupAdmins = [];
          groupMembers = [];
          loadingMembers = false;
        });
      }
    } catch (e) {
      setState(() {
        groupAdmins = [];
        groupMembers = [];
        loadingMembers = false;
      });
    }
  }

  Future<void> retirerMembre(int groupId, String userId) async {
    try {
      final response = await http.get(Uri.parse('https://embmission.com/mobileappebm/api/retirer_menbre_group?idgroupe=$groupId&iduser=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 'true' && data['action'] == 'removed') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Membre retiré avec succès.')));
          await fetchMembersAndAdmins(groupId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Erreur lors du retrait.')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> saveNotificationPreferences({
    required int groupId,
    required String userId,
    required bool notifContentPush,
    required bool notifContentEmail,
    required bool notifArrivantPush,
    required bool notifArrivantEmail,
  }) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/savenotifyparamgroup');
    final body = {
      'group_id': groupId.toString(),
      'user_id': userId,
      'notif_content_push': (notifContentPush ? 1 : 0).toString(),
      'notif_content_email': (notifContentEmail ? 1 : 0).toString(),
      'notif_arrivant_push': (notifArrivantPush ? 1 : 0).toString(),
      'notif_arrivant_email': (notifArrivantEmail ? 1 : 0).toString(),
    };
    try {
      final response = await http.post(url, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 'true') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Préférences enregistrées avec succès.')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la sauvegarde.')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<Map<String, bool>> fetchNotificationPreferences({
    required int groupId,
    required String userId,
  }) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/recupnotifyparamgroup?group_id=$groupId&user_id=$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 'true') {
          return {
            'notif_content_push': data['notif_content_push'] == 1,
            'notif_content_email': data['notif_content_email'] == 1,
            'notif_arrivant_push': data['notif_arrivant_push'] == 1,
            'notif_arrivant_email': data['notif_arrivant_email'] == 1,
          };
        }
      }
    } catch (_) {}
    // Valeurs par défaut si erreur ou non trouvé
    return {
      'notif_content_push': true,
      'notif_content_email': false,
      'notif_arrivant_push': false,
      'notif_arrivant_email': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
        title: const Text(
          'Groupe Spécifique',
          style: TextStyle(color: Colors.white),
        ),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: isLoadingGroups ? null : _showGroupListAndSelect,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du groupe avec icône et informations dynamiques
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: [
                  _buildGroupHeader(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(child: Text(error!, style: TextStyle(color: Colors.red))),
                    ),
                ],
              ),
            
            // Options du groupe - Section avec fond blanc
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  _buildGroupOption(
                    icon: 'assets/images/messages.svg',
                    title: 'Messages du groupe',
                    subtitle: 'Voir toutes les conversations',
                    backgroundColor: Colors.blue.shade50,
                    iconColor: Colors.blue,
                    onTap: () {
                      if (selectedGroupId != null) {
                        context.go('/community/group/${selectedGroupId.toString()}');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Aucun groupe sélectionné')),
                        );
                      }
                    },
                  ),
                  
                  _buildGroupOption(
                    icon: 'assets/images/membres.svg',
                    title: 'Membres et administrateurs',
                    subtitle: 'Gérer les participants',
                    backgroundColor: AppColors.prayerCardBackground,
                    iconColor: AppColors.green,
                    onTap: () async {
                      await fetchMembersAndAdmins(selectedGroupId ?? 0);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppColors.background,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) {
                          return DraggableScrollableSheet(
                            expand: false,
                            initialChildSize: 0.65,
                            minChildSize: 0.3,
                            maxChildSize: 0.95,
                            builder: (context, scrollController) {
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  child: loadingMembers
                                    ? const Center(child: CircularProgressIndicator())
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Center(
                                            child: Container(
                                              width: 40,
                                              height: 4,
                                              margin: const EdgeInsets.only(bottom: 16),
                                              decoration: BoxDecoration(
                                                color: AppColors.divider,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          Center(
                                            child: Text(
                                              'Membres & Administrateurs',
                                              style: AppTheme.appBarTheme.titleTextStyle?.copyWith(
                                                fontSize: 20,
                                                color: AppColors.primaryBlue,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          if (groupAdmins.isNotEmpty) ...[
                                            Text(
                                              'Administrateurs',
                                              style: AppTheme.appBarTheme.titleTextStyle?.copyWith(
                                                fontSize: 16,
                                                color: AppColors.purple,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...groupAdmins.map((admin) => Card(
                                                  color: AppColors.cardBackground,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                                  child: ListTile(
                                                    leading: admin['urlavatar'] != null && admin['urlavatar'].toString().isNotEmpty
                                                        ? CircleAvatar(
                                                            backgroundImage: NetworkImage(admin['urlavatar']),
                                                            backgroundColor: AppColors.purple.withOpacity(0.15),
                                                          )
                                                        : CircleAvatar(
                                                            backgroundColor: AppColors.purple.withOpacity(0.15),
                                                            child: Text(
                                                              (admin['nameavatar'] ?? '?').toString().isNotEmpty
                                                                  ? (admin['nameavatar'])[0].toUpperCase()
                                                                  : '?',
                                                              style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                    title: Text(
                                                      admin['nameavatar'] ?? 'Administrateur',
                                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textDark),
                                                    ),
                                                    subtitle: const Text('Administrateur', style: TextStyle(color: AppColors.textGrey)),
                                                  ),
                                                )),
                                            const Divider(height: 32, color: AppColors.divider),
                                          ],
                                          if (groupMembers.isNotEmpty) ...[
                                            Text(
                                              'Membres',
                                              style: AppTheme.appBarTheme.titleTextStyle?.copyWith(
                                                fontSize: 16,
                                                color: AppColors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: ListView.separated(
                                                controller: scrollController,
                                                itemCount: groupMembers.length,
                                                separatorBuilder: (context, i) => const Divider(height: 1, color: AppColors.divider),
                                                itemBuilder: (context, index) {
                                                  final m = groupMembers[index];
                                                  return ListTile(
                                                    leading: m['urlavatar'] != null && m['urlavatar'].toString().isNotEmpty
                                                        ? CircleAvatar(
                                                            backgroundImage: NetworkImage(m['urlavatar']),
                                                            backgroundColor: AppColors.green.withOpacity(0.15),
                                                          )
                                                        : CircleAvatar(
                                                            backgroundColor: AppColors.green.withOpacity(0.15),
                                                            child: Text(
                                                              (m['nameavatar'] ?? '?').toString().isNotEmpty
                                                                  ? (m['nameavatar'])[0].toUpperCase()
                                                                  : '?',
                                                              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                    title: Text(
                                                      m['nameavatar'] ?? 'Membre',
                                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppColors.textDark),
                                                    ),
                                                    subtitle: const Text('Membre', style: TextStyle(color: AppColors.textGrey)),
                                                    trailing: (groupAdmins.any((a) => a['iduser'] == currentUserId))
                                                        ? IconButton(
                                                            icon: const Icon(Icons.remove_circle, color: AppColors.embRed),
                                                            tooltip: 'Retirer ce membre',
                                                            onPressed: () async {
                                                              final confirm = await showDialog<bool>(
                                                                context: context,
                                                                builder: (context) => AlertDialog(
                                                                  title: const Text('Retirer ce membre ?'),
                                                                  content: Text('Voulez-vous vraiment retirer ${m['nameavatar'] ?? 'ce membre'} du groupe ?'),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () => Navigator.pop(context, false),
                                                                      child: const Text('Annuler'),
                                                                    ),
                                                                    ElevatedButton(
                                                                      onPressed: () => Navigator.pop(context, true),
                                                                      child: const Text('Retirer'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                              if (confirm == true) {
                                                                await retirerMembre(selectedGroupId ?? 0, m['iduser']);
                                                              }
                                                            },
                                                          )
                                                        : null,
                                                  );
                                                },
                                              ),
                                            ),
                                          ] else if (groupAdmins.isEmpty) ...[
                                            const Center(child: Text('Aucun membre trouvé.', style: TextStyle(color: AppColors.textGrey))),
                                          ],
                                        ],
                                      ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  
                  _buildGroupOption(
                    icon: 'assets/images/paramètres.svg',
                    title: 'Paramètres de notification',
                    subtitle: 'Personnaliser les alertes',
                    backgroundColor: AppColors.amber.withOpacity(0.15),
                    iconColor: AppColors.amber,
                    onTap: () async {
                      final prefs = await fetchNotificationPreferences(
                        groupId: selectedGroupId ?? 0,
                        userId: currentUserId ?? '',
                      );
                      bool notifContentPush = prefs['notif_content_push'] ?? true;
                      bool notifContentEmail = prefs['notif_content_email'] ?? false;
                      bool notifArrivantPush = prefs['notif_arrivant_push'] ?? false;
                      bool notifArrivantEmail = prefs['notif_arrivant_email'] ?? false;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppColors.background,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) {
                          return StatefulBuilder(
                            builder: (context, setModalState) {
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.notifications, color: AppColors.primaryBlue, size: 26),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Préférences notifications',
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          const Expanded(child: SizedBox()),
                                          Row(
                                            children: [
                                              const Icon(Icons.notifications_active, color: AppColors.primaryBlue, size: 20),
                                              const SizedBox(width: 4),
                                              Text('Push', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                          const SizedBox(width: 24),
                                          Row(
                                            children: [
                                              const Icon(Icons.email_outlined, color: AppColors.green, size: 20),
                                              const SizedBox(width: 4),
                                              Text('Email', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24, color: AppColors.divider),
                                      _buildNotifRow(
                                        context,
                                        label: 'Nouveaux contenus',
                                        valuePush: notifContentPush,
                                        valueEmail: notifContentEmail,
                                        onChangedPush: (v) => setModalState(() => notifContentPush = v),
                                        onChangedEmail: (v) => setModalState(() => notifContentEmail = v),
                                      ),
                                      _buildNotifRow(
                                        context,
                                        label: 'Nouvelles adhésions au groupe',
                                        valuePush: notifArrivantPush,
                                        valueEmail: notifArrivantEmail,
                                        onChangedPush: (v) => setModalState(() => notifArrivantPush = v),
                                        onChangedEmail: (v) => setModalState(() => notifArrivantEmail = v),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Fermer'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await saveNotificationPreferences(
                                                groupId: selectedGroupId ?? 0,
                                                userId: currentUserId ?? '',
                                                notifContentPush: notifContentPush,
                                                notifContentEmail: notifContentEmail,
                                                notifArrivantPush: notifArrivantPush,
                                                notifArrivantEmail: notifArrivantEmail,
                                              );
                                              if (context.mounted) Navigator.pop(context);
                                            },
                                            child: const Text('Enregistrer'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Statistiques du groupe
            _buildGroupStats(),
          ],
        ),
      ),
    );
  }

  // En-tête du groupe avec icône et informations
  Widget _buildGroupHeader() {
    print('DEBUG: Affichage header: $groupName, $memberCount, $messageCount, selectedGroupId: $selectedGroupId');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icône du groupe
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade400,
            child: Icon(
              Icons.group,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          // Informations du groupe
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$memberCount membres',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(creationDate),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                if (messageCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$messageCount messages',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Option du groupe avec icône, titre et sous-titre
  Widget _buildGroupOption({
    required String icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.grey.shade50,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: backgroundColor,
          child: SvgPicture.asset(
            icon,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            height: 20,
            width: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // Statistiques du groupe
  Widget _buildGroupStats() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques du groupe',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Card Membres
              Expanded(
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          '$memberCount',
                          style: TextStyle(
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Membres',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Card Messages
              Expanded(
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          '$messageCount',
                          style: TextStyle(
                            color: Colors.green.shade500,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Messages',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotifRow(BuildContext context, {
    required String label,
    required bool valuePush,
    required bool valueEmail,
    required ValueChanged<bool> onChangedPush,
    required ValueChanged<bool> onChangedEmail,
  }) {
    Widget customSwitch({
      required bool value,
      required ValueChanged<bool> onChanged,
      required Color activeColor,
    }) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: !value ? Colors.black : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
          color: value ? activeColor : Colors.white,
        ),
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? Colors.white : Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        width: 44,
        height: 28,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textDark, fontWeight: FontWeight.w600)),
          ),
          customSwitch(
            value: valuePush,
            onChanged: onChangedPush,
            activeColor: AppColors.primaryBlue,
          ),
          const SizedBox(width: 8),
          customSwitch(
            value: valueEmail,
            onChanged: onChangedEmail,
            activeColor: AppColors.green,
          ),
        ],
      ),
    );
  }
}

