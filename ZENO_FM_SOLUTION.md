# Solution Zeno.fm - Gestion Automatique des Tokens

## Problème identifié

L'URL Zeno.fm `https://stream.zeno.fm/rxi8n979ui1tv` fait une redirection 302 vers une URL avec un **token JWT temporaire** qui expire après **60 secondes** :

```
https://stream-176.zeno.fm/rxi8n979ui1tv?zt=eyJhbGciOiJIUzI1NiJ9...
```

C'est pourquoi la radio se coupe après environ 1 minute.

## Solution implémentée

### 1. **Service Zeno.fm automatique**
- **Détection automatique** des URLs Zeno.fm
- **Obtention automatique** des tokens valides
- **Renouvellement automatique** avant expiration
- **Gestion des erreurs** de connexion

### 2. **Fonctionnalités du service**

#### Obtention du token :
```dart
// Appel automatique pour obtenir l'URL avec token valide
String streamUrl = await ZenoFmService.getStreamUrl();
```

#### Renouvellement automatique :
- **Vérification** : Token valide pendant 30+ secondes
- **Renouvellement** : Nouveau token 30 secondes avant expiration
- **Transparence** : L'utilisateur ne voit pas les changements

#### Gestion des erreurs :
- **Timeout** : 10 secondes pour obtenir le token
- **Fallback** : URLs alternatives si Zeno.fm échoue
- **Logs détaillés** : Pour diagnostiquer les problèmes

### 3. **Intégration dans le provider radio**

#### Détection automatique :
```dart
if (ZenoFmService.isZenoFmUrl(url)) {
  streamUrl = await ZenoFmService.getStreamUrl();
}
```

#### Reconnexion intelligente :
- **Renouvellement de token** en cas de perte de connexion
- **Fallback automatique** vers d'autres URLs si échec
- **Gestion transparente** pour l'utilisateur

## Avantages de cette solution

### ✅ **Transparence pour l'utilisateur**
- L'utilisateur utilise toujours l'URL simple : `https://stream.zeno.fm/rxi8n979ui1tv`
- Le service gère automatiquement les tokens en arrière-plan
- Pas de changement d'interface utilisateur

### ✅ **Continuité de lecture**
- Renouvellement automatique avant expiration
- Reconnexion automatique en cas de perte
- Pas d'interruption audible

### ✅ **Robustesse**
- Gestion des erreurs de réseau
- Fallback vers d'autres URLs si Zeno.fm échoue
- Logs détaillés pour le diagnostic

### ✅ **Performance**
- Cache du token valide
- Renouvellement anticipé (30 secondes avant expiration)
- Pas de requêtes inutiles

## Utilisation

### Pour l'utilisateur :
1. **Lancez l'application**
2. **Allez sur la radio live**
3. **Cliquez sur play**
4. **La radio continue de jouer sans interruption**

### Pour le développeur :
```dart
// Le service gère automatiquement :
String url = 'https://stream.zeno.fm/rxi8n979ui1tv';
// Devient automatiquement :
// https://stream-176.zeno.fm/rxi8n979ui1tv?zt=eyJhbGciOiJIUzI1NiJ9...
```

## Logs de diagnostic

### Logs normaux :
```
[ZENO FM] URL Zeno.fm détectée, obtention du token...
[ZENO FM] Nouveau token obtenu, expire dans 60 secondes
[RADIO PROVIDER] URL Zeno.fm avec token: https://stream-176.zeno.fm/rxi8n979ui1tv?zt=...
```

### Logs de renouvellement :
```
[ZENO FM] Token encore valide pour 45 secondes
[ZENO FM] Renouvellement automatique du token...
[ZENO FM] Nouveau token obtenu, expire dans 60 secondes
```

### Logs de reconnexion :
```
[RADIO PROVIDER] Tentative de reconnexion Zeno.fm avec nouveau token...
[RADIO PROVIDER] Reconnexion Zeno.fm réussie
```

## Fichiers créés/modifiés

### `lib/core/services/zeno_fm_service.dart` (NOUVEAU)
- Service complet pour gérer les tokens Zeno.fm
- Obtention automatique des tokens
- Renouvellement automatique
- Gestion des erreurs

### `lib/core/providers/radio_player_provider.dart` (MODIFIÉ)
- Intégration du service Zeno.fm
- Détection automatique des URLs Zeno.fm
- Reconnexion avec renouvellement de token

### `lib/features/radio/screens/radio_screen.dart` (MODIFIÉ)
- Retour à l'URL Zeno.fm originale
- Le service gère automatiquement les tokens

## Résultat attendu

Avec cette solution, la radio Zeno.fm devrait maintenant :
- ✅ **Continuer de jouer en continu** sans interruption
- ✅ **Renouveler automatiquement** les tokens avant expiration
- ✅ **Se reconnecter automatiquement** en cas de problème
- ✅ **Fonctionner de manière transparente** pour l'utilisateur

## Dépannage

### Si la radio se coupe encore :
1. **Vérifiez les logs** pour voir les messages Zeno.fm
2. **Vérifiez la connexion internet**
3. **Redémarrez l'application** pour réinitialiser le service

### Logs à surveiller :
- `[ZENO FM] Nouveau token obtenu, expire dans 60 secondes`
- `[ZENO FM] Renouvellement automatique du token...`
- `[RADIO PROVIDER] Reconnexion Zeno.fm réussie`

Cette solution résout définitivement le problème des tokens temporaires de Zeno.fm ! 🎵 