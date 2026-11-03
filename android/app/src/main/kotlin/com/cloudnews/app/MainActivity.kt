package com.cloudnews.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cloudnews.app/meeting_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val title = call.argument<String>("title") ?: "CloudNews Meeting Active"
                    val body = call.argument<String>("body") ?: "Audio active in background"
                    val isScreenSharing = call.argument<Boolean>("isScreenSharing") ?: false
                    MeetingForegroundService.startService(this, title, body, isScreenSharing)
                    result.success(true)
                }
                "updateService" -> {
                    val title = call.argument<String>("title") ?: "CloudNews Meeting Active"
                    val body = call.argument<String>("body") ?: "Audio active in background"
                    val isScreenSharing = call.argument<Boolean>("isScreenSharing") ?: false
                    MeetingForegroundService.updateService(this, title, body, isScreenSharing)
                    result.success(true)
                }
                "stopService" -> {
                    MeetingForegroundService.stopService(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
