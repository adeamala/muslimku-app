package com.example.muslimku

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Cek pengingat" in Pengaturan: battery optimisation and the system
        // settings screens, which the notifications plugin does not cover.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.muslimku/reminders")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "batteryUnrestricted" -> result.success(batteryUnrestricted())
                    "publishWidget" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.arguments as? Map<String, String>
                        if (data == null) {
                            result.error("args", "publishWidget needs a Map<String, String>", null)
                        } else {
                            PrayerWidgetProvider.publish(this, data)
                            result.success(true)
                        }
                    }
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun batteryUnrestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /// The system list of optimised apps (no special permission needed, unlike
    /// ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, which Play restricts).
    private fun openBatterySettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        } catch (_: Exception) {
            openAppDetails()
        }
    }

    private fun openNotificationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                )
            } else {
                openAppDetails()
            }
        } catch (_: Exception) {
            openAppDetails()
        }
    }

    private fun openAppDetails() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        )
    }
}
