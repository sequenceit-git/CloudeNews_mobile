package com.tencent.cloud.tuikit.flutter.tuichatkit.audioplayer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class AtomicAudioPlayerPlugin : FlutterPlugin {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var handler: AudioPlayerHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "tencent_chat_uikit/audio_player")
        eventChannel = EventChannel(binding.binaryMessenger, "tencent_chat_uikit/audio_player_events")

        handler = AudioPlayerHandler(methodChannel!!, eventChannel!!)

        methodChannel?.setMethodCallHandler(handler)
        eventChannel?.setStreamHandler(handler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        handler?.dispose()
        handler = null
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
    }
}
