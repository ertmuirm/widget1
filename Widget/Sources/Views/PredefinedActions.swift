import SwiftUI

// MARK: - Models

struct AppActionGroup: Identifiable {
    let category: String
    let name: String
    let openURL: String
    let deepLinks: [DeepLink]

    var id: String { name + category }
    var hasDeepLinks: Bool { !deepLinks.isEmpty }
}

struct DeepLink: Identifiable {
    let name: String
    let urlString: String
    var id: String { urlString }
}

// MARK: - Helpers

func bundleIDURL(_ bundleID: String, fallback: String? = nil) -> String {
    var s = "openapp://launch?bundle=\(bundleID)"
    if let fb = fallback { s += "&fallback=\(fb)" }
    return s
}

// MARK: - Predefined list (flat, alphabetical)

let predefinedApps: [AppActionGroup] = [
    AppActionGroup(category: "", name: "Alipay",           openURL: "alipay://", deepLinks: [
        DeepLink(name: "Scan QR Code",   urlString: "alipayqr://platformapi/startapp?saId=10000007"),
        DeepLink(name: "Payment QR",     urlString: "alipayqr://platformapi/startapp?appId=20000056"),
        DeepLink(name: "Transfer Money", urlString: "alipays://platformapi/startapp?appId=20000116"),
        DeepLink(name: "Phone Top-Up",   urlString: "alipayqr://platformapi/startapp?appId=10000003"),
    ]),
    AppActionGroup(category: "", name: "App Store",        openURL: "itms-apps://", deepLinks: [
        DeepLink(name: "Today Tab", urlString: "itms-apps://?action=today"),
        DeepLink(name: "Search",    urlString: "itms-apps://?action=search&term="),
    ]),
    AppActionGroup(category: "", name: "Bank of Singapore", openURL: bundleIDURL("com.bankofsingapore.digital.iphone"), deepLinks: []),
    AppActionGroup(category: "", name: "Calculator",       openURL: bundleIDURL("com.apple.calculator"), deepLinks: []),
    AppActionGroup(category: "", name: "Chase",            openURL: "chase://", deepLinks: []),
    AppActionGroup(category: "", name: "ChatGPT",          openURL: "chatgpt://", deepLinks: []),
    AppActionGroup(category: "", name: "Citibank",         openURL: "citi://", deepLinks: []),
    AppActionGroup(category: "", name: "Claude",           openURL: bundleIDURL("com.anthropic.claudeios"), deepLinks: []),
    AppActionGroup(category: "", name: "Contacts",         openURL: bundleIDURL("com.apple.MobileAddressBook"), deepLinks: []),
    AppActionGroup(category: "", name: "Copilot",          openURL: "ms-officemobile://", deepLinks: []),
    AppActionGroup(category: "", name: "DBS digibank",     openURL: "dbsnow://", deepLinks: []),
    AppActionGroup(category: "", name: "Doubao 豆包",       openURL: "doubao://", deepLinks: []),
    AppActionGroup(category: "", name: "Duolingo",         openURL: "duolingo://", deepLinks: []),
    AppActionGroup(category: "", name: "Files",            openURL: "shareddocuments://", deepLinks: []),
    AppActionGroup(category: "", name: "Gemini",           openURL: "googleapp://robin", deepLinks: [
        DeepLink(name: "Open Microphone", urlString: "googlegeminiai://open-mic"),
    ]),
    AppActionGroup(category: "", name: "Google Home",      openURL: "googlehome://", deepLinks: []),
    AppActionGroup(category: "", name: "Google Maps",      openURL: "comgooglemaps://", deepLinks: [
        DeepLink(name: "Search",                urlString: "comgooglemaps://?q="),
        DeepLink(name: "Directions (Driving)",  urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=driving"),
        DeepLink(name: "Directions (Transit)",  urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=transit"),
        DeepLink(name: "Directions (Walking)",  urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=walking"),
        DeepLink(name: "Directions (Cycling)",  urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=bicycling"),
    ]),
    AppActionGroup(category: "", name: "Google Photos",    openURL: "googlephotos://", deepLinks: []),
    AppActionGroup(category: "", name: "Google Translate", openURL: "googletranslate://", deepLinks: [
        DeepLink(name: "Translate to English", urlString: "googletranslate://?sl=auto&tl=en&text="),
        DeepLink(name: "Translate to Chinese", urlString: "googletranslate://?sl=auto&tl=zh&text="),
        DeepLink(name: "Translate to Spanish", urlString: "googletranslate://?sl=auto&tl=es&text="),
        DeepLink(name: "Translate to French",  urlString: "googletranslate://?sl=auto&tl=fr&text="),
        DeepLink(name: "Translate to Japanese", urlString: "googletranslate://?sl=auto&tl=ja&text="),
    ]),
    AppActionGroup(category: "", name: "Google Voice",     openURL: "googlevoice://", deepLinks: []),
    AppActionGroup(category: "", name: "Grab",             openURL: "grab://", deepLinks: []),
    AppActionGroup(category: "", name: "Granola",          openURL: bundleIDURL("com.granola.ios-prod"), deepLinks: []),
    AppActionGroup(category: "", name: "Grok",             openURL: bundleIDURL("ai.x.GrokApp", fallback: "grok://"), deepLinks: []),
    AppActionGroup(category: "", name: "HDFlix",           openURL: bundleIDURL("com.box.hd.flix.drama.hub"), deepLinks: []),
    AppActionGroup(category: "", name: "HeyCyan",          openURL: bundleIDURL("com.heycyan.app"), deepLinks: []),
    AppActionGroup(category: "", name: "Hilton Honors",    openURL: "hiltonhhonors://", deepLinks: []),
    AppActionGroup(category: "", name: "iCondo",           openURL: bundleIDURL("com.project.icondo"), deepLinks: []),
    AppActionGroup(category: "", name: "iSH Shell",        openURL: bundleIDURL("app.ish.iSH"), deepLinks: []),
    AppActionGroup(category: "", name: "Lark",             openURL: "https://applink.larksuite.com/", deepLinks: []),
    AppActionGroup(category: "", name: "Libby",            openURL: bundleIDURL("com.overdrive.dewey", fallback: "libbyapp://"), deepLinks: []),
    AppActionGroup(category: "", name: "M1 (My M1+)",      openURL: bundleIDURL("sg.com.m1.sunshine"), deepLinks: []),
    AppActionGroup(category: "", name: "Maribank",         openURL: bundleIDURL("sg.com.maribankmobile.digitalbank"), deepLinks: []),
    AppActionGroup(category: "", name: "Marriott Bonvoy",  openURL: "marriott://", deepLinks: []),
    AppActionGroup(category: "", name: "McDonald's",       openURL: "mcdonalds://", deepLinks: []),
    AppActionGroup(category: "", name: "Messages",         openURL: bundleIDURL("com.apple.MobileSMS"), deepLinks: [
        DeepLink(name: "New Message",       urlString: "sms:"),
        DeepLink(name: "Message to Number", urlString: "sms:+"),
    ]),
    AppActionGroup(category: "", name: "Microsoft Teams",  openURL: "msteams://", deepLinks: [
        DeepLink(name: "New Meeting",  urlString: "https://teams.microsoft.com/l/meeting/new"),
        DeepLink(name: "New Chat",     urlString: "https://teams.microsoft.com/l/chat/0/0?users="),
        DeepLink(name: "Audio Call",   urlString: "https://teams.microsoft.com/l/call/0/0?users="),
        DeepLink(name: "Video Call",   urlString: "https://teams.microsoft.com/l/call/0/0?users=&withVideo=true"),
    ]),
    AppActionGroup(category: "", name: "MiHome",           openURL: "mihome://", deepLinks: []),
    AppActionGroup(category: "", name: "OneDrive",         openURL: "ms-onedrive://", deepLinks: [
        DeepLink(name: "My Files",       urlString: "ms-onedrive://files"),
        DeepLink(name: "Recent Files",   urlString: "ms-onedrive://recent"),
        DeepLink(name: "Shared with Me", urlString: "ms-onedrive://shared"),
    ]),
    AppActionGroup(category: "", name: "Phone",            openURL: "mobilephone-keypad://", deepLinks: [
        DeepLink(name: "Recents",   urlString: "mobilephone-recents://"),
        DeepLink(name: "Voicemail", urlString: "mobilephone-voicemail://"),
    ]),
    AppActionGroup(category: "", name: "Photos",           openURL: bundleIDURL("com.apple.mobileslideshow"), deepLinks: []),
    AppActionGroup(category: "", name: "S&P Capital IQ",   openURL: bundleIDURL("com.capitaliq.mobile.MarketIntelligence"), deepLinks: []),
    AppActionGroup(category: "", name: "Safemate",         openURL: bundleIDURL("com.safemate2.yet"), deepLinks: []),
    AppActionGroup(category: "", name: "SAP Concur",       openURL: "concurmobile://", deepLinks: [
        DeepLink(name: "Deep Link",      urlString: "concurmobiledeeplink://"),
        DeepLink(name: "Expense Report", urlString: "https://www.concursolutions.com/goto/expense-report/"),
    ]),
    AppActionGroup(category: "", name: "Shopee",           openURL: "shopee://", deepLinks: []),
    AppActionGroup(category: "", name: "Shortcuts",        openURL: "shortcuts://", deepLinks: [
        DeepLink(name: "Run Shortcut",       urlString: "shortcuts://run-shortcut?name="),
        DeepLink(name: "Run with Clipboard", urlString: "shortcuts://run-shortcut?name=&input=clipboard"),
        DeepLink(name: "Open Shortcut",      urlString: "shortcuts://open-shortcut?name="),
        DeepLink(name: "Create Shortcut",    urlString: "shortcuts://create-shortcut"),
        DeepLink(name: "Open Gallery",       urlString: "shortcuts://gallery"),
    ]),
    AppActionGroup(category: "", name: "Singapore Airlines", openURL: bundleIDURL("com.amadeus.sqmobile", fallback: "https://www.singaporeair.com/"), deepLinks: []),
    AppActionGroup(category: "", name: "Singpass",         openURL: "sg.gov.singpass.app://", deepLinks: [
        DeepLink(name: "Open (web fallback)", urlString: "https://app.singpass.gov.sg"),
    ]),
    AppActionGroup(category: "", name: "Spotify",          openURL: "spotify:", deepLinks: [
        DeepLink(name: "Search",        urlString: "spotify:search:"),
        DeepLink(name: "Open Artist",   urlString: "spotify:artist:"),
        DeepLink(name: "Open Album",    urlString: "spotify:album:"),
        DeepLink(name: "Open Playlist", urlString: "spotify:playlist:"),
        DeepLink(name: "Open Track",    urlString: "spotify:track:"),
        DeepLink(name: "Open Show",     urlString: "spotify:show:"),
    ]),
    AppActionGroup(category: "", name: "Stocks",           openURL: bundleIDURL("com.apple.stocks"), deepLinks: []),
    AppActionGroup(category: "", name: "Taobao 淘宝",       openURL: "taobao://", deepLinks: [
        DeepLink(name: "Search Products", urlString: "taobao://s.taobao.com?q="),
        DeepLink(name: "Search Shops",    urlString: "taobao://shopsearch.taobao.com/browse/shop_search.htm?q="),
    ]),
    AppActionGroup(category: "", name: "Telegram",         openURL: "tg://", deepLinks: [
        DeepLink(name: "Settings",         urlString: "tg://settings"),
        DeepLink(name: "Privacy Settings", urlString: "tg://settings/privacy"),
        DeepLink(name: "Open Username",    urlString: "tg://resolve?domain="),
        DeepLink(name: "Share a Link",     urlString: "tg://msg_url?url="),
        DeepLink(name: "Join via Invite",  urlString: "tg://join?invite="),
    ]),
    AppActionGroup(category: "", name: "Trust Bank",       openURL: bundleIDURL("sg.trust"), deepLinks: []),
    AppActionGroup(category: "", name: "Uber",             openURL: "uber://", deepLinks: [
        DeepLink(name: "Request Ride (from here)", urlString: "uber://?action=setPickup&pickup=my_location"),
        DeepLink(name: "Set Pickup & Dropoff",     urlString: "uber://?action=setPickup&pickup[latitude]=&pickup[longitude]=&dropoff[latitude]=&dropoff[longitude]="),
    ]),
    AppActionGroup(category: "", name: "Wallet",           openURL: "wallet://", deepLinks: []),
    AppActionGroup(category: "", name: "WeChat",           openURL: "weixin://", deepLinks: [
        DeepLink(name: "Scan QR Code", urlString: "weixin://scanqrcode"),
    ]),
    AppActionGroup(category: "", name: "WhatsApp",         openURL: "whatsapp://", deepLinks: [
        DeepLink(name: "New Message",       urlString: "whatsapp://send"),
        DeepLink(name: "Message with Text", urlString: "whatsapp://send?text="),
        DeepLink(name: "Message to Number", urlString: "whatsapp://send?phone="),
    ]),
    AppActionGroup(category: "", name: "Widgetsmith",      openURL: "widgetsmith://", deepLinks: []),
    AppActionGroup(category: "", name: "YouTube",          openURL: "vnd.youtube://", deepLinks: [
        DeepLink(name: "Open Video", urlString: "vnd.youtube://"),
        DeepLink(name: "Search",     urlString: "https://www.youtube.com/results?search_query="),
    ]),
    AppActionGroup(category: "", name: "Zoom",             openURL: "zoomus://", deepLinks: [
        DeepLink(name: "Join Meeting", urlString: "zoomus://zoom.us/join?confno="),
    ]),
]

// Keep legacy predefinedGroups alias for InstalledAppsManager.predefinedBundleIDs
let predefinedGroups: [(category: String, apps: [AppActionGroup])] = [
    ("", predefinedApps)
]

// MARK: - Installed Apps Manager

class InstalledAppsManager: ObservableObject {
    static let shared = InstalledAppsManager()

    @Published var scannedApps: [AppActionGroup] = []
    @Published var isScanning = false
    @Published var hasCompletedScan = false
    @Published var installedBundleIDs: Set<String> = []
    @Published var installedURLSchemes: Set<String> = []

    private let predefinedBundleIDs: Set<String> = {
        var ids = Set<String>()
        for app in predefinedApps {
            if app.openURL.hasPrefix("openapp://launch?bundle="),
               let comps = URLComponents(string: app.openURL),
               let id = comps.queryItems?.first(where: { $0.name == "bundle" })?.value {
                ids.insert(id)
            }
        }
        return ids
    }()

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let (apps, bundleIDs, urlSchemes) = self.fetchUserApps()
            DispatchQueue.main.async {
                self.scannedApps = apps
                self.installedBundleIDs = bundleIDs
                self.installedURLSchemes = urlSchemes
                self.hasCompletedScan = !bundleIDs.isEmpty
                self.isScanning = false
            }
        }
    }

    func isInstalled(_ app: AppActionGroup) -> Bool {
        guard hasCompletedScan else { return true }

        let url = app.openURL

        if url.hasPrefix("openapp://launch?bundle="),
           let comps = URLComponents(string: url),
           let bundleID = comps.queryItems?.first(where: { $0.name == "bundle" })?.value {
            return installedBundleIDs.contains(bundleID)
        }

        if url.hasPrefix("http://") || url.hasPrefix("https://") { return true }

        if let scheme = URL(string: url)?.scheme {
            return installedURLSchemes.contains(scheme)
        }
        return true
    }

    private func fetchUserApps() -> ([AppActionGroup], Set<String>, Set<String>) {
        guard
            let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
            let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
            let raw = ws.perform(NSSelectorFromString("allApplications"))?.takeUnretainedValue(),
            let nsArray = raw as? NSArray
        else { return ([], [], []) }

        var result: [AppActionGroup] = []
        var bundleIDs = Set<String>()
        var urlSchemes = Set<String>()

        for proxy in nsArray {
            let p = proxy as AnyObject
            guard let bundleID = p.value(forKey: "applicationIdentifier") as? String else { continue }

            bundleIDs.insert(bundleID)

            if let schemes = p.value(forKey: "registeredURLSchemes") as? [String] {
                for scheme in schemes { urlSchemes.insert(scheme.lowercased()) }
            }

            guard
                let name = p.value(forKey: "localizedName") as? String,
                (p.value(forKey: "applicationType") as? String) == "User",
                !name.isEmpty,
                !predefinedBundleIDs.contains(bundleID)
            else { continue }

            result.append(AppActionGroup(
                category: "All Installed Apps",
                name: name,
                openURL: bundleIDURL(bundleID),
                deepLinks: []
            ))
        }
        let sorted = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (sorted, bundleIDs, urlSchemes)
    }
}

// MARK: - Picker View

struct AppActionPickerView: View {
    let onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appsManager = InstalledAppsManager.shared
    @State private var searchText = ""

    private var filteredPredefined: [AppActionGroup] {
        let installed = predefinedApps.filter { appsManager.isInstalled($0) }
        guard !searchText.isEmpty else { return installed }
        let q = searchText.lowercased()
        return installed.filter {
            $0.name.lowercased().contains(q) ||
            $0.deepLinks.contains { $0.name.lowercased().contains(q) }
        }
    }

    private var filteredScanned: [AppActionGroup] {
        guard !searchText.isEmpty else { return appsManager.scannedApps }
        let q = searchText.lowercased()
        return appsManager.scannedApps.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredPredefined) { app in
                        AppActionRow(app: app) { url, label in
                            onSelect(url, label)
                            dismiss()
                        }
                    }
                }

                if !filteredScanned.isEmpty {
                    Section {
                        ForEach(filteredScanned) { app in
                            AppActionRow(app: app) { url, label in
                                onSelect(url, label)
                                dismiss()
                            }
                        }
                    } header: {
                        HStack {
                            Text("All Installed Apps")
                            if appsManager.isScanning {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                    }
                } else if appsManager.isScanning {
                    Section("All Installed Apps") {
                        HStack {
                            ProgressView()
                            Text("Scanning…").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select App Action")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search apps")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { appsManager.scan() }
    }
}

// MARK: - App Row

struct AppActionRow: View {
    let app: AppActionGroup
    let onSelect: (String, String) -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    onSelect(app.openURL, "\(app.name): Open")
                } label: {
                    Text(app.name)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if app.hasDeepLinks {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 22)

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(app.deepLinks) { link in
                        Button {
                            onSelect(link.urlString, "\(app.name): \(link.name)")
                        } label: {
                            HStack {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(link.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if link.id != app.deepLinks.last?.id {
                            Divider().padding(.leading, 28)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
