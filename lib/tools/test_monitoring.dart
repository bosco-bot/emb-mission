import 'package:flutter/material.dart';
import 'package:emb_mission/core/services/monitoring_service.dart';

class TestMonitoringScreen extends StatelessWidget {
  const TestMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Monitoring Firebase'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre principal
            Text(
              'Test du Monitoring Firebase', 
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Validez que le monitoring fonctionne sans affecter l\'application',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            
            // Section Analytics
            _buildSectionHeader(context, '📊 Analytics', Colors.green),
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logEvent('test_event', {
                  'test_param': 'test_value',
                  'timestamp': DateTime.now().toIso8601String(),
                  'user_id': 'test_user_123',
                });
                _showSuccessSnackBar(context, '✅ Événement Analytics testé');
              },
              icon: Icon(Icons.analytics),
              label: Text('Test Événement Analytics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logContentView(
                  'test_content', 
                  'test_id_123', 
                  title: 'Test Content Title'
                );
                _showSuccessSnackBar(context, '✅ Contenu testé');
              },
              icon: Icon(Icons.article),
              label: Text('Test Affichage Contenu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section Performance
            _buildSectionHeader(context, '⚡ Performance', Colors.orange),
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logPerformanceMetric('test_performance', 100);
                _showSuccessSnackBar(context, '✅ Métrique Performance testée');
              },
              icon: Icon(Icons.speed),
              label: Text('Test Métrique Performance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logPerformanceMetric('app_startup_time', 2500);
                _showSuccessSnackBar(context, '✅ Temps de démarrage testé');
              },
              icon: Icon(Icons.timer),
              label: Text('Test Temps Démarrage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section Erreurs
            _buildSectionHeader(context, '🐛 Crashlytics', Colors.red),
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logError(
                  'Test error non fatale', 
                  StackTrace.current, 
                  fatal: false
                );
                _showSuccessSnackBar(context, '✅ Erreur testée (non fatale)');
              },
              icon: Icon(Icons.bug_report),
              label: Text('Test Erreur (Non Fatale)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logError(
                  'Test error fatale', 
                  StackTrace.current, 
                  fatal: true
                );
                _showSuccessSnackBar(context, '✅ Erreur fatale testée');
              },
              icon: Icon(Icons.warning),
              label: Text('Test Erreur (Fatale)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700]!,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section Utilisateur
            _buildSectionHeader(context, '👤 Actions Utilisateur', Colors.purple),
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logUserAction('button_click', {
                  'button_name': 'test_button',
                  'screen': 'test_monitoring',
                  'timestamp': DateTime.now().toIso8601String(),
                });
                _showSuccessSnackBar(context, '✅ Action utilisateur testée');
              },
              icon: Icon(Icons.person),
              label: Text('Test Action Utilisateur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section Session
            _buildSectionHeader(context, '🕐 Sessions', Colors.teal),
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logSessionStart();
                _showSuccessSnackBar(context, '✅ Début de session testé');
              },
              icon: Icon(Icons.play_arrow),
              label: Text('Test Début Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: () async {
                await MonitoringService.logSessionEnd(300); // 5 minutes
                _showSuccessSnackBar(context, '✅ Fin de session testée');
              },
              icon: Icon(Icons.stop),
              label: Text('Test Fin Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Instructions
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Instructions de Test:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('1. Tester chaque bouton pour valider le monitoring'),
                  Text('2. Vérifier les logs dans la console (rechercher ✅)'),
                  Text('3. Vérifier Firebase Console (Analytics + Crashlytics)'),
                  Text('4. S\'assurer que l\'app fonctionne normalement'),
                  Text('5. Vérifier qu\'aucune erreur n\'apparaît'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 16),
        SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
