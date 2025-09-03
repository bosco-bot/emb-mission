import 'package:flutter/material.dart';
import 'package:emb_mission/core/widgets/guest_activity_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Écran de test pour vérifier le fonctionnement du suivi des invités
class TestGuestTrackingScreen extends StatefulWidget {
  const TestGuestTrackingScreen({super.key});

  @override
  State<TestGuestTrackingScreen> createState() => _TestGuestTrackingScreenState();
}

class _TestGuestTrackingScreenState extends State<TestGuestTrackingScreen> {
  String? _currentGuestId;
  DateTime? _lastActiveTime;
  bool _isActive = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGuestInfo();
  }

  /// Charger les informations de l'invité
  Future<void> _loadGuestInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer l'ID invité
      _currentGuestId = await GuestService.getOrCreateGuestId();
      
      // Récupérer le timestamp de la dernière activité
      _lastActiveTime = await GuestService.getLastActiveTime();
      
      // Vérifier si l'invité est actif
      _isActive = await GuestService.isGuestActive();
    } catch (e) {
      print('❌ Erreur lors du chargement des informations invité: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Forcer la mise à jour de l'activité
  Future<void> _forceUpdateActivity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await GuestService.updateGuestLastActive();
      if (success) {
        // Recharger les informations
        await _loadGuestInfo();
        
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
              content: Text('⚠️ Échec de la mise à jour de l\'activité'),
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
      // Supprimer l'ancien ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('guest_id');
      await prefs.remove('guest_last_active');
      
      // Générer un nouvel ID
      _currentGuestId = await GuestService.getOrCreateGuestId();
      
      // Mettre à jour l'activité
      await GuestService.updateGuestLastActive();
      
      // Recharger les informations
      await _loadGuestInfo();
      
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

  /// Nettoyer les données invité
  Future<void> _clearGuestData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await GuestService.clearGuestData();
      
      // Réinitialiser l'état local
      setState(() {
        _currentGuestId = null;
        _lastActiveTime = null;
        _isActive = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 Données invité supprimées'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Suivi Invités'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGuestInfo,
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
                  // Informations de l'invité
                  _buildInfoCard(
                    title: 'Informations Invité',
                    children: [
                      _buildInfoRow('ID Invité', _currentGuestId ?? 'Non défini'),
                      _buildInfoRow('Dernière Activité', _lastActiveTime?.toString() ?? 'Jamais'),
                      _buildInfoRow('Statut', _isActive ? '🟢 Actif' : '🟡 Inactif'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Actions
                  _buildActionCard(
                    title: 'Actions',
                    children: [
                      _buildActionButton(
                        icon: Icons.update,
                        label: 'Mettre à jour l\'activité',
                        onPressed: _forceUpdateActivity,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Générer nouvel ID',
                        onPressed: _generateNewGuestId,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.clear,
                        label: 'Nettoyer les données',
                        onPressed: _clearGuestData,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Logs
                  _buildInfoCard(
                    title: 'Logs',
                    children: [
                      const Text(
                        'Vérifiez la console pour voir les logs détaillés du suivi d\'activité.',
                        style: TextStyle(fontStyle: FontStyle.italic),
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
