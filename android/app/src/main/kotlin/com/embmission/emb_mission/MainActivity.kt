package com.embmission.emb_mission

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.embmission.android_background"
    private val RADIO_CONTROL_CHANNEL = "com.embmission.radio_control"
    private var radioControlChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        println("🎵 MainActivity.configureFlutterEngine() - Configuration du canal: $CHANNEL")
        
        // Canal pour les services en arrière-plan
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            println("🎵 MainActivity.MethodCallHandler - Méthode reçue: ${call.method}")
            
            when (call.method) {
                "startRadioBackgroundService" -> {
                    println("🎵 MainActivity - startRadioBackgroundService() appelée")
                    startRadioBackgroundService()
                    result.success(true)
                }
                "startRadioBackgroundServiceSilent" -> {
                    startRadioBackgroundServiceSilent()
                    result.success(true)
                }
                "stopRadioBackgroundService" -> {
                    stopRadioBackgroundService()
                    result.success(true)
                }
                "showNotification" -> {
                    println("🎵 MainActivity - showNotification() appelée")
                    showNotification()
                    result.success(true)
                }
                "hideNotification" -> {
                    println("🎵 MainActivity - hideNotification() appelée")
                    hideNotification()
                    result.success(true)
                }
                "updateRadioState" -> {
                    val isPlaying = call.arguments as Boolean? ?: false
                    println("🎵 MainActivity - updateRadioState() appelée avec: $isPlaying")
                    updateRadioState(isPlaying)
                    result.success(true)
                }
                "forceShowNotification" -> {
                    println("🎵 Demande de forçage de notification")
                    forceShowNotification()
                }
                "forceHideNotification" -> {
                    println("🔇 Demande de masquage forcé de notification")
                    forceHideNotification()
                }
                "forceCompleteSync" -> {
                    println("🔧 Demande de synchronisation complète")
                    forceCompleteSync()
                }
                "startServiceViaIntent" -> {
                    startServiceViaIntent()
                    result.success(true)
                }
                "startServiceViaIntentSilent" -> {
                    startServiceViaIntentSilent()
                    result.success(true)
                }
                "keepServiceAlive" -> {
                    keepServiceAlive()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Canal pour les contrôles de radio
        radioControlChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RADIO_CONTROL_CHANNEL)
        
        // Enregistrer le receiver pour les actions de notification
        registerRadioControlReceiver()
    }
    
    private fun registerRadioControlReceiver() {
        val filter = android.content.IntentFilter("RADIO_CONTROL_ACTION")
        registerReceiver(radioControlReceiver, filter)
        println("📡 Receiver radio control enregistré")
    }
    
    private val radioControlReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "RADIO_CONTROL_ACTION") {
                val action = intent.getStringExtra("action")
                println("📡 Action reçue du service: $action")
                
                // Relayer l'action vers Flutter
                radioControlChannel?.invokeMethod("onRadioAction", mapOf("action" to action))
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(radioControlReceiver)
        } catch (e: Exception) {
            println("❌ Erreur lors de la désinscription du receiver: $e")
        }
    }
    
    private fun startRadioBackgroundService() {
        try {
            val intent = Intent(this, RadioBackgroundService::class.java)
            // ✅ NOUVEAU: Passer l'état de la radio
            intent.putExtra("isRadioPlaying", true)
            
            println("🎵 MainActivity.startRadioBackgroundService() - isRadioPlaying: true")
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            println("✅ Service RadioBackgroundService démarré (radio active)")
        } catch (e: Exception) {
            println("❌ Erreur lors du démarrage du service: $e")
        }
    }
    
    /// ✅ NOUVEAU: Démarrer le service sans notification (radio arrêtée)
    private fun startRadioBackgroundServiceSilent() {
        try {
            val intent = Intent(this, RadioBackgroundService::class.java)
            // ✅ NOUVEAU: Passer l'état de la radio
            intent.putExtra("isRadioPlaying", false)
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            println("✅ Service RadioBackgroundService démarré (radio arrêtée)")
        } catch (e: Exception) {
            println("❌ Erreur lors du démarrage du service: $e")
        }
    }
    
    private fun stopRadioBackgroundService() {
        try {
            val intent = Intent(this, RadioBackgroundService::class.java)
            stopService(intent)
            println("✅ Service RadioBackgroundService arrêté")
        } catch (e: Exception) {
            println("❌ Erreur lors de l'arrêt du service: $e")
        }
    }
    
    private fun startServiceViaIntent() {
        try {
            val intent = Intent(this, RadioBackgroundService::class.java)
            intent.action = "START_RADIO_BACKGROUND"
            // ✅ CORRECTION: Mode avec notification pour la radio live
            intent.putExtra("isRadioPlaying", true)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            println("✅ Service démarré via Intent (mode avec notification)")
        } catch (e: Exception) {
            println("❌ Erreur lors du démarrage via Intent: $e")
        }
    }
    
    private fun startServiceViaIntentSilent() {
        try {
            val intent = Intent(this, RadioBackgroundService::class.java)
            intent.action = "START_RADIO_BACKGROUND"
            // ✅ Mode silencieux pour la maintenance
            intent.putExtra("isRadioPlaying", false)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            println("✅ Service démarré via Intent (mode silencieux)")
        } catch (e: Exception) {
            println("❌ Erreur lors du démarrage silencieux via Intent: $e")
        }
    }
    
    private fun keepServiceAlive() {
        try {
            // Envoyer un broadcast pour maintenir le service actif
            val intent = Intent("KEEP_SERVICE_ALIVE")
            sendBroadcast(intent)
            println("💓 Signal de maintien en vie envoyé")
        } catch (e: Exception) {
            println("❌ Erreur lors du maintien en vie: $e")
        }
    }
    
    /// ✅ NOUVEAU: Afficher la notification
    private fun showNotification() {
        try {
            // Envoyer un broadcast pour afficher la notification
            val intent = Intent("SHOW_NOTIFICATION")
            sendBroadcast(intent)
            println("🎵 Demande d'affichage de notification")
        } catch (e: Exception) {
            println("❌ Erreur lors de la demande d'affichage: $e")
        }
    }
    
    /// ✅ NOUVEAU: Masquer la notification
    private fun hideNotification() {
        try {
            // Envoyer un broadcast pour masquer la notification
            val intent = Intent("HIDE_NOTIFICATION")
            sendBroadcast(intent)
            println("🔇 Demande de masquage de notification")
        } catch (e: Exception) {
            println("❌ Erreur lors de la demande de masquage: $e")
        }
    }
    
    /// ✅ NOUVEAU: Mettre à jour l'état de la radio
    private fun updateRadioState(isPlaying: Boolean) {
        try {
            // Envoyer un broadcast pour mettre à jour l'état
            val intent = Intent("UPDATE_RADIO_STATE")
            intent.putExtra("isPlaying", isPlaying)
            sendBroadcast(intent)
            println("📻 Demande de mise à jour de l'état radio: $isPlaying")
        } catch (e: Exception) {
            println("❌ Erreur lors de la mise à jour de l'état: $e")
        }
    }
    
    /// ✅ NOUVEAU: Forcer l'affichage de la notification
    private fun forceShowNotification() {
        try {
            // Envoyer un broadcast pour forcer l'affichage
            val intent = Intent("FORCE_SHOW_NOTIFICATION")
            sendBroadcast(intent)
            println("🎵 Demande de forçage de notification")
        } catch (e: Exception) {
            println("❌ Erreur lors du forçage de notification: $e")
        }
    }

    /// ✅ NOUVEAU: Forcer le masquage de la notification
    private fun forceHideNotification() {
        try {
            // Envoyer un broadcast pour forcer le masquage
            val intent = Intent("FORCE_HIDE_NOTIFICATION")
            sendBroadcast(intent)
            println("🔇 Demande de masquage forcé de notification")
        } catch (e: Exception) {
            println("❌ Erreur lors du masquage forcé de notification: $e")
        }
    }

    /// ✅ NOUVEAU: Forcer la synchronisation complète
    private fun forceCompleteSync() {
        try {
            // Envoyer un broadcast pour forcer la synchronisation complète
            val intent = Intent("FORCE_COMPLETE_SYNC")
            sendBroadcast(intent)
            println("🔧 Demande de synchronisation complète envoyée")
        } catch (e: Exception) {
            println("❌ Erreur lors de la demande de synchronisation complète: $e")
        }
    }
}
