import Flutter
import UIKit

public class AtomicVideoPlayerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register InlineVideoPlayer PlatformView (controls handled by Flutter)
        let inlineFactory = InlineVideoPlayerViewFactory(messenger: registrar.messenger())
        registrar.register(
            inlineFactory,
            withId: "tencent_chat_uikit/inline_video_player"
        )
    }
}
