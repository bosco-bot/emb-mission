import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/widgets/guest_activity_tracker.dart';
import 'package:emb_mission/core/services/user_activity_service.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:emb_mission/core/services/proactive_data_recovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Écran de test unifié pour vérifier le suivi des invités ET des utilisateurs connectés
class TestActivityTrackingScreen extends ConsumerStatefulWidget {
  const TestActivityTrackingScreen({super.key});

  @override
  ConsumerState<TestActivityTrackingScreen> createState() => _TestActivityTrackingScreenState();
}

class _TestActivityTrackingScreenState extends ConsumerState<TestActivityTrackingScreen> {
  // Données invité
  String? _currentGuestId;
  DateTime? _guestLastActiveTime;
  bool _isGuestActive = false;
  
  // Données utilisateur connecté
  String? _currentUserId;
  DateTime? _userLastActiveTime;
  bool _isUserActive = false;
  bool _isUserLoggedIn = false;
  
  // Données de récupération proactive
  DateTime? _lastProactiveRecovery;
  bool _isProactiveRecoveryEnabled = false;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllInfo();
  }

  /// Charger toutes les informations
  Future<void> _loadAllInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les informations invité
      _currentGuestId = await GuestService.getOrCreateGuestId();
      _guestLastActiveTime = await GuestService.getLastActiveTime();
      _isGuestActive = await GuestService.isGuestActive();
      
      // Charger les informations utilisateur connecté
      _currentUserId = ref.read(userIdProvider);
      _isUserLoggedIn = _currentUserId != null;
      if (_isUserLoggedIn) {
        _userLastActiveTime = await UserActivityService.getLastActiveTime();
        _isUserActive = await UserActivityService.isUserActive();
        
        // Charger les informations de récupération proactive
        _lastProactiveRecovery = await ProactiveDataRecoveryService.getLastRecoveryTime();
        _isProactiveRecoveryEnabled = _lastProactiveRecovery != null;
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des informations: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Forcer la mise à jour de l'activité invité
  Future<void> _forceUpdateGuestActivity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await GuestService.updateGuestLastActive();
      if (success) {
        await _loadAllInfo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Activité invité mise à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Échec de la mise à jour de l\'activité invité'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Forcer la mise à jour de l'activité utilisateur
  Future<void> _forceUpdateUserActivity() async {
    if (!_isUserLoggedIn || _currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Aucun utilisateur connecté'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await UserActivityService.updateUserLastActive(_currentUserId!);
      if (success) {
        await _loadAllInfo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Activité utilisateur mise à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Échec de la mise à jour de l\'activité utilisateur'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Générer un nouvel ID invité
  Future<void> _generateNewGuestId() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await GuestService.clearGuestData();
      _currentGuestId = await GuestService.getOrCreateGuestId();
      await GuestService.updateGuestLastActive();
      await _loadAllInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🆔 Nouvel ID invité généré'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Nettoyer toutes les données
  Future<void> _clearAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await GuestService.clearGuestData();
      await UserActivityService.clearUserActivityData();
      
      setState(() {
        _currentGuestId = null;
        _guestLastActiveTime = null;
        _isGuestActive = false;
        _userLastActiveTime = null;
        _isUserActive = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 Toutes les données supprimées'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ✅ NOUVEAU: Simuler la transition invité → utilisateur connecté
  Future<void> _simulateGuestToUserTransition() async {
    if (!_isUserLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Connectez-vous d\'abord pour tester la transition'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simuler la transition
      if (await GuestService.wasGuest()) {
        await GuestService.completeGuestCleanup();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔄 Transition invité → utilisateur simulée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Recharger les informations
        await _loadAllInfo();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ Aucun historique invité détecté'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la simulation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ✅ NOUVEAU: Force une récupération proactive des données utilisateur
  Future<void> _forceProactiveRecovery() async {
    if (!_isUserLoggedIn || _currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Connectez-vous d\'abord pour tester la récupération proactive'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Récupération proactive forcée pour: $_currentUserId');
      
      // Effectuer la récupération proactive forcée
      final success = await ProactiveDataRecoveryService.forceProactiveRecovery(_currentUserId!);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Récupération proactive forcée terminée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Recharger les informations
        await _loadAllInfo();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Échec de la récupération proactive forcée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la récupération proactive: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Suivi d\'Activité'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllInfo,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations invité
                  _buildInfoCard(
                    title: '📱 Informations Invité',
                    color: Colors.orange,
                    children: [
                      _buildInfoRow('ID Invité', _currentGuestId ?? 'Non défini'),
                      _buildInfoRow('Dernière Activité', _guestLastActiveTime?.toString() ?? 'Jamais'),
                      _buildInfoRow('Statut', _isGuestActive ? '🟢 Actif' : '🟡 Inactif'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Informations utilisateur connecté
                  _buildInfoCard(
                    title: '👤 Informations Utilisateur Connecté',
                    color: Colors.blue,
                    children: [
                      _buildInfoRow('Connecté', _isUserLoggedIn ? '✅ Oui' : '❌ Non'),
                      if (_isUserLoggedIn) ...[
                        _buildInfoRow('ID Utilisateur', _currentUserId ?? 'Non défini'),
                        _buildInfoRow('Dernière Activité', _userLastActiveTime?.toString() ?? 'Jamais'),
                        _buildInfoRow('Statut', _isUserActive ? '🟢 Actif' : '🟡 Inactif'),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Informations de récupération proactive
                  _buildInfoCard(
                    title: '🔄 Informations Récupération Proactive',
                    color: Colors.purple,
                    children: [
                      _buildInfoRow('Activée', _isProactiveRecoveryEnabled ? '✅ Oui' : '❌ Non'),
                      if (_isProactiveRecoveryEnabled) ...[
                        _buildInfoRow('Dernière Récupération', _lastProactiveRecovery?.toString() ?? 'Jamais'),
                        _buildInfoRow('Fréquence', 'Toutes les 30 minutes max'),
                        _buildInfoRow('Statut', '🟢 Système actif'),
                      ] else ...[
                        _buildInfoRow('Statut', '🟡 Pas de données disponibles'),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Actions
                  _buildActionCard(
                    title: '🔧 Actions',
                    children: [
                      _buildActionButton(
                        icon: Icons.update,
                        label: 'Mettre à jour activité invité',
                        onPressed: _forceUpdateGuestActivity,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.update,
                        label: 'Mettre à jour activité utilisateur',
                        onPressed: _forceUpdateUserActivity,
                        color: Colors.blue,
                        enabled: _isUserLoggedIn,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Générer nouvel ID invité',
                        onPressed: _generateNewGuestId,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.clear,
                        label: 'Nettoyer toutes les données',
                        onPressed: _clearAllData,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.swap_horiz,
                        label: 'Simuler transition invité→utilisateur',
                        onPressed: _simulateGuestToUserTransition,
                        color: Colors.purple,
                        enabled: _isUserLoggedIn,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.download,
                        label: 'Récupération proactive forcée',
                        onPressed: _forceProactiveRecovery,
                        color: Colors.indigo,
                        enabled: _isUserLoggedIn,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Logs
                  _buildInfoCard(
                    title: '📋 Logs',
                    color: Colors.grey,
                    children: [
                      const Text(
                        'Vérifiez la console pour voir les logs détaillés du suivi d\'activité.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fréquence: Invités (5 min) | Utilisateurs (5 min)',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  /// Construire une carte d'information
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      color: color?.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Construire une carte d'actions
  Widget _buildActionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Construire une ligne d'information
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  /// Construire un bouton d'action
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: enabled ? Colors.white : Colors.grey),
        label: Text(
          label, 
          style: TextStyle(color: enabled ? Colors.white : Colors.grey)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
