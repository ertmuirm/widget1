import CallKit
import UIKit
import AVFoundation

/// Registers the app as a CallKit VoIP calling provider.
///
/// For VoIP calls (audio routed through the internet) this allows calls to
/// complete without a confirmation dialog and appear in the native call UI.
/// For cellular calls (tel: scheme), iOS enforces a system confirmation
/// dialog in the telephony kernel regardless of CallKit registration — this
/// is a deliberate iOS security measure that cannot be bypassed by any
/// third-party app, including Shortcuts.
final class CallKitManager: NSObject {

    static let shared = CallKitManager()

    private let callController = CXCallController()
    private let provider: CXProvider

    private override init() {
        let config = CXProviderConfiguration(localizedName: "Widget")
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.phoneNumber]
        config.includesCallsInRecents = true
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
    }

    /// Attempts to start a call via CallKit.
    /// - Returns: true if CallKit accepted the request (no dialog shown), false
    ///   if it rejected it (caller should fall back to opening the tel: URL).
    func dial(phoneNumber: String, completion: @escaping (Bool) -> Void) {
        let handle = CXHandle(type: .phoneNumber, value: phoneNumber)
        let action = CXStartCallAction(call: UUID(), handle: handle)
        action.isVideo = false
        callController.request(CXTransaction(action: action)) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {}

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        // For a phoneNumber handle the system routes through the cellular carrier.
        // Only report startedConnecting; let the system/carrier report connectedAt.
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Configure audio session for the call if needed
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}
