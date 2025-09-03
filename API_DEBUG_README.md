# Guide de débogage de l'API Export

## Problème identifié
L'erreur HTTP 500 lors de la synchronisation indique un problème côté serveur. Cette erreur peut avoir plusieurs causes :

## Solutions implémentées

### 1. Amélioration de la gestion des erreurs
- Ajout de logs détaillés pour diagnostiquer les problèmes
- Gestion spécifique des erreurs HTTP 500
- Messages d'erreur plus informatifs pour l'utilisateur
- Bouton "Réessayer" dans les messages d'erreur

### 2. Outil de test de connectivité
Un outil de test a été créé dans `lib/tools/test_api_connection.dart` pour diagnostiquer les problèmes d'API.

## Comment utiliser l'outil de test

### Option 1: Via le code
```dart
// Dans votre application, naviguez vers :
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const TestApiConnection(),
  ),
);
```

### Option 2: Ajouter un bouton dans les actions
Vous pouvez ajouter un bouton "Tester l'API" dans l'écran des actions pour faciliter le débogage.

## Tests effectués par l'outil

1. **Test de connectivité** : Vérifie si l'API est accessible
2. **Test de l'endpoint /health** : Vérifie l'état du serveur
3. **Test de l'endpoint /export/request** : Vérifie le comportement avec des données invalides

## Logs de débogage

L'outil affiche des logs détaillés avec des emojis pour faciliter la lecture :
- 🔄 Début des opérations
- 🔍 Tests en cours
- ✅ Succès
- ❌ Erreurs
- 💥 Erreurs générales

## Causes possibles de l'erreur HTTP 500

### Côté serveur
1. **Base de données inaccessible** : Problème de connexion à la base de données
2. **Service externe indisponible** : Dépendance externe en panne
3. **Erreur de code** : Bug dans le code serveur
4. **Problème de configuration** : Mauvaise configuration du serveur
5. **Surcharge** : Trop de requêtes simultanées

### Côté client
1. **Données invalides** : Format incorrect des données envoyées
2. **Authentification** : Token expiré ou invalide
3. **Connexion réseau** : Problème de connectivité

## Actions recommandées

### Immédiat
1. Utiliser l'outil de test pour diagnostiquer
2. Vérifier les logs du serveur (si accessible)
3. Tester avec différents user_id

### À long terme
1. Implémenter une gestion d'erreur côté serveur plus robuste
2. Ajouter des logs côté serveur pour faciliter le débogage
3. Mettre en place un système de monitoring
4. Implémenter un système de retry automatique

## Contact
Si le problème persiste, contactez l'équipe de développement avec :
- Les logs de l'outil de test
- L'heure de l'erreur
- L'ID utilisateur concerné
- Le type d'appareil et la version de l'application

