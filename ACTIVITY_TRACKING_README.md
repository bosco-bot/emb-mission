# 📱 **SUIVI D'ACTIVITÉ UNIFIÉ - EMB Mission**

---

## 🎯 **DESCRIPTION GÉNÉRALE**

Le **suivi d'activité unifié** permet de tracer l'activité de **tous les utilisateurs** de l'application EMB Mission :
- **📱 Invités** : Utilisateurs anonymes (non connectés)
- **👤 Utilisateurs connectés** : Utilisateurs authentifiés

**Fréquence identique** : Mise à jour toutes les **5 minutes** pour les deux types d'utilisateurs.

---

## 🏗️ **ARCHITECTURE COMPLÈTE**

### **1. ✅ Composants principaux :**

- **`GuestService`** : Service pour les invités anonymes
- **`UserActivityService`** : Service pour les utilisateurs connectés
- **`GuestActivityTracker`** : Widget wrapper pour le suivi des invités
- **`UserActivityTracker`** : Widget wrapper pour le suivi des utilisateurs connectés
- **`TestActivityTrackingScreen`** : Écran de test unifié

### **2. ✅ Structure des fichiers :**

```
lib/
├── core/
│   ├── services/
│   │   ├── user_activity_service.dart     # Service utilisateurs connectés
│   │   └── auth_service.dart              # Service d'authentification
│   └── widgets/
│       ├── guest_activity_tracker.dart    # Tracker invités
│       └── user_activity_tracker.dart     # Tracker utilisateurs connectés
├── tools/
│   └── test_activity_tracking.dart        # Écran de test unifié
└── main.dart                              # Intégration principale
```

---

## 🚀 **FONCTIONNALITÉS**

### **1. ✅ Suivi des invités :**
- **Endpoint** : `https://embmission.com/mobileappebm/api/update_guest_last_active`
- **Paramètre** : `guestId` (ID unique généré)
- **Fréquence** : Toutes les 5 minutes
- **Stockage** : `SharedPreferences` avec clé `guest_id`

### **2. ✅ Suivi des utilisateurs connectés :**
- **Endpoint** : `https://embmission.com/mobileappebm/api/update_user_last_active`
- **Paramètre** : `user_id` (ID Firebase Auth)
- **Fréquence** : Toutes les 5 minutes
- **Stockage** : `SharedPreferences` avec clé `user_last_active`

### **3. ✅ Gestion intelligente :**
- **Activation automatique** selon le type d'utilisateur
- **Détection de connexion/déconnexion** en temps réel
- **Gestion du cycle de vie** de l'application
- **Optimisation** des appels API
- **✅ Transition automatique** invité → utilisateur connecté
- **✅ Nettoyage automatique** des données invité
- **✅ Prévention du double comptage**
- **✅ Récupération proactive** des données avant fermeture
- **✅ Restauration immédiate** à l'ouverture
- **✅ Prévention de la perte** d'avatar et de nom

---

## 🔧 **INTÉGRATION DANS L'APPLICATION**

### **1. ✅ Structure dans main.dart :**

```dart
return AppExitProtection(
  child: UserActivityTracker(              // ← Suivi utilisateurs connectés
    child: GuestActivityTracker(           // ← Suivi invités
      child: NotificationServiceInitializer(
        child: MaterialApp.router(...)
      ),
    ),
  ),
);
```

### **2. ✅ Logique d'activation :**

- **`UserActivityTracker`** : S'active uniquement si un utilisateur est connecté
- **`GuestActivityTracker`** : S'active toujours (pour les invités)
- **Gestion automatique** des transitions entre les deux états
- **✅ Transition invité → utilisateur** : Nettoyage automatique des données invité
- **✅ Prévention du double comptage** : Un utilisateur = un statut
- **✅ Gestion intelligente** des connexions/déconnexions
- **✅ Récupération proactive** : Données sauvegardées avant fermeture
- **✅ Restauration intelligente** : Données disponibles immédiatement

---

## 📊 **APIS BACKEND**

### **1. ✅ API Invités :**
```
GET https://embmission.com/mobileappebm/api/update_guest_last_active
Paramètre: guestId
Réponse: {"success": "true"}
```

### **2. ✅ API Utilisateurs connectés :**
```
GET https://embmission.com/mobileappebm/api/update_user_last_active
Paramètre: user_id
Réponse: {"success": "true"}
```

### **3. ✅ Gestion des réponses :**
- **Statut 200 + success: "true"** : Succès
- **Autres cas** : Gérés gracieusement avec logs détaillés

