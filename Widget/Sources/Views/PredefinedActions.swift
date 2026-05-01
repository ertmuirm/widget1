import SwiftUI

// MARK: - Models

struct AppActionGroup: Identifiable {
    let category: String
    let name: String
    let openURL: String
    let deepLinks: [DeepLink]

    var id: String { name + category }

    /// The fallback URI scheme embedded in openURL (after "&fallback="), if any.
    var fallbackURL: String? {
        guard let range = openURL.range(of: "&fallback=") else { return nil }
        return String(openURL[range.upperBound...])
    }

    /// True when the row can be expanded (has deep links or a fallback URL).
    var hasExpansion: Bool { !deepLinks.isEmpty || fallbackURL != nil }
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
    AppActionGroup(category: "", name: "Alipay",             openURL: bundleIDURL("com.alipay.iphoneclient", fallback: "alipay://"), deepLinks: [
        DeepLink(name: "Scan QR Code",   urlString: "alipayqr://platformapi/startapp?saId=10000007"),
        DeepLink(name: "Payment QR",     urlString: "alipayqr://platformapi/startapp?appId=20000056"),
        DeepLink(name: "Transfer Money", urlString: "alipays://platformapi/startapp?appId=20000116"),
        DeepLink(name: "Phone Top-Up",   urlString: "alipayqr://platformapi/startapp?appId=10000003"),
    ]),
    AppActionGroup(category: "", name: "App Store",          openURL: bundleIDURL("com.apple.AppStore", fallback: "itms-apps://"), deepLinks: [
        DeepLink(name: "Today Tab",              urlString: "itms-apps://?action=today"),
        DeepLink(name: "Search",                 urlString: "itms-apps://?action=search&term="),
        DeepLink(name: "Updates",                urlString: "itms-apps://itunes.apple.com/updates"),
    ]),
    AppActionGroup(category: "", name: "Authy",              openURL: bundleIDURL("com.authy", fallback: "authy://"), deepLinks: []),
    AppActionGroup(category: "", name: "Bank of Singapore",  openURL: bundleIDURL("com.bankofsingapore.digital.iphone"), deepLinks: []),
    AppActionGroup(category: "", name: "Calculator",         openURL: bundleIDURL("com.apple.calculator"), deepLinks: []),
    AppActionGroup(category: "", name: "Chase",              openURL: bundleIDURL("com.chase", fallback: "chase://"), deepLinks: []),
    AppActionGroup(category: "", name: "ChatGPT",            openURL: bundleIDURL("com.openai.chat", fallback: "chatgpt://"), deepLinks: []),
    AppActionGroup(category: "", name: "Citibank",           openURL: bundleIDURL("com.citigroup.citimobile", fallback: "citi://"), deepLinks: []),
    AppActionGroup(category: "", name: "Claude",             openURL: bundleIDURL("com.anthropic.claudeios"), deepLinks: []),
    AppActionGroup(category: "", name: "Contacts",           openURL: bundleIDURL("com.apple.MobileAddressBook", fallback: "contacts://"), deepLinks: []),
    AppActionGroup(category: "", name: "Copilot",            openURL: bundleIDURL("com.microsoft.copilot", fallback: "ms-officemobile://"), deepLinks: []),
    AppActionGroup(category: "", name: "DBS digibank",       openURL: bundleIDURL("com.dbs.sg.dbsmbanking", fallback: "dbsnow://"), deepLinks: []),
    AppActionGroup(category: "", name: "Discord",            openURL: bundleIDURL("com.hammerandchisel.discord", fallback: "discord://"), deepLinks: []),
    AppActionGroup(category: "", name: "Doubao 豆包",         openURL: bundleIDURL("com.bot.doubao", fallback: "doubao://"), deepLinks: []),
    AppActionGroup(category: "", name: "Dropbox",            openURL: bundleIDURL("com.getdropbox.Dropbox", fallback: "dbinbox://"), deepLinks: []),
    AppActionGroup(category: "", name: "Duolingo",           openURL: bundleIDURL("com.duolingo.DuolingoMobile", fallback: "duolingo://"), deepLinks: []),
    AppActionGroup(category: "", name: "Facebook",           openURL: bundleIDURL("com.facebook.Facebook", fallback: "fb://"), deepLinks: [
        DeepLink(name: "Events",                 urlString: "fb://events"),
        DeepLink(name: "Notifications",          urlString: "fb://notifications"),
        DeepLink(name: "Marketplace",            urlString: "fb://marketplace"),
    ]),
    AppActionGroup(category: "", name: "FaceTime",           openURL: bundleIDURL("com.apple.facetime", fallback: "facetime://"), deepLinks: []),
    AppActionGroup(category: "", name: "Files",              openURL: bundleIDURL("com.apple.DocumentsApp", fallback: "shareddocuments://"), deepLinks: []),
    AppActionGroup(category: "", name: "Gemini",             openURL: bundleIDURL("com.google.gemini", fallback: "googleapp://robin"), deepLinks: [
        DeepLink(name: "Open Microphone",        urlString: "googlegeminiai://open-mic"),
    ]),
    AppActionGroup(category: "", name: "Google Calendar",    openURL: bundleIDURL("com.google.calendar", fallback: "googlecalendar://"), deepLinks: []),
    AppActionGroup(category: "", name: "Google Drive",       openURL: bundleIDURL("com.google.Drive", fallback: "googledrive://"), deepLinks: [
        DeepLink(name: "New Document",           urlString: "https://docs.new"),
        DeepLink(name: "New Spreadsheet",        urlString: "https://sheets.new"),
        DeepLink(name: "New Presentation",       urlString: "https://slides.new"),
    ]),
    AppActionGroup(category: "", name: "Google Home",        openURL: bundleIDURL("com.google.Chromecast", fallback: "googlehome://"), deepLinks: []),
    AppActionGroup(category: "", name: "Google Maps",        openURL: bundleIDURL("com.google.Maps", fallback: "comgooglemaps://"), deepLinks: [
        DeepLink(name: "Search",                 urlString: "comgooglemaps://?q="),
        DeepLink(name: "Directions (Driving)",   urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=driving"),
        DeepLink(name: "Directions (Transit)",   urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=transit"),
        DeepLink(name: "Directions (Walking)",   urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=walking"),
        DeepLink(name: "Directions (Cycling)",   urlString: "comgooglemaps://?saddr=&daddr=&directionsmode=bicycling"),
    ]),
    AppActionGroup(category: "", name: "Google Meet",        openURL: bundleIDURL("com.google.Tachyon", fallback: "gmeet://"), deepLinks: [
        DeepLink(name: "New Meeting",            urlString: "https://meet.new"),
    ]),
    AppActionGroup(category: "", name: "Google Photos",      openURL: bundleIDURL("com.google.photos", fallback: "googlephotos://"), deepLinks: []),
    AppActionGroup(category: "", name: "Google Translate",   openURL: bundleIDURL("com.google.Translate", fallback: "googletranslate://"), deepLinks: [
        DeepLink(name: "Translate to English",   urlString: "googletranslate://?sl=auto&tl=en&text="),
        DeepLink(name: "Translate to Chinese",   urlString: "googletranslate://?sl=auto&tl=zh&text="),
        DeepLink(name: "Translate to Spanish",   urlString: "googletranslate://?sl=auto&tl=es&text="),
        DeepLink(name: "Translate to French",    urlString: "googletranslate://?sl=auto&tl=fr&text="),
        DeepLink(name: "Translate to Japanese",  urlString: "googletranslate://?sl=auto&tl=ja&text="),
    ]),
    AppActionGroup(category: "", name: "Google Voice",       openURL: bundleIDURL("com.google.GVDialer", fallback: "googlevoice://"), deepLinks: []),
    AppActionGroup(category: "", name: "Grab",               openURL: bundleIDURL("com.grabtaxi.iphone", fallback: "grab://"), deepLinks: []),
    AppActionGroup(category: "", name: "Granola",            openURL: bundleIDURL("com.granola.ios-prod"), deepLinks: []),
    AppActionGroup(category: "", name: "Grok",               openURL: bundleIDURL("ai.x.GrokApp", fallback: "grok://"), deepLinks: []),
    AppActionGroup(category: "", name: "HDFlix",             openURL: bundleIDURL("com.box.hd.flix.drama.hub"), deepLinks: []),
    AppActionGroup(category: "", name: "HeyCyan",            openURL: bundleIDURL("com.heycyan.app"), deepLinks: []),
    AppActionGroup(category: "", name: "Hilton Honors",      openURL: bundleIDURL("com.hilton.hhonors", fallback: "hiltonhhonors://"), deepLinks: []),
    AppActionGroup(category: "", name: "iCondo",             openURL: bundleIDURL("com.project.icondo"), deepLinks: []),
    AppActionGroup(category: "", name: "Instagram",          openURL: bundleIDURL("com.burbn.instagram", fallback: "instagram://"), deepLinks: [
        DeepLink(name: "Camera",                 urlString: "instagram://camera"),
        DeepLink(name: "Direct Messages",        urlString: "instagram://direct-inbox"),
    ]),
    AppActionGroup(category: "", name: "iSH Shell",          openURL: bundleIDURL("app.ish.iSH"), deepLinks: []),
    AppActionGroup(category: "", name: "Lark",               openURL: bundleIDURL("com.larksuite.lark", fallback: "https://applink.larksuite.com/"), deepLinks: []),
    AppActionGroup(category: "", name: "Libby",              openURL: bundleIDURL("com.overdrive.dewey", fallback: "dewey-oauth://"), deepLinks: []),
    AppActionGroup(category: "", name: "Line",               openURL: bundleIDURL("jp.naver.line", fallback: "line://"), deepLinks: [
        DeepLink(name: "New Message",            urlString: "line://msg/"),
        DeepLink(name: "QR Code Reader",         urlString: "line://nv/qrCodeReader"),
    ]),
    AppActionGroup(category: "", name: "LinkedIn",           openURL: bundleIDURL("com.linkedin.LinkedIn", fallback: "linkedin://"), deepLinks: [
        DeepLink(name: "My Profile",             urlString: "linkedin://profile"),
        DeepLink(name: "Messaging",              urlString: "linkedin://messaging"),
        DeepLink(name: "Notifications",          urlString: "linkedin://notifications"),
    ]),
    AppActionGroup(category: "", name: "M1 (My M1+)",        openURL: bundleIDURL("sg.com.m1.sunshine"), deepLinks: []),
    AppActionGroup(category: "", name: "Maribank",           openURL: bundleIDURL("sg.com.maribankmobile.digitalbank"), deepLinks: []),
    AppActionGroup(category: "", name: "Marriott Bonvoy",    openURL: bundleIDURL("com.marriott.iphoneprod", fallback: "marriott://"), deepLinks: []),
    AppActionGroup(category: "", name: "McDonald's",         openURL: bundleIDURL("com.mcdonalds.gma", fallback: "mcdonalds://"), deepLinks: []),
    AppActionGroup(category: "", name: "Messages",           openURL: bundleIDURL("com.apple.MobileSMS"), deepLinks: [
        DeepLink(name: "New Message",            urlString: "sms:"),
        DeepLink(name: "Message to Number",      urlString: "sms:+"),
    ]),
    AppActionGroup(category: "", name: "Microsoft Excel",    openURL: bundleIDURL("com.microsoft.Office.Excel", fallback: "ms-excel://"), deepLinks: [
        DeepLink(name: "New Workbook",           urlString: "ms-excel://"),
    ]),
    AppActionGroup(category: "", name: "Microsoft Outlook",  openURL: bundleIDURL("com.microsoft.Office.Outlook", fallback: "ms-outlook://"), deepLinks: [
        DeepLink(name: "New Email",              urlString: "ms-outlook://compose"),
    ]),
    AppActionGroup(category: "", name: "Microsoft Teams",    openURL: bundleIDURL("com.microsoft.skype.teams", fallback: "msteams://"), deepLinks: [
        DeepLink(name: "New Meeting",            urlString: "https://teams.microsoft.com/l/meeting/new"),
        DeepLink(name: "New Chat",               urlString: "https://teams.microsoft.com/l/chat/0/0?users="),
        DeepLink(name: "Audio Call",             urlString: "https://teams.microsoft.com/l/call/0/0?users="),
        DeepLink(name: "Video Call",             urlString: "https://teams.microsoft.com/l/call/0/0?users=&withVideo=true"),
    ]),
    AppActionGroup(category: "", name: "Microsoft Word",     openURL: bundleIDURL("com.microsoft.Office.Word", fallback: "ms-word://"), deepLinks: [
        DeepLink(name: "New Document",           urlString: "ms-word://"),
    ]),
    AppActionGroup(category: "", name: "MiHome",             openURL: bundleIDURL("com.xiaomi.mihome", fallback: "mihome://"), deepLinks: []),
    AppActionGroup(category: "", name: "Netflix",            openURL: bundleIDURL("com.netflix.Netflix", fallback: "nflx://"), deepLinks: []),
    AppActionGroup(category: "", name: "OneDrive",           openURL: bundleIDURL("com.microsoft.skydrive", fallback: "ms-onedrive://"), deepLinks: [
        DeepLink(name: "My Files",               urlString: "ms-onedrive://files"),
        DeepLink(name: "Recent Files",           urlString: "ms-onedrive://recent"),
        DeepLink(name: "Shared with Me",         urlString: "ms-onedrive://shared"),
    ]),
    AppActionGroup(category: "", name: "Phone",              openURL: bundleIDURL("com.apple.mobilephone", fallback: "mobilephone-keypad://"), deepLinks: [
        DeepLink(name: "Recents",                urlString: "mobilephone-recents://"),
        DeepLink(name: "Voicemail",              urlString: "mobilephone-voicemail://"),
    ]),
    AppActionGroup(category: "", name: "Photos",             openURL: bundleIDURL("com.apple.mobileslideshow", fallback: "photos-redirect://"), deepLinks: []),
    AppActionGroup(category: "", name: "Reddit",             openURL: bundleIDURL("com.reddit.Reddit", fallback: "reddit://"), deepLinks: [
        DeepLink(name: "Search",                 urlString: "reddit://search?q="),
    ]),
    AppActionGroup(category: "", name: "S&P Capital IQ",     openURL: bundleIDURL("com.capitaliq.mobile.MarketIntelligence"), deepLinks: []),
    AppActionGroup(category: "", name: "Safemate",           openURL: bundleIDURL("com.yaoertai.safemate2"), deepLinks: []),
    AppActionGroup(category: "", name: "SAP Concur",         openURL: bundleIDURL("com.concur.concurmobile", fallback: "concurmobile://"), deepLinks: [
        DeepLink(name: "Deep Link",              urlString: "concurmobiledeeplink://"),
        DeepLink(name: "Expense Report",         urlString: "https://www.concursolutions.com/goto/expense-report/"),
    ]),
    AppActionGroup(category: "", name: "Shopee",             openURL: bundleIDURL("com.shopee.sg", fallback: "shopeesg://"), deepLinks: []),
    AppActionGroup(category: "", name: "Shortcuts",          openURL: bundleIDURL("com.apple.shortcuts", fallback: "shortcuts://"), deepLinks: [
        DeepLink(name: "Run Shortcut",           urlString: "shortcuts://run-shortcut?name="),
        DeepLink(name: "Run with Clipboard",     urlString: "shortcuts://run-shortcut?name=&input=clipboard"),
        DeepLink(name: "Open Shortcut",          urlString: "shortcuts://open-shortcut?name="),
        DeepLink(name: "Create Shortcut",        urlString: "shortcuts://create-shortcut"),
        DeepLink(name: "Open Gallery",           urlString: "shortcuts://gallery"),
    ]),
    AppActionGroup(category: "", name: "Singapore Airlines", openURL: bundleIDURL("com.amadeus.sqmobile", fallback: "https://www.singaporeair.com/"), deepLinks: []),
    AppActionGroup(category: "", name: "Singpass",           openURL: bundleIDURL("sg.ndi.sp", fallback: "singpass://"), deepLinks: [
        DeepLink(name: "Open (web fallback)",    urlString: "https://app.singpass.gov.sg"),
    ]),
    AppActionGroup(category: "", name: "Snapchat",           openURL: bundleIDURL("com.toyopagroup.picaboo", fallback: "snapchat://"), deepLinks: []),
    AppActionGroup(category: "", name: "Spotify",            openURL: bundleIDURL("com.spotify.client", fallback: "spotify:"), deepLinks: [
        DeepLink(name: "Search",                 urlString: "spotify:search:"),
        DeepLink(name: "Open Artist",            urlString: "spotify:artist:"),
        DeepLink(name: "Open Album",             urlString: "spotify:album:"),
        DeepLink(name: "Open Playlist",          urlString: "spotify:playlist:"),
        DeepLink(name: "Open Track",             urlString: "spotify:track:"),
        DeepLink(name: "Open Show",              urlString: "spotify:show:"),
    ]),
    AppActionGroup(category: "", name: "Stocks",             openURL: bundleIDURL("com.apple.stocks"), deepLinks: []),
    AppActionGroup(category: "", name: "Taobao 淘宝",         openURL: bundleIDURL("com.taobao.taobao4iphone", fallback: "taobao://"), deepLinks: [
        DeepLink(name: "Search Products",        urlString: "taobao://s.taobao.com?q="),
        DeepLink(name: "Search Shops",           urlString: "taobao://shopsearch.taobao.com/browse/shop_search.htm?q="),
    ]),
    AppActionGroup(category: "", name: "Telegram",           openURL: bundleIDURL("ph.telegra.Telegraph", fallback: "tg://"), deepLinks: [
        DeepLink(name: "Settings",               urlString: "tg://settings"),
        DeepLink(name: "Privacy Settings",       urlString: "tg://settings/privacy"),
        DeepLink(name: "Open Username",          urlString: "tg://resolve?domain="),
        DeepLink(name: "Share a Link",           urlString: "tg://msg_url?url="),
        DeepLink(name: "Join via Invite",        urlString: "tg://join?invite="),
    ]),
    AppActionGroup(category: "", name: "TikTok",             openURL: bundleIDURL("com.zhiliaoapp.musically", fallback: "snssdk1233://"), deepLinks: []),
    AppActionGroup(category: "", name: "Trust Bank",         openURL: bundleIDURL("sg.com.trustbank.trustbankmobile"), deepLinks: []),
    AppActionGroup(category: "", name: "Uber",               openURL: bundleIDURL("com.ubercab.UberClient", fallback: "uber://"), deepLinks: [
        DeepLink(name: "Request Ride (from here)", urlString: "uber://?action=setPickup&pickup=my_location"),
        DeepLink(name: "Set Pickup & Dropoff",   urlString: "uber://?action=setPickup&pickup[latitude]=&pickup[longitude]=&dropoff[latitude]=&dropoff[longitude]="),
    ]),
    AppActionGroup(category: "", name: "Wallet",             openURL: bundleIDURL("com.apple.Passbook", fallback: "wallet://"), deepLinks: []),
    AppActionGroup(category: "", name: "WeChat",             openURL: bundleIDURL("com.tencent.xin", fallback: "weixin://"), deepLinks: [
        DeepLink(name: "Scan QR Code",           urlString: "weixin://scanqrcode"),
    ]),
    AppActionGroup(category: "", name: "WhatsApp",           openURL: bundleIDURL("net.whatsapp.WhatsApp", fallback: "whatsapp://"), deepLinks: [
        DeepLink(name: "New Message",            urlString: "whatsapp://send"),
        DeepLink(name: "Message with Text",      urlString: "whatsapp://send?text="),
        DeepLink(name: "Message to Number",      urlString: "whatsapp://send?phone="),
    ]),
    AppActionGroup(category: "", name: "Widgetsmith",        openURL: bundleIDURL("com.crossforward.WidgetSmith", fallback: "widgetsmith://"), deepLinks: []),
    AppActionGroup(category: "", name: "X (Twitter)",        openURL: bundleIDURL("com.atebits.Tweetie2", fallback: "twitter://"), deepLinks: [
        DeepLink(name: "Search",                 urlString: "twitter://search?query="),
        DeepLink(name: "Post",                   urlString: "twitter://post?message="),
    ]),
    AppActionGroup(category: "", name: "YouTube",            openURL: bundleIDURL("com.google.ios.youtube", fallback: "vnd.youtube://"), deepLinks: [
        DeepLink(name: "Open Video",             urlString: "vnd.youtube://"),
        DeepLink(name: "Search",                 urlString: "https://www.youtube.com/results?search_query="),
    ]),
    AppActionGroup(category: "", name: "YouTube Music",      openURL: bundleIDURL("com.google.ios.youtubemusic", fallback: "youtubemusic://"), deepLinks: []),
    AppActionGroup(category: "", name: "Zoom",               openURL: bundleIDURL("us.zoom.videomeetings", fallback: "zoomus://"), deepLinks: [
        DeepLink(name: "Join Meeting",           urlString: "zoomus://zoom.us/join?confno="),
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
    @Published var isWorkspaceAccessible = false
    @Published var hasSuccessfullyEnumerated = false
    @Published var installedBundleIDs: Set<String> = []
    @Published var installedURLSchemes: Set<String> = []

    private let predefinedBundleIDs: Set<String> = {
        var ids = Set<String>()
        for app in predefinedApps {
            let url = app.openURL
            if url.hasPrefix("openapp://launch?bundle=") {
                // URLComponents fails on fallback=xxx:// query values — use string range
                let suffix = String(url.dropFirst("openapp://launch?bundle=".count))
                if let id = suffix.components(separatedBy: "&").first, !id.isEmpty {
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
            let (apps, bundleIDs, urlSchemes, workspaceOK) = self.fetchUserApps()
            DispatchQueue.main.async {
                self.scannedApps = apps
                self.installedBundleIDs = bundleIDs
                self.installedURLSchemes = urlSchemes
                self.isWorkspaceAccessible = workspaceOK
                self.hasSuccessfullyEnumerated = !bundleIDs.isEmpty
                self.hasCompletedScan = workspaceOK
                self.isScanning = false
            }
        }
    }

    func isInstalled(_ app: AppActionGroup) -> Bool {
        let url = app.openURL

        if url.hasPrefix("openapp://launch?bundle=") {
            // URLComponents fails when fallback= contains ://, so extract with string range
            let suffix = String(url.dropFirst("openapp://launch?bundle=".count))
            let bundleID = suffix.components(separatedBy: "&").first ?? ""
            if !bundleID.isEmpty {
                if hasSuccessfullyEnumerated {
                    return installedBundleIDs.contains(bundleID)
                }
                // Bulk enumeration unavailable — fall back to per-app workspace check
                return InstalledAppsManager.workspaceIsInstalled(bundleID: bundleID)
            }
        }

        guard hasCompletedScan else { return true }
        if url.hasPrefix("http://") || url.hasPrefix("https://") { return true }
        if let scheme = URL(string: url)?.scheme { return installedURLSchemes.contains(scheme) }
        return true
    }

    static func workspaceIsInstalled(bundleID: String) -> Bool {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
        else { return false }
        let sel = NSSelectorFromString("applicationIsInstalled:")
        guard ws.responds(to: sel) else { return false }
        // BOOL methods return 0/1 as raw pointer — use != nil rather than casting
        return ws.perform(sel, with: bundleID) != nil
    }

    private func fetchUserApps() -> ([AppActionGroup], Set<String>, Set<String>, Bool) {
        guard
            let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
            let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
        else { return ([], [], [], false) }

        let allAppsSel = NSSelectorFromString("allApplications")
        guard ws.responds(to: allAppsSel),
              let raw = ws.perform(allAppsSel)?.takeUnretainedValue(),
              let nsArray = raw as? NSArray
        else {
            return ([], [], [], true)
        }

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
        return (sorted, bundleIDs, urlSchemes, true)
    }
}

// MARK: - Picker View

struct AppActionPickerView: View {
    let onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appsManager = InstalledAppsManager.shared
    @State private var searchText = ""

    /// Show ALL predefined apps; installed = white, not installed = gray.
    private var filteredPredefined: [AppActionGroup] {
        guard !searchText.isEmpty else { return predefinedApps }
        let q = searchText.lowercased()
        return predefinedApps.filter {
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
                        AppActionRow(
                            app: app,
                            isInstalled: appsManager.isInstalled(app)
                        ) { url, label in
                            onSelect(url, label)
                            dismiss()
                        }
                    }
                }

                if !filteredScanned.isEmpty {
                    Section {
                        ForEach(filteredScanned) { app in
                            AppActionRow(app: app, isInstalled: true) { url, label in
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
    var isInstalled: Bool = true
    let onSelect: (String, String) -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    onSelect(app.openURL, "\(app.name): Open")
                } label: {
                    Text(app.name)
                        .foregroundStyle(isInstalled ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if app.hasExpansion {
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
                    // Fallback URL scheme option (shown first when available)
                    if let fb = app.fallbackURL {
                        Button {
                            onSelect(fb, "\(app.name): URL Scheme")
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text("Use URL Scheme (\(fb))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if !app.deepLinks.isEmpty {
                            Divider().padding(.leading, 28)
                        }
                    }

                    // Deep links
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
