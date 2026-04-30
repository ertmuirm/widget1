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

func bundleIDURL(_ bundleID: String) -> String {
    "openapp://launch?bundle=\(bundleID)"
}

// MARK: - Predefined list

let predefinedGroups: [(category: String, apps: [AppActionGroup])] = [
    ("AI Assistants", [
        AppActionGroup(category: "AI Assistants", name: "Doubao 豆包", openURL: "doubao://",          deepLinks: []),
        AppActionGroup(category: "AI Assistants", name: "Gemini",      openURL: "googlegeminiai://", deepLinks: []),
        AppActionGroup(category: "AI Assistants", name: "Grok",        openURL: "grok://",           deepLinks: []),
        AppActionGroup(category: "AI Assistants", name: "Replika",     openURL: "replika://",        deepLinks: []),
    ]),
    ("Communication", [
        AppActionGroup(category: "Communication", name: "WeChat",          openURL: "weixin://",                        deepLinks: [
            DeepLink(name: "Scan QR Code", urlString: "weixin://scanqrcode"),
        ]),
        AppActionGroup(category: "Communication", name: "WhatsApp",        openURL: "whatsapp://",                      deepLinks: []),
        AppActionGroup(category: "Communication", name: "Telegram",        openURL: "tg://",                            deepLinks: []),
        AppActionGroup(category: "Communication", name: "Lark",            openURL: "https://applink.larksuite.com/",   deepLinks: []),
        AppActionGroup(category: "Communication", name: "Microsoft Teams", openURL: "msteams://",                       deepLinks: []),
        AppActionGroup(category: "Communication", name: "Zoom",            openURL: "zoomus://",                        deepLinks: []),
        AppActionGroup(category: "Communication", name: "Google Voice",    openURL: "googlevoice://",                   deepLinks: []),
        AppActionGroup(category: "Communication", name: "Messages",        openURL: "sms:",                             deepLinks: []),
    ]),
    ("Phone & Contacts", [
        AppActionGroup(category: "Phone & Contacts", name: "Phone",    openURL: "mobilephone-keypad://", deepLinks: [
            DeepLink(name: "Recents", urlString: "mobilephone-recents://"),
        ]),
        AppActionGroup(category: "Phone & Contacts", name: "Contacts", openURL: "contacts://", deepLinks: []),
    ]),
    ("Navigation & Transport", [
        AppActionGroup(category: "Navigation & Transport", name: "Google Maps",        openURL: "comgooglemaps://",   deepLinks: [
            DeepLink(name: "Search",     urlString: "comgooglemaps://?q="),
            DeepLink(name: "Directions", urlString: "comgooglemaps://?saddr=&daddr="),
        ]),
        AppActionGroup(category: "Navigation & Transport", name: "Uber",               openURL: "uber://",            deepLinks: [
            DeepLink(name: "Request Ride", urlString: "uber://riderequest"),
        ]),
        AppActionGroup(category: "Navigation & Transport", name: "Grab",               openURL: "grab://",            deepLinks: []),
        AppActionGroup(category: "Navigation & Transport", name: "Singapore Airlines", openURL: "singaporeair://",    deepLinks: []),
    ]),
    ("Music & Video", [
        AppActionGroup(category: "Music & Video", name: "Spotify", openURL: "spotify:", deepLinks: [
            DeepLink(name: "Search", urlString: "spotify:search:"),
        ]),
        AppActionGroup(category: "Music & Video", name: "YouTube", openURL: "youtube://", deepLinks: []),
    ]),
    ("Shopping & Food", [
        AppActionGroup(category: "Shopping & Food", name: "Taobao 淘宝", openURL: "taobao://",    deepLinks: [
            DeepLink(name: "Search", urlString: "taobao://s.taobao.com?q="),
        ]),
        AppActionGroup(category: "Shopping & Food", name: "Shopee",      openURL: "shopee://",    deepLinks: []),
        AppActionGroup(category: "Shopping & Food", name: "McDonald's",  openURL: "mcdonalds://", deepLinks: []),
    ]),
    ("Banking & Finance", [
        AppActionGroup(category: "Banking & Finance", name: "Chase",            openURL: "chase://",                                                   deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "Citibank",         openURL: "citi://",                                                    deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "DBS Bank",         openURL: "dbsnow://",                                                  deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "Alipay",           openURL: "alipay://",                                                  deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "Wallet",           openURL: "wallet://",                                                  deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "Bank of Singapore",openURL: bundleIDURL("com.bankofsingapore.digital.iphone"),             deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "Maribank",         openURL: bundleIDURL("sg.com.maribankmobile.digitalbank"),              deepLinks: []),
        AppActionGroup(category: "Banking & Finance", name: "Trust Bank",       openURL: bundleIDURL("sg.trust"),                                      deepLinks: []),
    ]),
    ("Business", [
        AppActionGroup(category: "Business", name: "SAP Concur",     openURL: "concurmobile://",                                      deepLinks: [
            DeepLink(name: "Deep Link", urlString: "concurmobiledeeplink://"),
        ]),
        AppActionGroup(category: "Business", name: "S&P Capital IQ", openURL: bundleIDURL("com.capitaliq.mobile.MarketIntelligence"), deepLinks: []),
        AppActionGroup(category: "Business", name: "OneDrive",        openURL: "ms-onedrive://",                                      deepLinks: []),
    ]),
    ("Travel & Hotels", [
        AppActionGroup(category: "Travel & Hotels", name: "Singapore Airlines", openURL: "singaporeair://",    deepLinks: []),
        AppActionGroup(category: "Travel & Hotels", name: "Hilton Honors",      openURL: "hiltonhhonors://",   deepLinks: []),
        AppActionGroup(category: "Travel & Hotels", name: "Marriott Bonvoy",    openURL: "marriott://",        deepLinks: []),
    ]),
    ("Productivity & Learning", [
        AppActionGroup(category: "Productivity & Learning", name: "Google Translate", openURL: "googletranslate://", deepLinks: []),
        AppActionGroup(category: "Productivity & Learning", name: "Duolingo",         openURL: "duolingo://",        deepLinks: []),
        AppActionGroup(category: "Productivity & Learning", name: "Libby",            openURL: "libby://",           deepLinks: []),
        AppActionGroup(category: "Productivity & Learning", name: "Shortcuts",        openURL: "shortcuts://",       deepLinks: [
            DeepLink(name: "Run Shortcut", urlString: "shortcuts://run-shortcut?name="),
            DeepLink(name: "Open Gallery", urlString: "shortcuts://gallery"),
        ]),
        AppActionGroup(category: "Productivity & Learning", name: "Granola",   openURL: bundleIDURL("com.granola.ios-prod"), deepLinks: []),
        AppActionGroup(category: "Productivity & Learning", name: "iSH Shell", openURL: bundleIDURL("app.ish.iSH"),          deepLinks: []),
    ]),
    ("Smart Home", [
        AppActionGroup(category: "Smart Home", name: "Google Home", openURL: "googlehome://", deepLinks: []),
        AppActionGroup(category: "Smart Home", name: "MiHome",      openURL: "mihome://",     deepLinks: []),
    ]),
    ("Apple System", [
        AppActionGroup(category: "Apple System", name: "App Store",     openURL: "itms-apps://",      deepLinks: [
            DeepLink(name: "Today Tab", urlString: "itms-apps://?action=today"),
            DeepLink(name: "Search",    urlString: "itms-apps://?action=search&term="),
        ]),
        AppActionGroup(category: "Apple System", name: "Photos",        openURL: "photos://",         deepLinks: []),
        AppActionGroup(category: "Apple System", name: "Calculator",    openURL: "calc://",           deepLinks: []),
        AppActionGroup(category: "Apple System", name: "Files",         openURL: "shareddocuments://",deepLinks: []),
        AppActionGroup(category: "Apple System", name: "Stocks",        openURL: "stocks://",         deepLinks: []),
        AppActionGroup(category: "Apple System", name: "Google Photos", openURL: "googlephotos://",   deepLinks: []),
        AppActionGroup(category: "Apple System", name: "Widgetsmith",   openURL: "widgetsmith://",    deepLinks: []),
    ]),
    ("Government & Identity", [
        AppActionGroup(category: "Government & Identity", name: "Singpass", openURL: "https://app.singpass.gov.sg", deepLinks: []),
    ]),
    ("Utilities", [
        AppActionGroup(category: "Utilities", name: "Safemate",    openURL: bundleIDURL("com.safemate2.yet"),                  deepLinks: []),
        AppActionGroup(category: "Utilities", name: "HeyCyan",     openURL: bundleIDURL("com.heycyan.app"),                    deepLinks: []),
        AppActionGroup(category: "Utilities", name: "iCondo",      openURL: bundleIDURL("com.project.icondo"),                 deepLinks: []),
        AppActionGroup(category: "Utilities", name: "M1 (My M1+)", openURL: bundleIDURL("sg.com.m1.sunshine"),                 deepLinks: []),
        AppActionGroup(category: "Utilities", name: "HDFlix",      openURL: bundleIDURL("com.box.hd.flix.drama.hub"),          deepLinks: []),
    ]),
]

