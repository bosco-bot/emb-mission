# 📱 **FONCTIONNALITÉ DE SUIVI DES INVITÉS - EMB Mission**

---

## 🎯 **DESCRIPTION GÉNÉRALE**

La fonctionnalité de **suivi des invités** permet de tracer l'activité des utilisateurs anonymes (non connectés) dans l'application EMB Mission. Elle génère un identifiant unique pour chaque invité et met à jour régulièrement son statut d'activité côté backend.

---

## 🏗️ **ARCHITECTURE**

### **1. ✅ Composants principaux :**

- **`GuestService`** : Service statique pour gérer les invités
- **`GuestActivityTracker`** : Widget wrapper pour le suivi automatique
- **`GuestActivityMixin`** : Mixin pour ajouter le suivi aux écrans
- **`TestGuestTrackingScreen`** : Écran de test et débogage

### **2. ✅ Structure des fichiers :**

```
lib/
├── core/
│   ├── widgets/
│   │   └── guest_activity_tracker.dart    # Implémentation principale
│   └── services/
│       └── auth_service.dart              # Service d'authentification
├── tools/
│   └── test_guest_tracking.dart           # Écran de test
└── main.dart                              # Intégration principale
```

---

## 🚀 **FONCTIONNALITÉS**

### **1. ✅ Génération d'ID unique :**
- **Format** : `guest_{timestamp}_{random}`
- **Exemple** : `guest_1703123456789_123456`
- **Stockage** : `SharedPreferences` avec la clé `guest_id`

### **2. ✅ Suivi automatique :**
- **Fréquence** : Toutes les 5 minutes
- **API** : `https://embmission.com/mobileappebm/api/update_guest_last_active`
- **Paramètre** : `guestId` (ID unique de l'invité)

### **3. ✅ Gestion du cycle de vie :**
- **App reprise** : Mise à jour immédiate de l'activité
- **App en pause** : Pas de mise à jour automatique
- **App fermée** : Nettoyage des timers

### **4. ✅ Persistance des données :**
- **ID invité** : Sauvegardé localement
- **Dernière activité** : Timestamp ISO 8601
- **Statut actif** : Basé sur la dernière activité (< 1 heure)

---

## 🔧 **UTILISATION**

### **1. ✅ Intégration automatique :**

Le `GuestActivityTracker` est déjà intégré dans `main.dart` et s'active automatiquement :

```dart
// Dans main.dart
return AppExitProtection(
  child: GuestActivityTracker(           // ← Suivi automatique des invités
    child: NotificationServiceInitializer(
      child: MaterialApp.router(...)
    ),
  ),
);
```

### **2. ✅ Utilisation manuelle dans un écran :**

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with GuestActivityMixin {
  @override
  void initState() {
    super.initState();
    startGuestActivityTracking();  // ← Démarrer le suivi
  }
  
  // Le suivi s'arrête automatiquement dans dispose()
}
```

### **3. ✅ Appels directs au service :**

```dart
// Mettre à jour l'activité manuellement
await GuestService.updateGuestLastActive();

// Récupérer l'ID invité
String guestId = await GuestService.getOrCreateGuestId();

// Vérifier le statut
bool isActive = await GuestService.isGuestActive();

// Nettoyer les données
await GuestService.clearGuestData();
```

---

## 📊 **API BACKEND**

### **1. ✅ Endpoint :**
```
GET https://embmission.com/mobileappebm/api/update_guest_last_active
```

### **2. ✅ Paramètres :**
- **`guestId`** : Identifiant unique de l'invité (requis)

### **3. ✅ Exemple de requête :**
```
GET /mobileappebm/api/update_guest_last_active?guestId=guest_1703123456789_123456
```

### **4. ✅ Réponse attendue :**
- **Statut 200** : Succès
- **Autres statuts** : Erreur (gérée gracieusement)

---

## 🧪 **TEST ET DÉBOGAGE**

### **1. ✅ Écran de test :**

L'écran `TestGuestTrackingScreen` permet de :
- **Voir** l'ID invité actuel
- **Vérifier** la dernière activité
- **Tester** la mise à jour manuelle
- **Générer** un nouvel ID
- **Nettoyer** les données

### **2. ✅ Logs de débogage :**

Les logs suivants sont affichés dans la console :

```
🆔 Nouvel ID invité généré: guest_1703123456789_123456
🚀 Suivi d'activité invité initialisé pour: guest_1703123456789_123456
🔄 Mise à jour de l'activité invité: guest_1703123456789_123456
✅ Activité invité mise à jour avec succès
🟢 Invité actif: guest_1703123456789_123456
```

### **3. ✅ Accès à l'écran de test :**

Pour accéder à l'écran de test, ajoutez une route dans votre routeur :

```dart
// Dans app_router.dart
GoRoute(
  path: '/test-guest-tracking',
  builder: (context, state) => const TestGuestTrackingScreen(),
),
```

---

## ⚙️ **CONFIGURATION**

### **1. ✅ Fréquences de mise à jour :**

```dart
// Dans guest_activity_tracker.dart
_activityTimer = Timer.periodic(const Duration(minutes: 5), (_) {
  _updateGuestActivity();
});

_statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
  _checkGuestStatus();
});
```

### **2. ✅ Timeout des requêtes :**

```dart
final response = await http.get(url).timeout(
  const Duration(seconds: 10),
  onTimeout: () {
    throw TimeoutException('Timeout lors de la mise à jour de l\'activité invité');
  },
);
```

### **3. ✅ Seuil d'activité :**

```dart
// Un invité est considéré actif si sa dernière activité est < 1 heure
final difference = DateTime.now().difference(lastActive);
return difference.inHours < 1;
```

---

## 🔒 **SÉCURITÉ ET PRIVACY**

### **1. ✅ Données collectées :**
- **ID invité** : Identifiant unique anonyme
- **Timestamp** : Heure de la dernière activité
- **Aucune** information personnelle

### **2. ✅ Stockage local :**
- **SharedPreferences** : Stockage sécurisé de l'app
- **Pas de** synchronisation avec d'autres appareils
- **Suppression** possible à tout moment

### **3. ✅ Gestion des erreurs :**
- **Timeout** : 10 secondes maximum
- **Fallback** : ID temporaire en cas d'erreur
- **Logs** : Débogage sans exposition de données sensibles

---

## 🚨 **DÉPANNAGE**

### **1. ✅ Problèmes courants :**

| **Symptôme** | **Cause possible** | **Solution** |
|--------------|-------------------|--------------|
| Pas de logs | GuestActivityTracker non intégré | Vérifier l'import dans main.dart |
| Erreur API | Endpoint incorrect | Vérifier l'URL dans GuestService |
| ID non généré | Permissions SharedPreferences | Vérifier les permissions Android |

### **2. ✅ Vérifications :**

```bash
# Vérifier que l'import est correct
grep -r "GuestActivityTracker" lib/main.dart

