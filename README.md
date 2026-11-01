# CloudNews

Android and iOS meeting app. The meeting room uses the Tencent TRTC Flutter engine (`tencent_rtc_sdk`), not TUIRoomKit. UserSigs stay on the CloudNews server. Meeting chat, images, and files stay on that server too.

## What it uses

| Piece | Source |
|---|---|
| Meeting room | `TRTCCloud.enterRoom` and `TRTCCloudVideoView` |
| Login / create / join | CloudNews API, then the plain TRTC room |
| UserSig | CloudNews server (`POST /meetings/instant` for the host, `POST /meetings/:code/join` for a guest) |
| Chat | CloudNews WebSocket and file upload |
| App screens | Welcome, Host login, Host dashboard, Pre-join lobby, Meeting room |

There is no React Native meeting UIKit. That is why this app is Flutter, not React Native.

## Build

Needs Flutter 3.29.3 or later (3.47.7 is installed at `E:\dev\flutter`).

```bash
cd cloud_news_app
flutter pub get
flutter pub run flutter_launcher_icons
flutter run
```

### Android APK (Windows)

```bash
flutter build apk --release
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`.

### iOS (Mac only)

This Windows machine cannot compile an IPA. Copy `cloud_news_app` to a Mac with Xcode 16+, CocoaPods, and Flutter 3.29.3 or later, then:

```bash
cd cloud_news_app
flutter pub get
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

In Xcode, select the **Runner** target → **Signing & Capabilities** → tick **Automatically manage signing** and choose your Apple Team. Bundle ID is `com.cloudnews.app`. Keep **Strip Style** as **Non-Global Symbols**.

Then either run from Xcode on a device, or:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

`ios/ExportOptions.plist` is set to a development IPA. For TestFlight / App Store, change `method` to `app-store-connect` after you have a distribution certificate.

Screen share is Android-only for now. iPhone screen share needs a Broadcast Upload Extension, which has to be added on a Mac.

## Server

The default API is `https://admin.cloudnewsmeet.com/api/v1`. Override it at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000/api/v1
```

The TRTC secret key never goes into this app.
