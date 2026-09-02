package com.smartspend.smartspend

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val SMS_CHANNEL = "com.smartspend/sms"
    private val SMS_PERMISSION_REQ_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS), SMS_PERMISSION_REQ_CODE)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "readInboxSms" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                        result.error("PERMISSION_DENIED", "READ_SMS permission not granted", null)
                        return@setMethodCallHandler
                    }
                    val limit = call.argument<Int>("limit") ?: 2000
                    val smsList = queryFinancialSms(limit)
                    result.success(smsList)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun queryFinancialSms(limit: Int): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("_id", "address", "body", "date")
        
        // Filter for financial senders and keywords
        val selection = "body LIKE ? OR body LIKE ? OR body LIKE ? OR body LIKE ? OR body LIKE ?"
        val selectionArgs = arrayOf("%Rs%", "%INR%", "%debited%", "%credited%", "%spent%")
        val sortOrder = "date DESC LIMIT $limit"

        contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
            val addressCol = cursor.getColumnIndex("address")
            val bodyCol = cursor.getColumnIndex("body")
            val dateCol = cursor.getColumnIndex("date")

            while (cursor.moveToNext()) {
                val address = if (addressCol >= 0) cursor.getString(addressCol) ?: "" else ""
                val body = if (bodyCol >= 0) cursor.getString(bodyCol) ?: "" else ""
                val date = if (dateCol >= 0) cursor.getLong(dateCol) else System.currentTimeMillis()

                messages.add(mapOf(
                    "sender" to address,
                    "body" to body,
                    "timestamp" to date
                ))
            }
        }
        return messages
    }
}
