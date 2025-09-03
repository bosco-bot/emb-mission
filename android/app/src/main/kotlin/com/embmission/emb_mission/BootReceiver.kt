package com.embmission.emb_mission

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver pour redémarrer automatiquement le service radio au démarrage du téléphone
 */
class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                
                Log.d("BootReceiver", "🎵 Démarrage du téléphone détecté")
                
                try {
                    // Redémarrer le service radio en arrière-plan
                    val serviceIntent = Intent(context, RadioBackgroundService::class.java)
                    serviceIntent.putExtra("isRadioPlaying", false) // Démarrer silencieusement
                    context?.startService(serviceIntent)
                    
                    Log.d("BootReceiver", "✅ Service radio redémarré au boot")
                    
                } catch (e: Exception) {
                    Log.e("BootReceiver", "❌ Erreur lors du redémarrage du service: $e")
                }
            }
        }
    }
}
