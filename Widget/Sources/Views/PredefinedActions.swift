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

// MARK: - Curated list

let predefinedActionCategories: [(name: String, actions: [PredefinedAction])] = [
    ("AI Assistants", [
        PredefinedAction(category: "AI Assistants", appName: "Doubao 豆包",      actionName: "Open", urlString: "doubao://"),
        PredefinedAction(category: "AI Assistants", appName: "Gemini",           actionName: "Open", urlString: "googlegeminiai://"),
        PredefinedAction(category: "AI Assistants", appName: "Grok",             actionName: "Open", urlString: "grok://"),
        PredefinedAction(category: "AI Assistants", appName: "Replika",          actionName: "Open", urlString: "replika://"),
    ]),
    ("Communication", [
        PredefinedAction(category: "Communication", appName: "WeChat",           actionName: "Open",          urlString: "weixin://"),
        PredefinedAction(category: "Communication", appName: "WeChat",           actionName: "Scan QR Code",  urlString: "weixin://scanqrcode"),
        PredefinedAction(category: "Communication", appName: "WhatsApp",         actionName: "Open",          urlString: "whatsapp://"),
        PredefinedAction(category: "Communication", appName: "Telegram",         actionName: "Open",          urlString: "tg://"),
        PredefinedAction(category: "Communication", appName: "Lark",             actionName: "Open",          urlString: "https://applink.larksuite.com/"),
        PredefinedAction(category: "Communication", appName: "Microsoft Teams",  actionName: "Open",          urlString: "msteams://"),
        PredefinedAction(category: "Communication", appName: "Zoom",             actionName: "Open",          urlString: "zoomus://"),
        PredefinedAction(category: "Communication", appName: "Google Voice",     actionName: "Open",          urlString: "googlevoice://"),
        PredefinedAction(category: "Communication", appName: "Messages",         actionName: "Open",          urlString: "sms:"),
    ]),
    ("Phone & Contacts", [
        PredefinedAction(category: "Phone & Contacts", appName: "Phone",     actionName: "Open Keypad",  urlString: "mobilephone-keypad://"),
        PredefinedAction(category: "Phone & Contacts", appName: "Phone",     actionName: "Open Recents", urlString: "mobilephone-recents://"),
        PredefinedAction(category: "Phone & Contacts", appName: "Contacts",  actionName: "Open",         urlString: "contacts://"),
    ]),
    ("Navigation & Transport", [
        PredefinedAction(category: "Navigation & Transport", appName: "Google Maps",        actionName: "Open",       urlString: "comgooglemaps://"),
        PredefinedAction(category: "Navigation & Transport", appName: "Uber",               actionName: "Open",       urlString: "uber://"),
        PredefinedAction(category: "Navigation & Transport", appName: "Grab",               actionName: "Open",       urlString: "grab://"),
        PredefinedAction(category: "Navigation & Transport", appName: "Singapore Airlines", actionName: "Open",       urlString: "singaporeair://"),
    ]),
    ("Music & Video", [
        PredefinedAction(category: "Music & Video", appName: "Spotify",  actionName: "Open",   urlString: "spotify:"),
        PredefinedAction(category: "Music & Video", appName: "Spotify",  actionName: "Search", urlString: "spotify:search:"),
        PredefinedAction(category: "Music & Video", appName: "YouTube",  actionName: "Open",   urlString: "youtube://"),
    ]),
    ("Shopping & Food", [
        PredefinedAction(category: "Shopping & Food", appName: "Taobao 淘宝",  actionName: "Open", urlString: "taobao://"),
        PredefinedAction(category: "Shopping & Food", appName: "Shopee",       actionName: "Open", urlString: "shopee://"),
        PredefinedAction(category: "Shopping & Food", appName: "McDonald's",   actionName: "Open", urlString: "mcdonalds://"),
    ]),
    ("Banking & Finance", [
        PredefinedAction(category: "Banking & Finance", appName: "Chase",    actionName: "Open", urlString: "chase://"),
        PredefinedAction(category: "Banking & Finance", appName: "Citibank", actionName: "Open", urlString: "citi://"),
        PredefinedAction(category: "Banking & Finance", appName: "DBS Bank", actionName: "Open", urlString: "dbsnow://"),
        PredefinedAction(category: "Banking & Finance", appName: "Alipay",   actionName: "Open", urlString: "alipay://"),
        PredefinedAction(category: "Banking & Finance", appName: "Wallet",   actionName: "Open", urlString: "wallet://"),
    ]),
    ("Travel & Hotels", [
        PredefinedAction(category: "Travel & Hotels", appName: "Singapore Airlines", actionName: "Open", urlString: "singaporeair://"),
        PredefinedAction(category: "Travel & Hotels", appName: "Hilton Honors",      actionName: "Open", urlString: "hiltonhhonors://"),
        PredefinedAction(category: "Travel & Hotels", appName: "Marriott Bonvoy",    actionName: "Open", urlString: "marriott://"),
    ]),
    ("Productivity & Learning", [
        PredefinedAction(category: "Productivity & Learning", appName: "OneDrive",         actionName: "Open", urlString: "ms-onedrive://"),
        PredefinedAction(category: "Productivity & Learning", appName: "Google Translate",  actionName: "Open", urlString: "googletranslate://"),
        PredefinedAction(category: "Productivity & Learning", appName: "Duolingo",          actionName: "Open", urlString: "duolingo://"),
        PredefinedAction(category: "Productivity & Learning", appName: "Libby",             actionName: "Open", urlString: "libby://"),
        PredefinedAction(category: "Productivity & Learning", appName: "Shortcuts",         actionName: "Open", urlString: "shortcuts://"),
        PredefinedAction(category: "Productivity & Learning", appName: "Granola",           actionName: "Open", urlString: "granola://"),
    ]),
    ("Smart Home", [
        PredefinedAction(category: "Smart Home", appName: "Google Home", actionName: "Open", urlString: "googlehome://"),
        PredefinedAction(category: "Smart Home", appName: "MiHome",      actionName: "Open", urlString: "mihome://"),
    ]),
    ("Apple System", [
        PredefinedAction(category: "Apple System", appName: "App Store",     actionName: "Open",          urlString: "itms-apps://"),
        PredefinedAction(category: "Apple System", appName: "Photos",        actionName: "Open",          urlString: "photos://"),
        PredefinedAction(category: "Apple System", appName: "Calculator",    actionName: "Open",          urlString: "calc://"),
        PredefinedAction(category: "Apple System", appName: "Files",         actionName: "Open",          urlString: "shareddocuments://"),
        PredefinedAction(category: "Apple System", appName: "Stocks",        actionName: "Open",          urlString: "stocks://"),
        PredefinedAction(category: "Apple System", appName: "Google Photos", actionName: "Open",          urlString: "googlephotos://"),
        PredefinedAction(category: "Apple System", appName: "Widgetsmith",   actionName: "Open",          urlString: "widgetsmith://"),
    ]),
    ("Government & Identity", [
        PredefinedAction(category: "Government & Identity", appName: "Singpass", actionName: "Open", urlString: "https://app.singpass.gov.sg"),
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.appName)
                                        .foregroundStyle(.white)
                                        .font(.body)
                                    Text(action.actionName)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
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
        }
        .preferredColorScheme(.dark)
    }
}
