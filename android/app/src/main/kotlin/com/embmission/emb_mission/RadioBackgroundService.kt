package com.embmission.emb_mission

import android.app.*
import android.content.Intent
import android.os.IBinder
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import com.embmission.emb_mission.MainActivity

class RadioBackgroundService : Service() {
    
    companion object {
        private const val CHANNEL_ID = "com.embmission.radio.background"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_NAME = "EMB-Mission Radio"
        private const val CHANNEL_DESCRIPTION = "Service de maintenance de la radio en arrière-plan"
    }
    
    // Variables pour gérer l'état de la notification
    private var isNotificationVisible = false
    private var isRadioPlaying = false
    
    // Variable pour stocker le timer de maintien en vie
    private var keepAliveHandler: android.os.Handler? = null
    private var keepAliveRunnable: Runnable? = null
    
    override fun onCreate() {
        super.onCreate()
        println("🎵 RadioBackgroundService.onCreate() - Service créé")
        createNotificationChannel()
        
        // Enregistrer le receiver pour les actions de notification
        val filter = android.content.IntentFilter().apply {
            addAction("RADIO_STOP")
            addAction("SHOW_NOTIFICATION")
            addAction("HIDE_NOTIFICATION")
            addAction("UPDATE_RADIO_STATE")
            addAction("FORCE_SHOW_NOTIFICATION")
            addAction("FORCE_HIDE_NOTIFICATION")
            addAction("FORCE_COMPLETE_SYNC")
        }
        registerReceiver(notificationActionReceiver, filter)
        println("🎵 Receiver enregistré avec succès")
    }
    