---

## 🧪 **TEST ET DÉBOGAGE**

### **1. ✅ Écran de test unifié :**

L'écran `TestActivityTrackingScreen` permet de :
- **Voir** les informations des invités ET des utilisateurs connectés
- **Tester** les deux APIs séparément
- **Vérifier** les timestamps et statuts
- **Générer** de nouveaux IDs invités
- **Nettoyer** toutes les données
- **✅ Simuler** la transition invité → utilisateur connecté
- **✅ Tester** le nettoyage automatique des données invité
- **✅ Vérifier** la prévention du double comptage
- **✅ Tester** la récupération proactive des données
- **✅ Vérifier** le système de restauration
- **✅ Monitorer** les performances du système

### **2. ✅ Logs de débogage :**

#### **Logs invités :**
```
🆔 Nouvel ID invité généré: guest_1703123456789_123456
🚀 Suivi d'activité invité initialisé pour: guest_1703123456789_123456
🔄 Mise à jour de l'activité invité: guest_1703123456789_123456
✅ Activité invité mise à jour avec succès
🟢 Invité actif: guest_1703123456789_123456
```

#### **Logs utilisateurs connectés :**
```
🚀 Suivi d'activité utilisateur initialisé pour: CbmPcejiGNdm6ly4ndskTtjdQy33
🔄 Mise à jour de l'activité utilisateur: CbmPcejiGNdm6ly4ndskTtjdQy33
✅ Activité utilisateur mise à jour avec succès
🟢 Utilisateur actif: CbmPcejiGNdm6ly4ndskTtjdQy33
```

#### **Logs de transition invité → utilisateur :**
```
🔄 Transition détectée: Invité → Utilisateur connecté
🧹 Nettoyage des données invité pour: CbmPcejiGNdm6ly4ndskTtjdQy33
✅ Transition invité → utilisateur terminée avec succès
📊 L'utilisateur n'est plus compté parmi les invités
```

#### **Logs de récupération proactive :**
```
🔄 App en pause/fermeture - Récupération proactive des données utilisateur
🔄 Récupération proactive des données utilisateur pour: CbmPcejiGNdm6ly4ndskTtjdQy33
✅ Avatar utilisateur récupéré et sauvegardé: data:image/jpeg;base64,...
✅ Nom utilisateur récupéré et sauvegardé: John Doe
✅ Récupération proactive terminée avant fermeture de l'app
```

#### **Logs de restauration :**
```
🔄 Restauration immédiate des données proactives...
✅ Données proactives récentes disponibles (45 minutes)
📊 Avatar et nom utilisateur restaurés immédiatement
```

### **3. ✅ Accès à l'écran de test :**

Pour accéder à l'écran de test, ajoutez une route dans votre routeur :

```dart
// Dans app_router.dart
GoRoute(
  path: '/test-activity-tracking',
  builder: (context, state) => const TestActivityTrackingScreen(),
),
```

---

## ⚙️ **CONFIGURATION**

### **1. ✅ Fréquences de mise à jour :**

```dart
// Invités (GuestActivityTracker)
_activityTimer = Timer.periodic(const Duration(minutes: 5), (_) {
  _updateGuestActivity();
});

// Utilisateurs connectés (UserActivityTracker)
_activityTimer = Timer.periodic(const Duration(minutes: 5), (_) {
  _updateUserActivity();
});
```

### **2. ✅ Timeouts et gestion d'erreurs :**

```dart
final response = await http.get(url).timeout(
  const Duration(seconds: 10),
  onTimeout: () {
    throw TimeoutException('Timeout lors de la mise à jour de l\'activité');
  },
);
```

### **3. ✅ Seuils d'activité :**

```dart
// Un utilisateur est considéré actif si sa dernière activité est < 1 heure
final difference = DateTime.now().difference(lastActive);
return difference.inHours < 1;
```

---

## 🔒 **SÉCURITÉ ET PRIVACY**

### **1. ✅ Données collectées :**

#### **Invités :**
- **ID invité** : Identifiant unique anonyme
- **Timestamp** : Heure de la dernière activité
- **Aucune** information personnelle

#### **Utilisateurs connectés :**
- **User ID** : ID Firebase Auth (déjà connu)
- **Timestamp** : Heure de la dernière activité
- **Aucune** information supplémentaire

### **2. ✅ Stockage local :**
- **SharedPreferences** : Stockage sécurisé de l'app
- **Séparation** des données invités/utilisateurs
- **Suppression** automatique lors de la déconnexion

