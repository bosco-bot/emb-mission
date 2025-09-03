import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/providers/notification_provider.dart';
import 'package:emb_mission/core/services/notification_service.dart';

/// Outil de test pour vérifier le nettoyage automatique des notifications
class TestNotificationCleanup extends ConsumerWidget {
  const TestNotificationCleanup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Nettoyage Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête informatif
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_delete, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Test du Nettoyage Automatique',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Testez le nettoyage automatique des notifications après 12h. '
                    'Les notifications expirées seront supprimées automatiquement.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Statistiques
            Text(
              'Statistiques Actuelles',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildStatItem('📊 Total', '${notifications.length}'),
                  _buildStatItem('🔴 Non lues', '${notifications.where((n) => !n.isRead).length}'),
                  _buildStatItem('✅ Lues', '${notifications.where((n) => n.isRead).length}'),
                  _buildStatItem('⏰ Plus ancienne', notifications.isNotEmpty 
                    ? _formatAge(notifications.last.receivedAt) 
                    : 'Aucune'),
                  _buildStatItem('⏰ Plus récente', notifications.isNotEmpty 
                    ? _formatAge(notifications.first.receivedAt) 
                    : 'Aucune'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Actions de test
            Text(
              'Actions de Test',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Bouton pour ajouter une notification de test
            ElevatedButton.icon(
              onPressed: () {
                final now = DateTime.now();
                final title = 'Test ${now.hour}:${now.minute}:${now.second}';
                final body = 'Notification de test créée à ${now.toString()}';
                
                NotificationService.addTestNotification(title, body);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Notification de test ajoutée: $title'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter Notification Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton pour forcer le nettoyage
            ElevatedButton.icon(
              onPressed: () {
                final notifier = ref.read(notificationsProvider.notifier);
                notifier.forceCleanupExpiredNotifications();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nettoyage forcé déclenché'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Forcer Nettoyage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton pour ajouter une notification ancienne (pour tester l'expiration)
            ElevatedButton.icon(
              onPressed: () {
                final oldTime = DateTime.now().subtract(const Duration(hours: 13)); // Plus de 12h
                final title = 'Test Ancien ${oldTime.hour}:${oldTime.minute}';
                final body = 'Notification ancienne créée à ${oldTime.toString()} (sera supprimée)';
                
                // Ajouter directement au provider pour simuler une ancienne notification
                final notifier = ref.read(notificationsProvider.notifier);
                notifier.addNotification(title, body);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Notification ancienne ajoutée: $title'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.schedule),
              label: const Text('Ajouter Notification Ancienne'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const Spacer(),
            
            // Note importante
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le nettoyage automatique se déclenche :\n'
                      '• Toutes les heures automatiquement\n'
                      '• Après chaque nouvelle notification\n'
                      '• Au chargement de l\'application\n'
                      '• Supprime les notifications de plus de 12h',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber.shade700,
                      ),
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

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}j ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inSeconds}s';
    }
  }
}