// MARK: - Installed Apps Manager

class InstalledAppsManager: ObservableObject {
    static let shared = InstalledAppsManager()

    @Published var scannedApps: [AppActionGroup] = []
    @Published var isScanning = false

    private let predefinedBundleIDs: Set<String> = {
        var ids = Set<String>()
        for (_, apps) in predefinedGroups {
            for app in apps {
                if app.openURL.hasPrefix("openapp://launch?bundle="),
                   let comps = URLComponents(string: app.openURL),
                   let id = comps.queryItems?.first(where: { $0.name == "bundle" })?.value {
                    ids.insert(id)
                }
            }
        }
        return ids
    }()

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = self.fetchUserApps()
            DispatchQueue.main.async {
                self.scannedApps = apps
                self.isScanning = false
            }
        }
    }

    private func fetchUserApps() -> [AppActionGroup] {
        guard
            let cls = NSClassFromString("LSApplicationWorkspace"),
            let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue(),
            let raw = (ws as AnyObject).perform(NSSelectorFromString("allApplications"))?.takeUnretainedValue(),
            let nsArray = raw as? NSArray
        else { return [] }

        var result: [AppActionGroup] = []
        for proxy in nsArray {
            let p = proxy as AnyObject
            guard
                let bundleID = p.value(forKey: "applicationIdentifier") as? String,
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
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Picker View

struct AppActionPickerView: View {
    let onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appsManager = InstalledAppsManager.shared
    @State private var searchText = ""

    private var filteredPredefined: [(category: String, apps: [AppActionGroup])] {
        guard !searchText.isEmpty else { return predefinedGroups }
        let q = searchText.lowercased()
        return predefinedGroups.compactMap { cat in
            let filtered = cat.apps.filter {
                $0.name.lowercased().contains(q) ||
                $0.deepLinks.contains { $0.name.lowercased().contains(q) }
            }
            return filtered.isEmpty ? nil : (cat.category, filtered)
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
                ForEach(filteredPredefined, id: \.category) { cat in
                    Section(cat.category) {
                        ForEach(cat.apps) { app in
                            AppActionRow(app: app) { url, label in
                                onSelect(url, label)
                                dismiss()
                            }
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
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

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
                            .padding(.vertical, 7)
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
