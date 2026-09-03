package com.smartspend.smartspend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import io.flutter.plugin.common.EventChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        var eventSink: EventChannel.EventSink? = null
        private const val PREFS_NAME = "smartspend_sms_queue"
        private const val QUEUE_KEY = "pending_sms"

        fun getQueuedMessages(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val queue = prefs.getStringSet(QUEUE_KEY, emptySet()) ?: emptySet()
            val list = mutableListOf<Map<String, Any>>()
            for (item in queue) {
                val parts = item.split("|#|")
                if (parts.size >= 3) {
                    list.add(mapOf(
                        "sender" to parts[0],
                        "body" to parts[1],
                        "timestamp" to (parts[2].toLongOrNull() ?: System.currentTimeMillis())
                    ))
                }
            }
            // Clear queue after retrieval
            prefs.edit().remove(QUEUE_KEY).apply()
            return list
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val sender = sms.displayOriginatingAddress ?: ""
                val body = sms.displayMessageBody ?: ""
                val timestamp = sms.timestampMillis

                val smsMap = mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp
                )

                if (eventSink != null) {
                    // App is active: stream directly to Flutter
                    eventSink?.success(smsMap)
                } else {
                    // App is in background or process-killed: persist to SharedPreferences queue
                    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val existing = prefs.getStringSet(QUEUE_KEY, mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                    existing.add("$sender|#|$body|#|$timestamp")
                    prefs.edit().putStringSet(QUEUE_KEY, existing).apply()
                }
            }
        }
    }
}
