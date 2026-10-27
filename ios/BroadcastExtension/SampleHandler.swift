import ReplayKit
import TXLiteAVSDK_ReplayKitExt

/// Empty skips the App Group. The main app passes the same empty value to
/// DeviceStore.startScreenShare(iOSAppGroup:). Sharing can start, with less
/// stable cross-process delivery than a configured App Group.
let APPGROUP = ""

class SampleHandler: RPBroadcastSampleHandler, TXReplayKitExtDelegate {
  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    TXReplayKitExt.sharedInstance().setup(withAppGroup: APPGROUP, delegate: self)
  }

  override func broadcastPaused() {
    TXReplayKitExt.sharedInstance().broadcastPaused()
  }

  override func broadcastResumed() {
    TXReplayKitExt.sharedInstance().broadcastResumed()
  }

  override func broadcastFinished() {
    TXReplayKitExt.sharedInstance().broadcastFinished()
  }

  func broadcastFinished(_ broadcast: TXReplayKitExt, reason: TXReplayKitExtReason) {
    var tip = "Screen sharing ended"
    switch reason {
    case .requestedByMain:
      tip = "Screen sharing has ended"
    case .disconnected:
      tip = "App disconnected"
    case .versionMismatch:
      tip = "SDK version mismatch"
    @unknown default:
      break
    }
    let error = NSError(
      domain: NSStringFromClass(Self.self),
      code: 0,
      userInfo: [NSLocalizedFailureReasonErrorKey: tip]
    )
    finishBroadcastWithError(error)
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
    switch sampleBufferType {
    case .video, .audioApp:
      TXReplayKitExt.sharedInstance().send(sampleBuffer, with: sampleBufferType)
    case .audioMic:
      break
    @unknown default:
      break
    }
  }
}
