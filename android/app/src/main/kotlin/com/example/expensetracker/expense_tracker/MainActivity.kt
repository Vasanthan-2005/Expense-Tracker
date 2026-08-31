package com.example.expensetracker.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.expense_tracker/bubble"
    private var methodChannel: MethodChannel? = null

    private val expenseReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == FloatingBubbleService.ACTION_EXPENSE_ADDED) {
                methodChannel?.invokeMethod("onExpenseAdded", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "startBubble" -> {
                    if (checkOverlayPermission()) {
                        val intent = Intent(this, FloatingBubbleService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopBubble" -> {
                    val intent = Intent(this, FloatingBubbleService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "isBubbleRunning" -> {
                    result.success(FloatingBubbleService.isRunning)
                }
                "updateTheme" -> {
                    val themeName = call.argument<String>("theme") ?: "dark"
                    val prefs = getSharedPreferences("bubble_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("theme_option", themeName).apply()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (FloatingBubbleService.isRunning) {
            val intent = Intent(this, FloatingBubbleService::class.java).apply {
                action = FloatingBubbleService.ACTION_HIDE_BUBBLE
            }
            startService(intent)
        }
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(FloatingBubbleService.ACTION_EXPENSE_ADDED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(expenseReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(expenseReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        try {
            unregisterReceiver(expenseReceiver)
        } catch (_: Exception) {}

        if (FloatingBubbleService.isRunning) {
            val intent = Intent(this, FloatingBubbleService::class.java).apply {
                action = FloatingBubbleService.ACTION_SHOW_BUBBLE
            }
            startService(intent)
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }
}