### **3. ✅ Gestion des erreurs :**
- **Timeout** : 10 secondes maximum
- **Fallback** : Gestion gracieuse des échecs
- **Logs** : Débogage sans exposition de données sensibles

---

## 🚨 **DÉPANNAGE**

### **1. ✅ Problèmes courants :**

| **Symptôme** | **Cause possible** | **Solution** |
|--------------|-------------------|--------------|
| Pas de logs utilisateur | Utilisateur non connecté | Vérifier l'état d'authentification |
| Erreur API invité | Endpoint incorrect | Vérifier l'URL dans GuestService |
| Erreur API utilisateur | Endpoint incorrect | Vérifier l'URL dans UserActivityService |
| Double activation | Tracker mal configuré | Vérifier l'ordre dans main.dart |

### **2. ✅ Vérifications :**

```bash
# Vérifier que les trackers sont intégrés
grep -r "UserActivityTracker" lib/main.dart
grep -r "GuestActivityTracker" lib/main.dart

# Vérifier que les APIs sont accessibles
curl "https://embmission.com/mobileappebm/api/update_guest_last_active?guestId=test"
curl "https://embmission.com/mobileappebm/api/update_user_last_active?user_id=test"

# Vérifier les logs
flutter logs | grep "activité"
```

### **3. ✅ Solutions :**

- **Redémarrer l'app** : Force la réinitialisation
- **Vérifier la console** : Logs détaillés disponibles
- **Tester les APIs** : Utiliser l'écran de test unifié
- **Vérifier l'authentification** : S'assurer que l'utilisateur est connecté

---

## 📈 **MÉTRIQUES ET ANALYTICS**

### **1. ✅ Données collectées :**
- **Nombre d'invités** actifs
- **Nombre d'utilisateurs connectés** actifs
- **Fréquence d'utilisation** de l'app
- **Temps de session** moyen par type d'utilisateur
- **Taux de conversion** invité → utilisateur

### **2. ✅ Utilisation des données :**
- **Optimisation** de l'expérience utilisateur
- **Analyse** des comportements par segment
- **Décisions** de développement
- **Support** client amélioré
- **Marketing** ciblé

---

## 🔮 **ÉVOLUTIONS FUTURES**

### **1. ✅ Fonctionnalités prévues :**
- **Géolocalisation** (optionnel)
- **Préférences** de contenu par type d'utilisateur
- **Recommandations** personnalisées
- **Analytics** avancés avec segmentation
- **A/B testing** par segment

### **2. ✅ Améliorations techniques :**
- **Cache** des données d'activité
- **Synchronisation** multi-appareils
- **APIs** plus robustes avec retry
- **Monitoring** en temps réel
- **Alertes** de performance

---

## 📚 **RÉFÉRENCES**

### **1. ✅ Documentation Flutter :**
- [SharedPreferences](https://docs.flutter.dev/cookbook/persistence/key-value)
- [Timer](https://api.flutter.dev/flutter/dart-async/Timer-class.html)
- [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
- [ConsumerStatefulWidget](https://riverpod.dev/docs/concepts/reading)

### **2. ✅ Bonnes pratiques :**
- [Gestion du cycle de vie](https://docs.flutter.dev/development/ui/navigation/lifecycle)
- [Gestion des erreurs](https://docs.flutter.dev/testing/errors)
- [Performance](https://docs.flutter.dev/perf/best-practices)
- [Riverpod](https://riverpod.dev/docs/concepts/providers)

---

## ✅ **CONCLUSION**

Le **suivi d'activité unifié** est maintenant **entièrement intégré** dans l'application EMB Mission ! 

**Fonctionnalités activées :**
- ✅ **Suivi automatique des invités** toutes les 5 minutes
- ✅ **Suivi automatique des utilisateurs connectés** toutes les 5 minutes
- ✅ **Gestion intelligente** selon l'état d'authentification
- ✅ **APIs actives** pour les deux types d'utilisateurs
- ✅ **Gestion du cycle de vie** de l'application
- ✅ **Écran de test unifié** pour le débogage
- ✅ **Logs détaillés** pour le monitoring

**Les deux APIs sont maintenant actives et fonctionnelles !** 🚀

**Structure finale :**
```
AppExitProtection
└── UserActivityTracker (utilisateurs connectés)
    └── GuestActivityTracker (invités)
        └── NotificationServiceInitializer
            └── MaterialApp.router
```

**Fréquence unifiée : 5 minutes pour tous les utilisateurs !** ⏰