# Vérifier que l'API est accessible
curl "https://embmission.com/mobileappebm/api/update_guest_last_active?guestId=test"

# Vérifier les logs
flutter logs | grep "invité"
```

### **3. ✅ Solutions :**

- **Redémarrer l'app** : Force la réinitialisation
- **Vérifier la console** : Logs détaillés disponibles
- **Tester l'API** : Utiliser l'écran de test
- **Nettoyer les données** : Supprimer et régénérer l'ID

---

## 📈 **MÉTRIQUES ET ANALYTICS**

### **1. ✅ Données collectées :**
- **Nombre d'invités** actifs
- **Fréquence d'utilisation** de l'app
- **Temps de session** moyen
- **Taux de conversion** invité → utilisateur

### **2. ✅ Utilisation des données :**
- **Optimisation** de l'expérience utilisateur
- **Analyse** des comportements
- **Décisions** de développement
- **Support** client amélioré

---

## 🔮 **ÉVOLUTIONS FUTURES**

### **1. ✅ Fonctionnalités prévues :**
- **Géolocalisation** des invités (optionnel)
- **Préférences** de contenu
- **Recommandations** personnalisées
- **Analytics** avancés

### **2. ✅ Améliorations techniques :**
- **Cache** des données invité
- **Synchronisation** multi-appareils
- **API** plus robuste
- **Monitoring** en temps réel

---

## 📚 **RÉFÉRENCES**

### **1. ✅ Documentation Flutter :**
- [SharedPreferences](https://docs.flutter.dev/cookbook/persistence/key-value)
- [Timer](https://api.flutter.dev/flutter/dart-async/Timer-class.html)
- [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)

### **2. ✅ Bonnes pratiques :**
- [Gestion du cycle de vie](https://docs.flutter.dev/development/ui/navigation/lifecycle)
- [Gestion des erreurs](https://docs.flutter.dev/testing/errors)
- [Performance](https://docs.flutter.dev/perf/best-practices)

---

## ✅ **CONCLUSION**

La fonctionnalité de **suivi des invités** est maintenant **entièrement intégrée** dans l'application EMB Mission ! 

**Fonctionnalités activées :**
- ✅ **Suivi automatique** toutes les 5 minutes
- ✅ **Génération d'ID unique** pour chaque invité
- ✅ **Mise à jour backend** via l'API `update_guest_last_active`
- ✅ **Gestion du cycle de vie** de l'application
- ✅ **Écran de test** pour le débogage
- ✅ **Logs détaillés** pour le monitoring

**L'API est maintenant active et fonctionnelle !** 🚀
