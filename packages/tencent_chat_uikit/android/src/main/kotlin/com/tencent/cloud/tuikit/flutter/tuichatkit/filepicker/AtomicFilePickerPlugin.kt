package com.tencent.cloud.tuikit.flutter.tuichatkit.filepicker
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class AtomicFilePickerPlugin : FlutterPlugin {
    private var methodChannel: MethodChannel? = null
    private var handler: FilePickerHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "tencent_chat_uikit/file_picker")

        handler = FilePickerHandler(
            context = binding.applicationContext,
            methodChannel = methodChannel!!
        )

        methodChannel?.setMethodCallHandler(handler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        handler?.dispose()
        handler = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}
