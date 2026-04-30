import SwiftUI

// MARK: - Model

struct PredefinedAction: Identifiable {
    let category: String
    let appName: String
    let actionName: String
    let urlString: String

    var id: String { "\(category)_\(appName)_\(actionName)" }
    var displayLabel: String { "\(appName): \(actionName)" }
}

// MARK: - Helpers

/// URL scheme launch — app must have a registered URL scheme.
private func scheme(_ url: String) -> String { url }

/// Bundle ID launch — uses LSApplicationWorkspace via onOpenURL in WidgetApp.
/// Works on SideStore-distributed builds; not App Store eligible.
func bundleIDURL(_ bundleID: String) -> String {
    "openapp://launch?bundle=\(bundleID)"
}

// MARK: - Curated list

let predefinedActionCategories: [(name: String, actions: [PredefinedAction])] = [
    ("AI Assistants", [
        PredefinedAction(category: "AI Assistants", appName: "Doubao 豆包",  actionName: "Open", urlString: scheme("doubao://")),
        PredefinedAction(category: "AI Assistants", appName: "Gemini",       actionName: "Open", urlString: scheme("googlegeminiai://")),
        PredefinedAction(category: "AI Assistants", appName: "Grok",         actionName: "Open", urlString: scheme("grok://")),
        PredefinedAction(category: "AI Assistants", appName: "Replika",      actionName: "Open", urlString: scheme("replika://")),
    ]),
    ("Communication", [
        PredefinedAction(category: "Communication", appName: "WeChat",          actionName: "Open",         urlString: scheme("weixin://")),
        PredefinedAction(category: "Communication", appName: "WeChat",          actionName: "Scan QR Code", urlString: scheme("weixin://scanqrcode")),
        PredefinedAction(category: "Communication", appName: "WhatsApp",        actionName: "Open",         urlString: scheme("whatsapp://")),
        PredefinedAction(category: "Communication", appName: "Telegram",        actionName: "Open",         urlString: scheme("tg://")),
        PredefinedAction(category: "Communication", appName: "Lark",            actionName: "Open",         urlString: scheme("https://applink.larksuite.com/")),
        PredefinedAction(category: "Communication", appName: "Microsoft Teams", actionName: "Open",         urlString: scheme("msteams://")),
        PredefinedAction(category: "Communication", appName: "Zoom",            actionName: "Open",         urlString: scheme("zoomus://")),
        PredefinedAction(category: "Communication", appName: "Google Voice",    actionName: "Open",         urlString: scheme("googlevoice://")),
        PredefinedAction(category: "Communication", appName: "Messages",        actionName: "Open",         urlString: scheme("sms:")),
    ]),
    ("Phone & Contacts", [
        PredefinedAction(category: "Phone & Contacts", appName: "Phone",    actionName: "Open Keypad",  urlString: scheme("mobilephone-keypad://")),
        PredefinedAction(category: "Phone & Contacts", appName: "Phone",    actionName: "Open Recents", urlString: scheme("mobilephone-recents://")),
        PredefinedAction(category: "Phone & Contacts", appName: "Contacts", actionName: "Open",         urlString: scheme("contacts://")),
    ]),
    ("Navigation & Transport", [
        PredefinedAction(category: "Navigation & Transport", appName: "Google Maps",        actionName: "Open",       urlString: scheme("comgooglemaps://")),
        PredefinedAction(category: "Navigation & Transport", appName: "Uber",               actionName: "Open",       urlString: scheme("uber://")),
        PredefinedAction(category: "Navigation & Transport", appName: "Grab",               actionName: "Open",       urlString: scheme("grab://")),
        PredefinedAction(category: "Navigation & Transport", appName: "Singapore Airlines", actionName: "Open",       urlString: scheme("singaporeair://")),
    ]),
    ("Music & Video", [
        PredefinedAction(category: "Music & Video", appName: "Spotify",  actionName: "Open",   urlString: scheme("spotify:")),
        PredefinedAction(category: "Music & Video", appName: "Spotify",  actionName: "Search", urlString: scheme("spotify:search:")),
        PredefinedAction(category: "Music & Video", appName: "YouTube",  actionName: "Open",   urlString: scheme("youtube://")),
    ]),
    ("Shopping & Food", [
        PredefinedAction(category: "Shopping & Food", appName: "Taobao 淘宝", actionName: "Open", urlString: scheme("taobao://")),
        PredefinedAction(category: "Shopping & Food", appName: "Shopee",      actionName: "Open", urlString: scheme("shopee://")),
        PredefinedAction(category: "Shopping & Food", appName: "McDonald's",  actionName: "Open", urlString: scheme("mcdonalds://")),
    ]),
    ("Banking & Finance", [
        PredefinedAction(category: "Banking & Finance", appName: "Chase",            actionName: "Open", urlString: scheme("chase://")),
        PredefinedAction(category: "Banking & Finance", appName: "Citibank",         actionName: "Open", urlString: scheme("citi://")),
        PredefinedAction(category: "Banking & Finance", appName: "DBS Bank",         actionName: "Open", urlString: scheme("dbsnow://")),
        PredefinedAction(category: "Banking & Finance", appName: "Alipay",           actionName: "Open", urlString: scheme("alipay://")),
        PredefinedAction(category: "Banking & Finance", appName: "Wallet",           actionName: "Open", urlString: scheme("wallet://")),
        PredefinedAction(category: "Banking & Finance", appName: "Bank of Singapore",actionName: "Open", urlString: bundleIDURL("com.bankofsingapore.digital.iphone")),
        PredefinedAction(category: "Banking & Finance", appName: "Maribank",         actionName: "Open", urlString: bundleIDURL("sg.com.maribankmobile.digitalbank")),
        PredefinedAction(category: "Banking & Finance", appName: "Trust Bank",       actionName: "Open", urlString: bundleIDURL("sg.trust")),
    ]),
    ("Business", [
        PredefinedAction(category: "Business", appName: "SAP Concur",     actionName: "Open",          urlString: scheme("concurmobile://")),
        PredefinedAction(category: "Business", appName: "SAP Concur",     actionName: "Deep Link",     urlString: scheme("concurmobiledeeplink://")),
        PredefinedAction(category: "Business", appName: "S&P Capital IQ", actionName: "Open",          urlString: bundleIDURL("com.capitaliq.mobile.MarketIntelligence")),
        PredefinedAction(category: "Business", appName: "OneDrive",       actionName: "Open",          urlString: scheme("ms-onedrive://")),
    ]),
    ("Travel & Hotels", [
        PredefinedAction(category: "Travel & Hotels", appName: "Singapore Airlines", actionName: "Open", urlString: scheme("singaporeair://")),
        PredefinedAction(category: "Travel & Hotels", appName: "Hilton Honors",      actionName: "Open", urlString: scheme("hiltonhhonors://")),
        PredefinedAction(category: "Travel & Hotels", appName: "Marriott Bonvoy",    actionName: "Open", urlString: scheme("marriott://")),
    ]),
    ("Productivity & Learning", [
        PredefinedAction(category: "Productivity & Learning", appName: "Google Translate", actionName: "Open", urlString: scheme("googletranslate://")),
        PredefinedAction(category: "Productivity & Learning", appName: "Duolingo",         actionName: "Open", urlString: scheme("duolingo://")),
        PredefinedAction(category: "Productivity & Learning", appName: "Libby",            actionName: "Open", urlString: scheme("libby://")),
        PredefinedAction(category: "Productivity & Learning", appName: "Shortcuts",        actionName: "Open", urlString: scheme("shortcuts://")),
        PredefinedAction(category: "Productivity & Learning", appName: "Granola",          actionName: "Open", urlString: bundleIDURL("com.granola.ios-prod")),
        PredefinedAction(category: "Productivity & Learning", appName: "iSH Shell",        actionName: "Open", urlString: bundleIDURL("app.ish.iSH")),
    ]),
    ("Smart Home", [
        PredefinedAction(category: "Smart Home", appName: "Google Home", actionName: "Open", urlString: scheme("googlehome://")),
        PredefinedAction(category: "Smart Home", appName: "MiHome",      actionName: "Open", urlString: scheme("mihome://")),
    ]),
    ("Apple System", [
        PredefinedAction(category: "Apple System", appName: "App Store",     actionName: "Open", urlString: scheme("itms-apps://")),
        PredefinedAction(category: "Apple System", appName: "Photos",        actionName: "Open", urlString: scheme("photos://")),
        PredefinedAction(category: "Apple System", appName: "Calculator",    actionName: "Open", urlString: scheme("calc://")),
        PredefinedAction(category: "Apple System", appName: "Files",         actionName: "Open", urlString: scheme("shareddocuments://")),
        PredefinedAction(category: "Apple System", appName: "Stocks",        actionName: "Open", urlString: scheme("stocks://")),
        PredefinedAction(category: "Apple System", appName: "Google Photos", actionName: "Open", urlString: scheme("googlephotos://")),
        PredefinedAction(category: "Apple System", appName: "Widgetsmith",   actionName: "Open", urlString: scheme("widgetsmith://")),
    ]),
    ("Government & Identity", [
        PredefinedAction(category: "Government & Identity", appName: "Singpass", actionName: "Open", urlString: scheme("https://app.singpass.gov.sg")),
    ]),
    ("Utilities", [
        PredefinedAction(category: "Utilities", appName: "HeyCyan",  actionName: "Open", urlString: bundleIDURL("com.heycyan.app")),
        PredefinedAction(category: "Utilities", appName: "iCondo",   actionName: "Open", urlString: bundleIDURL("com.project.icondo")),
        PredefinedAction(category: "Utilities", appName: "M1 (My M1+)", actionName: "Open", urlString: bundleIDURL("sg.com.m1.sunshine")),
        PredefinedAction(category: "Utilities", appName: "HDFlix",   actionName: "Open", urlString: bundleIDURL("com.box.hd.flix.drama.hub")),
    ]),
]

// MARK: - Picker View

struct AppActionPickerView: View {
    let onSelect: (PredefinedAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCategories: [(name: String, actions: [PredefinedAction])] {
        guard !searchText.isEmpty else { return predefinedActionCategories }
        let q = searchText.lowercased()
        return predefinedActionCategories.compactMap { cat in
            let filtered = cat.actions.filter {
                $0.appName.lowercased().contains(q) || $0.actionName.lowercased().contains(q)
            }
            return filtered.isEmpty ? nil : (cat.name, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories, id: \.name) { cat in
                    Section(cat.name) {
                        ForEach(cat.actions) { action in
                            Button {
                                onSelect(action)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.appName)
                                            .foregroundStyle(.white)
                                            .font(.body)
                                        Text(action.actionName)
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    // Show bundle-ID badge for apps launched via private API
                                    if action.urlString.hasPrefix("openapp://") {
                                        Text("bundle ID")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select App Action")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search apps or actions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("\"bundle ID\" entries launch via system API — may not work on all iOS versions.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
    }
}
