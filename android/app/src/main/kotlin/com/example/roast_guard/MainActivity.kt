package com.example.roast_guard

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register UsageStats MethodChannel
        val usageStatsPlugin = UsageStatsPlugin(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UsageStatsPlugin.CHANNEL
        ).setMethodCallHandler(usageStatsPlugin)
    }
}