    private val notificationActionReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            println("🎵 Broadcast reçu: ${intent?.action}")
            when (intent?.action) {
                "RADIO_STOP" -> {
                    println("⏹️ Action Stop reçue")
                    sendActionToFlutter("STOP_RADIO")
                }
                "SHOW_NOTIFICATION" -> {
                    println("🎵 Demande d'affichage de notification")
                    showNotification()
                }
                "HIDE_NOTIFICATION" -> {
                    println("🔇 Demande de masquage de notification")
                    hideNotification()
                }
                "UPDATE_RADIO_STATE" -> {
                    val playing = intent.getBooleanExtra("isPlaying", false)
                    println("📻 Mise à jour de l'état radio reçue: $playing")
                    updateRadioState(playing)
                }
                "FORCE_SHOW_NOTIFICATION" -> {
                    println("🎵 Demande de forçage de notification reçue")
                    forceShowNotification()
                }
                "FORCE_HIDE_NOTIFICATION" -> {
                    println("🔇 Demande de masquage forcé de notification reçue")
                    forceHideNotification()
                }
                "FORCE_COMPLETE_SYNC" -> {
                    println("🔧 Demande de synchronisation complète reçue")
                    forceCompleteSync()
                }
            }
        }
    }
    
    private fun sendActionToFlutter(action: String) {
        try {
            val intent = Intent("RADIO_CONTROL_ACTION")
            intent.putExtra("action", action)
            sendBroadcast(intent)
            println("📡 Action envoyée vers Flutter: $action")
        } catch (e: Exception) {
            println("❌ Erreur lors de l'envoi vers Flutter: $e")
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val newRadioState = intent?.getBooleanExtra("isRadioPlaying", false) ?: false
        
        println("🎵 RadioBackgroundService.onStartCommand() - État radio: $newRadioState")
        println("🎵 État actuel - isRadioPlaying: $isRadioPlaying, isNotificationVisible: $isNotificationVisible")
        
        // ✅ CORRECTION CRITIQUE: TOUJOURS créer une notification technique au démarrage
        // Android exige que startForeground() soit appelé dans un délai imparti
        if (!isNotificationVisible) {
            println("🎵 Création de notification technique invisible obligatoire pour Android")
            val notification = createInvisibleNotification()
            startForeground(NOTIFICATION_ID, notification)
            isNotificationVisible = true
            println("🎵 ✅ Notification technique invisible créée pour respecter Android")
        }
        
        // ✅ Gestion de l'état radio
        if (newRadioState) {
            // Radio en cours → Maintenir la notification technique invisible
            println("🎵 Radio en cours - NOTIFICATION TECHNIQUE INVISIBLE MAINTAINUE")
        } else {
            // Radio arrêtée → Mode silencieux avec notification technique invisible
            println("🔇 Radio arrêtée - MODE SILENCIEUX AVEC NOTIFICATION TECHNIQUE INVISIBLE")
        }
        
        // Mettre à jour l'état
        isRadioPlaying = newRadioState
        println("🎵 État mis à jour - isRadioPlaying: $isRadioPlaying")
        
        // Démarrer le timer de maintien en vie
        startKeepAliveTimer()
        
        return START_STICKY
    }
    
    private fun startKeepAliveTimer() {
        // Arrêter le timer précédent s'il existe
        stopKeepAliveTimer()
        
        keepAliveHandler = android.os.Handler(android.os.Looper.getMainLooper())
        keepAliveRunnable = Runnable {
            try {
                println("💓 Timer de maintien en vie - Vérification...")
                println("💓 État actuel - isRadioPlaying: $isRadioPlaying, isNotificationVisible: $isNotificationVisible")
                
                // ✅ SYSTÈME BULLETPROOF : Vérification et correction automatique
                var correctionNeeded = false
                var correctionAction = ""
                
                // ✅ LOGIQUE : Vérifier la cohérence de la notification technique
                if (isRadioPlaying && !isNotificationVisible) {
                    println("⚠️ INCOHÉRENCE DÉTECTÉE: Radio joue mais notification technique invisible")
                    correctionNeeded = true
                    correctionAction = "FORCER_AFFICHAGE"
                } else 
                if (!isRadioPlaying && isNotificationVisible) {
                    println("⚠️ INCOHÉRENCE DÉTECTÉE: Radio arrêtée mais notification visible")
                    correctionNeeded = true
                    correctionAction = "FORCER_MASQUAGE"
                }
                
                // Vérifier que le service est toujours actif
                if (!isServiceRunning()) {
                    println("❌ Service inactif détecté")
                    correctionNeeded = true
                    correctionAction = "REDEMARRER_SERVICE"
                }
                
                // ✅ SOLUTION : Vérification de notification technique perdue
                if (isRadioPlaying && isNotificationVisible) {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val activeNotifications = notificationManager.activeNotifications
                    var notificationFound = false
                    
                    for (notif in activeNotifications) {
                        if (notif.id == NOTIFICATION_ID) {
                            notificationFound = true
                            break
                        }
                    }
                    
                    if (!notificationFound) {
                        println("⚠️ NOTIFICATION TECHNIQUE PERDUE: Notification supposée visible mais absente")
                        correctionNeeded = true
                        correctionAction = "RESTAURER_NOTIFICATION"
                    }
                }
                
                // Appliquer les corrections nécessaires
                if (correctionNeeded) {
                    println("🔧 CORRECTION AUTOMATIQUE NÉCESSAIRE: $correctionAction")
                    
                    when (correctionAction) {
                        "FORCER_AFFICHAGE" -> {
                            println("🔧 Correction: Affichage forcé de la notification technique")
                            forceShowNotification()
                        }
                        "FORCER_MASQUAGE" -> {
                            println("🔧 Correction: Masquage forcé de la notification")
                            forceHideNotification()
                        }
                        "REDEMARRER_SERVICE" -> {
                            println("🔧 Correction: Redémarrage du service")
                            val intent = Intent(this, RadioBackgroundService::class.java)
                            intent.putExtra("isRadioPlaying", isRadioPlaying)
                            startService(intent)
                        }
                        "RESTAURER_NOTIFICATION" -> {
                            println("🔧 Correction: Restauration de la notification technique")
                            forceShowNotification()
                        }
                    }
                    
                    println("🔧 ✅ Correction appliquée: $correctionAction")
                } else {
                    println("✅ États cohérents - Pas de correction nécessaire")
                }
                
                // Continuer le timer SEULEMENT si la radio joue
                if (isRadioPlaying && isServiceRunning()) {
                    println("✅ Service actif et radio joue - Continuer le timer")
                    startKeepAliveTimer()
                } else if (!isRadioPlaying) {
                    println("✅ Radio arrêtée - Arrêt du timer de maintien")
                    // Ne pas redémarrer le timer si la radio est arrêtée
                } else {
                    println("❌ Service inactif après correction - Redémarrage...")
                    val intent = Intent(this, RadioBackgroundService::class.java)
                    intent.putExtra("isRadioPlaying", isRadioPlaying)
                    startService(intent)
                }
            } catch (e: Exception) {
                println("❌ Erreur dans le timer de maintien: $e")
                e.printStackTrace()
                // Continuer malgré l'erreur SEULEMENT si la radio joue
                if (isRadioPlaying) {
                    startKeepAliveTimer()
                } else {
                    println("✅ Radio arrêtée - Arrêt du timer après erreur")
                }
            }
        }
        
        keepAliveHandler?.postDelayed(keepAliveRunnable!!, 5000) // 5 secondes pour une vérification ultra-fréquente
    }
    
    private fun stopKeepAliveTimer() {
        keepAliveRunnable?.let { runnable ->
            keepAliveHandler?.removeCallbacks(runnable)
        }
        keepAliveHandler = null
        keepAliveRunnable = null
        println("⏹️ Timer de maintien en vie arrêté")
    }
    
    fun showNotification() {
        try {
            println("🎵 showNotification() appelée - NOTIFICATION TECHNIQUE INVISIBLE")
            
            if (!isNotificationVisible) {
                println("🎵 Création de la notification technique invisible...")
                val notification = createInvisibleNotification()
                println("🎵 Notification technique créée avec succès")
                
                println("🎵 Démarrage startForeground avec ID: $NOTIFICATION_ID")
                startForeground(NOTIFICATION_ID, notification)
                println("🎵 startForeground exécuté avec succès")
                
                isNotificationVisible = true
                println("🎵 ✅ Notification technique invisible affichée (radio démarrée)")
                
            } else {
                println("ℹ️ Notification technique déjà visible - Maintien")
                // Maintenir la notification technique
                val notification = createInvisibleNotification()
                startForeground(NOTIFICATION_ID, notification)
                println("🎵 ✅ Notification technique invisible maintenue")
            }
        } catch (e: Exception) {
            println("❌ Erreur lors de l'affichage de la notification technique: $e")
            e.printStackTrace()
        }
    }
    
    fun hideNotification() {
        try {
            if (isNotificationVisible) {
                println("🔇 Masquage de la notification...")
                // ✅ CORRECTION: Ne jamais arrêter le foreground service
                // Maintenir la notification technique invisible
                val invisibleNotification = createInvisibleNotification()
                startForeground(NOTIFICATION_ID, invisibleNotification)
                println("🔇 ✅ Notification technique invisible maintenue (radio arrêtée)")
            } else {
                println("ℹ️ Notification déjà masquée")
            }
        } catch (e: Exception) {
            println("❌ Erreur lors du masquage de la notification: $e")
        }
    }
    
    fun updateRadioState(playing: Boolean) {
        println("📻 updateRadioState() appelée avec: $playing")
        println("📻 État actuel - isRadioPlaying: $isRadioPlaying, isNotificationVisible: $isNotificationVisible")
        
        // ✅ CORRECTION: Arrêter complètement le service quand la radio s'arrête
        if (playing) {
            // Radio démarrée → Notification technique invisible
            println("📻 Radio démarrée - NOTIFICATION TECHNIQUE INVISIBLE")
            forceShowNotification()
        } else {
            // Radio arrêtée → ARRÊTER COMPLÈTEMENT le service
            println("📻 Radio arrêtée - ARRÊT COMPLET du service")
            stopSelf()
            return
        }
        
        // Mettre à jour l'état
        isRadioPlaying = playing
        println("📻 État final - isRadioPlaying: $isRadioPlaying, isNotificationVisible: $isNotificationVisible")
    }
    
    /// ✅ NOUVEAU: Masquage FORCÉ de la notification (logique robuste)
    fun forceHideNotification() {
        try {
            println("🔇 FORCE HIDE NOTIFICATION - Masquage forcé...")
            
            // ✅ CORRECTION: Ne jamais arrêter complètement le foreground service
            // Android exige qu'il reste actif avec une notification
            if (isNotificationVisible) {
                println("🔇 Service en mode foreground - Maintien de la notification technique invisible")
                // Créer une notification encore plus invisible
                val invisibleNotification = createInvisibleNotification()
                startForeground(NOTIFICATION_ID, invisibleNotification)
                println("🔇 Notification technique invisible maintenue pour Android")
            } else {
                println("🔇 Service pas en mode foreground - Pas de modification nécessaire")
            }
            
            // ✅ IMPORTANT: Ne jamais réinitialiser isNotificationVisible à false
            // Le service doit rester en mode foreground
            println("🔇 ✅ Notification technique invisible maintenue pour respecter Android")
            
        } catch (e: Exception) {
            println("❌ Erreur lors du masquage forcé: $e")
            e.printStackTrace()
            // En cas d'erreur, maintenir quand même l'état
            isNotificationVisible = true
        }
    }
    
    /// ✅ SOLUTION : Affichage FORCÉ de la notification technique invisible
    fun forceShowNotification() {
        try {
            println("🎵 FORCE SHOW NOTIFICATION - Notification technique invisible...")
            
            // ✅ CORRECTION: Maintenir toujours le service en mode foreground
            if (!isNotificationVisible) {
                // Créer et afficher la notification technique
                val notification = createInvisibleNotification()
                println("🎵 Notification technique créée pour affichage forcé")
                
                // Démarrer le foreground service
                startForeground(NOTIFICATION_ID, notification)
                println("🎵 startForeground forcé avec succès")
                
                // Mettre à jour l'état
                isNotificationVisible = true
                println("🎵 ✅ Notification technique forcée affichée avec succès")
            } else {
                // Notification déjà visible, la maintenir
                println("🎵 Notification technique déjà visible - Maintien")
                val notification = createInvisibleNotification()
                startForeground(NOTIFICATION_ID, notification)
                println("🎵 ✅ Notification technique maintenue")
            }
            
        } catch (e: Exception) {
            println("❌ Erreur lors de l'affichage forcé de la notification technique: $e")
            e.printStackTrace()
            // En cas d'erreur, forcer quand même l'état
            isNotificationVisible = true
        }
    }
    
    /// ✅ NOUVEAU: Nettoyage et synchronisation complète (pour corriger tous les problèmes)
    fun forceCompleteSync() {
        try {
            println("🔧 FORCE COMPLETE SYNC - Nettoyage et synchronisation complète...")
            
            // 1. Vérifier l'état actuel
            println("🔧 État actuel - isRadioPlaying: $isRadioPlaying, isNotificationVisible: $isNotificationVisible")
            
            // 2. Vérifier que le service est actif
            if (!isServiceRunning()) {
                println("🔧 Service inactif détecté - Redémarrage...")
                val intent = Intent(this, RadioBackgroundService::class.java)
                intent.putExtra("isRadioPlaying", isRadioPlaying)
                startService(intent)
                return
            }
            
            // ✅ SOLUTION : Vérification de cohérence avec notifications techniques
            if (isRadioPlaying) {
                // Radio devrait jouer - Vérifier la notification technique
                if (!isNotificationVisible) {
                    println("🔧 Incohérence: Radio joue mais notification technique invisible - Correction...")
                    forceShowNotification()
                } else {
                    println("🔧 ✅ État cohérent: Radio joue + notification technique visible")
                }
            } else {
                // Radio devrait être arrêtée
                if (isNotificationVisible) {
                    println("🔧 Incohérence: Radio arrêtée mais notification technique visible - Correction...")
                    // ✅ CORRECTION: Maintenir la notification technique invisible
                    val invisibleNotification = createInvisibleNotification()
                    startForeground(NOTIFICATION_ID, invisibleNotification)
                    println("🔧 ✅ Notification technique invisible maintenue pour Android")
                } else {
                    println("🔧 ✅ État cohérent: Radio arrêtée + notification technique invisible")
                }
            }
            
            println("🔧 ✅ Synchronisation complète terminée")
            
        } catch (e: Exception) {
            println("❌ Erreur lors de la synchronisation complète: $e")
            e.printStackTrace()
        }
    }
    
    private fun isServiceRunning(): Boolean {
        try {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
                if (RadioBackgroundService::class.java.name == service.service.className) {
                    return true
                }
            }
        } catch (e: Exception) {
            println("❌ Erreur lors de la vérification du service: $e")
        }
        return false
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        println("🎵 RadioBackgroundService.onDestroy() - Service détruit")
        
        // ✅ CORRECTION: Arrêter le timer de maintien en vie
        stopKeepAliveTimer()
        
        try {
            unregisterReceiver(notificationActionReceiver)
            println("✅ Receiver désenregistré")
        } catch (e: Exception) {
            println("❌ Erreur lors de la désinscription du receiver: $e")
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            println("🎵 createNotificationChannel() - Création du canal de notification technique...")
            
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MIN // Importance minimale
            ).apply {
                description = "Canal technique pour la radio en arrière-plan" // Description technique
                setShowBadge(false) // Pas de badge
                enableLights(false) // Pas de lumière
                enableVibration(false) // Pas de vibration
                setSound(null, null) // Pas de son
                lockscreenVisibility = Notification.VISIBILITY_SECRET // Visibilité secrète
                setBypassDnd(false) // Ne pas contourner le mode ne pas déranger
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val result = notificationManager.createNotificationChannel(channel)
            println("🎵 Canal de notification technique créé: $result")
            println("🎵 Canal ID: $CHANNEL_ID")
            println("🎵 Canal nom: $CHANNEL_NAME")
            println("🎵 Canal importance: ${channel.importance}")
        } else {
            println("🎵 Pas de création de canal nécessaire (API < 26)")
        }
    }
    
    /// ✅ NOUVEAU: Création de notification technique invisible
    private fun createInvisibleNotification(): Notification {
        println("🎵 createInvisibleNotification() - Création de la notification technique invisible...")
        
        // Créer une notification technique minimale et invisible
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("") // Titre vide
            .setContentText("") // Texte vide
            .setSmallIcon(R.mipmap.ic_launcher) // Icône minimale
            .setPriority(NotificationCompat.PRIORITY_MIN) // Priorité minimale
            .setOngoing(true) // Notification persistante
            .setAutoCancel(false) // Ne pas annuler automatiquement
            .setSilent(true) // Pas de son
            .setVibrate(null) // Pas de vibration
            .setLights(0, 0, 0) // Pas de lumière
            .setCategory(NotificationCompat.CATEGORY_SERVICE) // Catégorie service
            .setVisibility(NotificationCompat.VISIBILITY_SECRET) // Visibilité secrète
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("") // Texte vide
                .setBigContentTitle("") // Titre vide
                .setSummaryText("")) // Résumé vide
        
        // Pas d'actions visibles
        // Pas de contrôles utilisateur
        
        return builder.build()
    }
    
    private fun createNotification(): Notification {
        println("🎵 createNotification() - Création de la notification...")
        
        // Créer une notification visible et informative
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎵 EMB-Mission Radio")
            .setContentText("Radio en cours de lecture")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(android.graphics.BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSilent(false)
            .setVibrate(longArrayOf(0L, 100L, 50L, 100L))
            .setLights(0xFF2196F3.toInt(), 1000, 1000)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("🎵 EMB-Mission Radio en cours de lecture\nCliquez pour contrôler la radio")
                .setBigContentTitle("🎵 Radio Active")
                .setSummaryText("Contrôles rapides disponibles"))
        
        // Action pour arrêter la radio
        val stopIntent = Intent("RADIO_STOP")
        val stopPendingIntent = PendingIntent.getBroadcast(
            this, 1, stopIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Action pour ouvrir l'app
        val openAppIntent = Intent(this, MainActivity::class.java)
        openAppIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 2, openAppIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        builder.addAction(
            android.R.drawable.ic_media_pause, 
            "Stop", 
            stopPendingIntent
        )
        .addAction(
            android.R.drawable.ic_menu_view, 
            "Ouvrir App", 
            openAppPendingIntent
        )
        
        return builder.build()
    }
}
