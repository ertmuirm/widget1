import SwiftUI
import Intents

@main
struct WidgetApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { @MainActor in
                        // Brief yield so the black ContentView renders before handing off
                        try? await Task.sleep(for: .milliseconds(30))
                        if url.scheme == "openapp" {
                            if let bundleID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                .queryItems?.first(where: { $0.name == "bundle" })?.value {
                                openAppByBundleID(bundleID)
                            }
                        } else if url.scheme == "tel" {
                            dialPhoneNumber(url: url)
                        } else {
                            await UIApplication.shared.open(url)
                        }
                    }
                }
                // Handles INStartCallIntent handed back to app (continueInApp response)
                .onContinueUserActivity(NSStringFromClass(INStartCallIntent.self)) { activity in
                    guard let intent = activity.interaction?.intent as? INStartCallIntent,
                          let contact = intent.contacts?.first,
                          let handle = contact.personHandle else { return }
                    let number = handle.value
                    CallKitManager.shared.dial(phoneNumber: number) { success in
                        guard !success, let url = URL(string: "tel:\(number)") else { return }
                        UIApplication.shared.open(url)
                    }
                }
                .onAppear {
                    InstalledAppsManager.shared.scan()
                }
        }
    }
}

// MARK: - Phone dialling

private func dialPhoneNumber(url: URL) {
    let raw = url.absoluteString
    let number = raw.hasPrefix("tel:") ? String(raw.dropFirst(4)) : raw

    // Primary: INStartCallIntent (same mechanism as iOS Shortcuts — no confirmation dialog)
    if dialViaINStartCallIntent(phoneNumber: number) { return }

    // Fallback: CallKit CXStartCallAction (native call UI, no dialog)
    CallKitManager.shared.dial(phoneNumber: number) { success in
        guard !success else { return }
        // Last resort: tel: URL (may show system confirmation dialog)
        UIApplication.shared.open(url)
    }
}

/// Invokes INStartCallIntent through our registered Intents Extension.
/// Returns true if the intent was dispatched (extension will handle it via CallKit).
@discardableResult
private func dialViaINStartCallIntent(phoneNumber: String) -> Bool {
    let handle = INPersonHandle(value: phoneNumber, type: .phoneNumber)
    let person = INPerson(
        personHandle: handle,
        nameComponents: nil,
        displayName: nil,
        image: nil,
        contactIdentifier: nil,
        customIdentifier: nil
    )
    let intent = INStartCallIntent(
        callCapability: .audioCall,
        contactIdentifier: nil,
        selectedContacts: [person],
        callRecordFilter: nil,
        unsatisfiedReason: nil
    )

    // Donate so Siri / system can learn this calling pattern
    INInteraction(intent: intent, response: nil).donate(completion: nil)

    // Hand off to our IntentsExtension via user activity (routes through system intent pipeline)
    guard let activity = NSUserActivity(intent: intent) else { return false }
    activity.becomeCurrent()
    return true
}

// MARK: - Bundle-ID app launch via LSApplicationWorkspace (private API)

private func openAppByBundleID(_ bundleID: String) {
    guard
        let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
        let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
    else { return }
    ws.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
}
