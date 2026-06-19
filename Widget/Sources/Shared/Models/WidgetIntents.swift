import AppIntents
import WidgetKit

// MARK: - Widget Item Action Intent
//
// When widget items have .appIntent actions, we use Button(intent:) to trigger them.
// This ensures iOS calls getTimeline() after the intent completes, refreshing the widget.

struct WidgetItemActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Widget Item Action"
    static var description = IntentDescription("Triggers widget item action and refreshes widget")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Encoded Action")
    var encodedAction: String  // Base64 encoded WidgetAction
    
    init() {}
    init(encodedAction: String) { self.encodedAction = encodedAction }
    
    func perform() async throws -> some IntentResult {
        // Store the action in shared UserDefaults so the main app can:
        // 1. Execute the action
        // 2. Call WidgetCenter.shared.reloadAllTimelines()
        let pendingKey = "pendingWidgetAction"
        UserDefaults.standard.set(encodedAction, forKey: pendingKey)
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(encodedAction, forKey: pendingKey)
        }
        
        // Intent completion triggers iOS to call getTimeline()
        return .result()
    }
}

// MARK: - Entity ID encoding
//
// Entity IDs use the format "<uuid>|<base64-slim-json>". The config is encoded with
// short single-char keys and nil-for-default values so that even a fully-populated
// 36-item large-widget config fits well under WidgetKit's undocumented entity-ID size
// limit (~2 KB). This embedded config is the only reliable cross-process channel on
// SideStore/AltStore where app-group entitlements and keychain sharing may be stripped.

// MARK: - Color packing

private func packColor(_ c: CodableColor) -> Int {
    let r = Int((max(0.0, min(1.0, c.red))   * 255).rounded())
    let g = Int((max(0.0, min(1.0, c.green)) * 255).rounded())
    let b = Int((max(0.0, min(1.0, c.blue))  * 255).rounded())
    let a = Int((max(0.0, min(1.0, c.alpha)) * 255).rounded())
    return (r << 24) | (g << 16) | (b << 8) | a
}

private func unpackColor(_ v: Int) -> CodableColor {
    CodableColor(
        red:   Double((v >> 24) & 0xFF) / 255,
        green: Double((v >> 16) & 0xFF) / 255,
        blue:  Double((v >> 8)  & 0xFF) / 255,
        alpha: Double(v & 0xFF) / 255
    )
}

// Default packed values used to omit fields that equal the WidgetItem/WidgetConfig init defaults
private let kSlimWhite: Int = (255 << 24) | (255 << 16) | (255 << 8) | 255  // CodableColor.white
private let kSlimClear: Int = 0                                                // CodableColor.clear
private let kSlimBlack: Int = 255                                              // CodableColor.black (config bg)

// MARK: - Slim Codable structs

struct SlimAction: Codable {
    var t: String    // ActionType.rawValue
    var p: String    // payload
    var n: String?   // displayName
}

struct SlimItem: Codable {
    var d: String      // DisplayType.rawValue
    var s: String?     // sfSymbolName        (nil = none)
    var t: String?     // customText           (nil = none)
    var fc: Int?       // packed foregroundColor (nil = white default)
    var bc: Int?       // packed backgroundColor (nil = clear/0 default)
    var bo: Double?    // backgroundOpacity    (nil = 1.0 default)
    var z: Double?     // fontSize             (nil = 10.0 default)
    var qc: String?    // qrCodeContent        (nil = none)
    var ql: String?    // qrCodeLabel          (nil = none)
    var qs: Double?    // qrCodeLabelSize      (nil = 8.0 default)
    var a: SlimAction? // action               (nil = none)
}

private extension SlimItem {
    init(_ item: WidgetItem) {
        d  = item.displayType.rawValue
        s  = item.sfSymbolName
        t  = item.customText
        let fg = packColor(item.foregroundColor)
        fc = fg == kSlimWhite ? nil : fg
        let bg = packColor(item.backgroundColor)
        bc = bg == kSlimClear ? nil : bg
        bo = item.backgroundOpacity == 1.0 ? nil : item.backgroundOpacity
        z  = Double(item.fontSize) == 10.0 ? nil : Double(item.fontSize)
        qc = item.qrCodeContent
        ql = item.qrCodeLabel
        qs = Double(item.qrCodeLabelSize) == 8.0 ? nil : Double(item.qrCodeLabelSize)
        a  = item.action.map { SlimAction(t: $0.type.rawValue, p: $0.payload, n: $0.displayName) }
    }
    func toWidgetItem() -> WidgetItem {
        WidgetItem(
            id: UUID(),  // Create new ID - order is preserved by array position
            displayType: DisplayType(rawValue: d) ?? .icon,
            sfSymbolName: s,
            customText: t,
            qrCodeContent: qc,
            qrCodeLabel: ql,
            qrCodeLabelSize: CGFloat(qs ?? 8.0),
            fontSize: CGFloat(z ?? 10.0),
            foregroundColor: unpackColor(fc ?? kSlimWhite),
            backgroundColor: unpackColor(bc ?? kSlimClear),
            backgroundOpacity: bo ?? 1.0,
            action: a.map { WidgetAction(type: ActionType(rawValue: $0.t) ?? .urlScheme,
                                         payload: $0.p, displayName: $0.n) }
        )
    }
}

struct SlimSlide: Codable {
    var fn: String?    // filename             (nil = QR/barcode slide)
    var qc: String?    // qrCodeContent
    var ql: String?    // qrCodeLabel
    var qs: Double?    // qrCodeLabelSize      (nil = 8.0 default)
    var ba: String?    // barcodeContent
    var a: SlimAction? // action
}

struct SlimConfig: Codable {
    var i: String      // id.uuidString
    var n: String      // name
    var sz: String     // WidgetSize.rawValue
    var k: String?     // WidgetKind.rawValue  (nil = .grid / nil)
    var bc: Int?       // packed backgroundColor (nil = black default)
    var bo: Double?    // backgroundOpacity    (nil = 1.0 default)
    var sil: Bool?     // showItemLabels
    var it: [SlimItem] // items
    var sl: [SlimSlide]? // slides             (nil = no slides)
    var ci: Int?       // currentSlideIndex
    // Clock-specific fields
    var cdp: String?    // clockDigitPosition.rawValue
    var cfn: String?    // clockFontName
    var cfsz: Double?   // clockFontSize
    var ca: [SlimItem]? // clockActions (first = tens digit, second = units digit)
}

private extension SlimConfig {
    init(_ config: WidgetConfig) {
        i   = config.id.uuidString
        n   = config.name
        sz  = config.size.rawValue
        k   = config.widgetKind?.rawValue
        let bgc = packColor(config.backgroundColor)
        bc  = bgc == kSlimBlack ? nil : bgc
        bo  = config.backgroundOpacity == 1.0 ? nil : config.backgroundOpacity
        sil = config.showItemLabels
        it  = config.items.map { SlimItem($0) }
        sl  = config.slides.map { slides in
            slides.map { ss in
                SlimSlide(
                    fn: ss.filename.isEmpty ? nil : ss.filename,
                    qc: ss.qrCodeContent,
                    ql: ss.qrCodeLabel,
                    qs: Double(ss.qrCodeLabelSize) == 8.0 ? nil : Double(ss.qrCodeLabelSize),
                    ba: ss.barcodeContent,
                    a:  ss.action.map { SlimAction(t: $0.type.rawValue, p: $0.payload, n: $0.displayName) }
                )
            }
        }
        ci   = config.currentSlideIndex
        cdp  = config.clockDigitPosition?.rawValue
        cfn  = config.clockFontName
        cfsz = config.clockFontSize
        ca   = config.clockActions.map { $0.map { SlimItem($0) } }
    }
    func toWidgetConfig() -> WidgetConfig {
        let slides: [ImageSlide]? = sl.map { slimSlides in
            slimSlides.map { ss in
                ImageSlide(
                    id: UUID(),
                    filename: ss.fn ?? "",
                    action: ss.a.map { WidgetAction(type: ActionType(rawValue: $0.t) ?? .urlScheme,
                                                    payload: $0.p, displayName: $0.n) },
                    qrCodeContent: ss.qc,
                    qrCodeLabel: ss.ql,
                    qrCodeLabelSize: CGFloat(ss.qs ?? 8.0),
                    barcodeContent: ss.ba
                )
            }
        }
        return WidgetConfig(
            id: UUID(uuidString: i) ?? UUID(),
            name: n,
            size: WidgetSize(rawValue: sz) ?? .systemSmall,
            items: it.map { $0.toWidgetItem() },
            backgroundColor: unpackColor(bc ?? kSlimBlack),
            backgroundOpacity: bo ?? 1.0,
            showItemLabels: sil,
            widgetKind: k.flatMap { WidgetKind(rawValue: $0) },
            slides: slides,
            currentSlideIndex: ci,
            clockDigitPosition: cdp.flatMap { ClockDigitPosition(rawValue: $0) },
            clockFontName: cfn,
            clockFontSize: cfsz,
            clockActions: ca?.map { $0.toWidgetItem() }
        )
    }
}

// MARK: - Encode / decode helpers

func encodeEntityID(_ config: WidgetConfig) -> String {
    guard let data = try? JSONEncoder().encode(SlimConfig(config)) else {
        return config.id.uuidString
    }
    return "\(config.id.uuidString)|\(data.base64EncodedString())"
}

private func uuidFromEntityID(_ entityID: String) -> String {
    String(entityID.split(separator: "|", maxSplits: 1).first ?? Substring(entityID))
}

func decodeConfigFromID(_ entityID: String) -> WidgetConfig? {
    let parts = entityID.split(separator: "|", maxSplits: 1)
    guard parts.count == 2 else { return nil }
    
    // Extract UUID to check for FRESH entity data
    let uuid = String(parts[0])
    let freshEntityKey = "FRESH_ENTITY_ID_\(uuid)"
    
    // Check App Group CONTAINER FILES for FRESH entity ID (written by swap action)
    // Using file instead of UserDefaults because sideloaded apps may not share UserDefaults
    for appGroupID in SharedStorage.appGroupCandidates {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = container.appendingPathComponent("\(freshEntityKey).txt")
            if let freshEntityID = try? String(contentsOf: fileURL, encoding: .utf8) {
                // Found fresh entity - decode it!
                let freshParts = freshEntityID.split(separator: "|", maxSplits: 1)
                if freshParts.count == 2, let freshData = Data(base64Encoded: String(freshParts[1])) {
                    if let slim = try? JSONDecoder().decode(SlimConfig.self, from: freshData) {
                        return slim.toWidgetConfig()
                    }
                    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
                    return try? dec.decode(WidgetConfig.self, from: freshData)
                }
            }
        }
    }
    
    // Fall back to decoding the provided entity ID
    guard let data = Data(base64Encoded: String(parts[1])) else { return nil }
    // Try compact slim format first (current), then legacy full WidgetConfig JSON.
    if let slim = try? JSONDecoder().decode(SlimConfig.self, from: data) {
        return slim.toWidgetConfig()
    }
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    return try? dec.decode(WidgetConfig.self, from: data)
}

// MARK: - URL resolution (shared between makeEntry diagnostics and WidgetEntryView)

/// Resolves a tap URL from a `WidgetAction`. Returns nil for empty/whitespace payloads.
func resolveURL(for action: WidgetAction) -> URL? {
    let raw = action.payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    switch action.type {
    case .urlScheme:
        return URL(string: raw)
            ?? URL(string: raw.addingPercentEncoding(
                withAllowedCharacters: .urlFragmentAllowed) ?? raw)
    case .appIntent:
        if raw.contains("://") {
            // Already a full URL — editor stores openapp://launch?bundle=<id> via bundleIDURL()
            return URL(string: raw)
                ?? URL(string: raw.addingPercentEncoding(
                    withAllowedCharacters: .urlFragmentAllowed) ?? raw)
        } else {
            // Bare bundle ID from shortcut import — wrap in openapp:// for the Widget app to handle
            guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            else { return nil }
            return URL(string: "openapp://launch?bundle=\(encoded)")
        }
    case .shortcut:
        guard let encoded = raw.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "shortcuts://run-shortcut?name=\(encoded)")
    }
}

/// Resolves the tap URL for a widget item. Returns nil when no action is configured.
func resolveItemURL(_ item: WidgetItem) -> URL? {
    guard let action = item.action else { return nil }
    return resolveURL(for: action)
}

// MARK: - Shared helpers

private func filteredConfigs(size: WidgetSize) -> [WidgetConfig] {
    ((try? SharedStorage.shared.loadConfigurations()) ?? [])
        .filter { $0.size == size && $0.widgetKind != .imageSlideshow && $0.widgetKind != .lockScreen && $0.widgetKind != .clock }
}

private func filteredConfigs(kind: WidgetKind) -> [WidgetConfig] {
    ((try? SharedStorage.shared.loadConfigurations()) ?? [])
        .filter { $0.widgetKind == kind }
}

private func allConfigs() -> [WidgetConfig] {
    (try? SharedStorage.shared.loadConfigurations()) ?? []
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
    let showItemLabels: Bool
    /// The UUID extracted from the entity ID, which may differ from configuration.id
    /// when makeEntry() fell back to .defaultConfiguration (random UUID). Buttons in
    /// WidgetEntryView must use this UUID — not configuration.id — when constructing
    /// AdvanceImageIntent so the intent can match the correct slideIdx_ key.
    let entityUUID: String
    /// Debug: timestamp when this entry was created (HH:mm:ss format)
    let debugRefreshTime: String
    /// Debug: entity UUID (last 8 chars) for comparison with SwapIntent
    let debugEntityUUID: String
    /// Debug: info about order override key lookup
    let debugOrderInfo: String
    /// Debug: whether order override was found
    let debugOrderFound: Bool
    /// Debug: which storage location is active (kc:xxx or App Group ID)
    let debugStorageName: String
    /// Debug: number of configs found in storage
    let debugConfigCount: Int
    /// Debug: info about fresh config from refresh button
    let debugFreshConfigInfo: String

    init(date: Date, configuration: WidgetConfig,
         showItemLabels: Bool = SharedStorage.shared.showItemLabels,
         entityUUID: String = "",
         debugOrderInfo: String = "---",
         debugOrderFound: Bool = false,
         debugStorageName: String = "---",
         debugConfigCount: Int = -1,
         debugFreshConfigInfo: String = "---") {
        self.date = date
        self.configuration = configuration
        self.showItemLabels = showItemLabels
        self.entityUUID = entityUUID.isEmpty ? configuration.id.uuidString : entityUUID
        // Format: HH:mm:ss for easy reading
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        self.debugRefreshTime = formatter.string(from: date)
        self.debugEntityUUID = String(self.entityUUID.suffix(8))
        self.debugOrderInfo = debugOrderInfo
        self.debugOrderFound = debugOrderFound
        self.debugStorageName = debugStorageName
        self.debugConfigCount = debugConfigCount
        self.debugFreshConfigInfo = debugFreshConfigInfo
    }
}

// MARK: - Shared provider logic

private var timelineDebugNote: String = ""

private func makeEntry(configID: String?) -> WidgetEntry {
    return makeEntryInternal(configID: configID, debugNote: nil)
}

private func makeEntryInternal(configID: String?, debugNote: String?) -> WidgetEntry {
    let storage = SharedStorage.shared
    
    // Debug note from timeline
    let note = debugNote ?? timelineDebugNote
    
    // Load configs - this is what reselection uses (via suggestedEntities -> entities -> loadConfigurations)
    let liveConfigs = (try? storage.loadConfigurations()) ?? []
    
    // Direct check of gatherRead for debugging
    let directRead = storage.gatherReadDebug(forKey: SharedStorage.configKey)

    // Load config - widget reselection just calls SharedStorage which should have fresh data
    // BUT: For sideloaded apps, SharedStorage may not be shared. So we check multiple sources:
    // 1. LATEST_ENCODED_CONFIG - written by SwapWidgetItemsIntent to UserDefaults.standard
    // 2. ENCODED_CONFIG_<configID> - specific encoded config
    // 3. App Group - might work for some configs
    // 4. liveConfigs from SharedStorage
    // 5. decodeConfigFromID() from stored entity ID
    var config: WidgetConfig
    
    // Check for latest encoded config (written by swap intent)
    var latestEncoded: String? = nil
    for id in SharedStorage.appGroupCandidates {
        if let s = UserDefaults(suiteName: id)?.string(forKey: "LATEST_ENCODED_CONFIG"), !s.isEmpty {
            latestEncoded = s; break
        }
    }
    if latestEncoded == nil {
        latestEncoded = UserDefaults.standard.string(forKey: "LATEST_ENCODED_CONFIG")
    }
    // Also check App Group container file
    if latestEncoded == nil {
        for id in SharedStorage.appGroupCandidates {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("latest_encoded_config.txt")
                if let s = try? String(contentsOf: url, encoding: .utf8), !s.isEmpty {
                    latestEncoded = s; break
                }
            }
        }
    }
    // Check shared Documents folder (written by SwapWidgetItemsIntent)
    if latestEncoded == nil {
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent("latest_entity_id.txt")
            if let s = try? String(contentsOf: url, encoding: .utf8), !s.isEmpty {
                latestEncoded = s
                storage.appendExtensionLog("makeEntry: latestEncoded=FROM_DOCS len=\(latestEncoded!.count)")
            }
        }
    }
    storage.appendExtensionLog("makeEntry: latestEncoded=\(latestEncoded != nil ? "FOUND(\(latestEncoded!.count)chars)" : "nil")")
    
    // Check for specific encoded config
    var specificEncoded: String? = nil
    if let cid = configID {
        specificEncoded = UserDefaults.standard.string(forKey: "ENCODED_CONFIG_\(cid)")
        if specificEncoded == nil {
            for id in SharedStorage.appGroupCandidates {
                if let s = UserDefaults(suiteName: id)?.string(forKey: "ENCODED_CONFIG_\(cid)"), !s.isEmpty {
                    specificEncoded = s; break
                }
            }
        }
    }
    
    // DEBUG: Show how widget reselection gets data
    // Widget reselection decodes the entity ID to get config data
    var decodeDebug: String
    if let id = configID {
        let hasPipe = id.contains("|")
        let uuidPart = uuidFromEntityID(id)
        let canDecode = decodeConfigFromID(id) != nil
        decodeDebug = "id.len=\(id.count)|pipe=\(hasPipe)|uuid=\(uuidPart.prefix(8))|decode=\(canDecode)"
        
        // Try to decode and show what we get
        if let decoded = decodeConfigFromID(id) {
            decodeDebug += "|items=\(decoded.items.count)|name=\(decoded.name.prefix(10))"
        } else {
            // Try to decode the base64 part separately
            let parts = id.split(separator: "|", maxSplits: 1)
            if parts.count == 2 {
                let b64 = String(parts[1])
                let validB64 = Data(base64Encoded: b64) != nil
                decodeDebug += "|b64.valid=\(validB64)"
            } else {
                decodeDebug += "|no.b64.part"
            }
        }
    } else {
        decodeDebug = "configID=nil"
    }
    storage.appendExtensionLog("RESELECTION_DEBUG: \(decodeDebug)")
    
    if let id = configID, id != "none" {
        let uuid = uuidFromEntityID(id)
        
        // DEBUG: Log all data sources
        storage.appendExtensionLog("DATA_SOURCES: latestEnc=\(latestEncoded != nil)|specificEnc=\(specificEncoded != nil)|liveConfigs=\(liveConfigs.count)|id.len=\(id.count)")
        
        // DEBUG: Show first few UUIDs in liveConfigs and the target uuid
        let configUUIDs = liveConfigs.prefix(3).map { $0.id.uuidString.prefix(8) }.joined(separator: ",")
        storage.appendExtensionLog("DEBUG: liveConfigs UUIDs[0-2]=\(configUUIDs)")
        storage.appendExtensionLog("DEBUG: target uuid=\(uuid.prefix(8)) comparing...")
        
        // 1. FIRST: Check live configs from SharedStorage (THIS HAS FRESH DATA!)
        // Widget reselection loads configs via loadConfigurations() which is accessible!
        if let found = liveConfigs.first(where: { $0.id.uuidString.uppercased() == uuid.uppercased() }) {
            config = found
            storage.appendExtensionLog("makeEntry: USING liveConfigs[FRESCOK] items=\(config.items.count)")
        }
        // 2. Then check LATEST_ENCODED_CONFIG
        else if let encoded = latestEncoded, let decoded = decodeConfigFromID(encoded) {
            config = decoded
            storage.appendExtensionLog("makeEntry: using LATEST_ENCODED_CONFIG")
        }
        // 3. Then check ENCODED_CONFIG_<configID>
        else if let encoded = specificEncoded, let decoded = decodeConfigFromID(encoded) {
            config = decoded
            storage.appendExtensionLog("makeEntry: using ENCODED_CONFIG")
        }
        // 4. Fall back to embedded config from stored entity ID
        else if let embedded = decodeConfigFromID(id) {
            config = embedded
            storage.appendExtensionLog("makeEntry: using EMBEDDED id.len=\(id.count)")
            
            // Populate imageData for slides/items not already populated by loadConfigurations
            if config.slides != nil {
                for j in config.slides!.indices where config.slides![j].imageData == nil {
                    let fn = config.slides![j].filename
                    if !fn.isEmpty {
                        config.slides![j].imageData = storage.loadWidgetImageData(filename: fn)
                    }
                }
            }
            // Note: do NOT load imageData for grid items here. The extension's ItemView
            // has no image-rendering path for grid cells, and loading full-res images
            // for 7+ items exceeds the 30 MB WidgetKit memory limit.
        } else {
            config = .defaultConfiguration
            storage.appendExtensionLog("makeEntry: DEFAULT_CONFIG id.len=\(id.count) uuid=\(uuid.prefix(8))")
        }
    } else {
        config = .defaultConfiguration
    }

    // Apply slide index written by AdvanceImageIntent as a lightweight override.
    // This fires when saveConfigurations didn't cross the process boundary so the
    // config we just loaded still has the old slide index.
    // Use the UUID from the entity ID parameter (not config.id) so that even when
    // SharedStorage is unavailable and config falls back to .defaultConfiguration
    // (which has a fresh random UUID), we still look up the key AdvanceImageIntent wrote.
    var finalConfig = config
    let entityUUID = configID.map { uuidFromEntityID($0) } ?? config.id.uuidString
    let idxKey = "slideIdx_\(entityUUID)"
    var slideOverride: Int? = nil
    for id in SharedStorage.appGroupCandidates {
        if let v = UserDefaults(suiteName: id)?.object(forKey: idxKey) as? Int {
            slideOverride = v; break
        }
    }
    if slideOverride == nil {
        slideOverride = UserDefaults.standard.object(forKey: idxKey) as? Int
    }
    if let v = slideOverride { finalConfig.currentSlideIndex = v }

    // Apply item-order override written by SwapWidgetItemsIntent using position indices.
    // Since SlimItem creates new UUIDs on load, we use array positions instead.
    // Format: "0,2,1,3,4" means item at index 0 stays at 0, item at index 1 moves to 2, etc.
    let normalizedEntityUUID = entityUUID.uppercased()
    let orderKey = "itemOrder_\(normalizedEntityUUID)"
    
    // DEBUG: Log exact keys being checked
    storage.appendExtensionLog("ORDER_KEY_DEBUG: entityUUID=\(entityUUID.prefix(8)) normalized=\(normalizedEntityUUID.prefix(20)) orderKey=\(orderKey)")
    storage.appendExtensionLog("ORDER_KEY_DEBUG: UD.st[\(orderKey)]=\(UserDefaults.standard.string(forKey: orderKey) != nil ? "YES" : "nil")")
    
    // Check order override from ALL sources - App Group files are most likely to work
    var orderFound = false
    var orderValue: String? = nil
    var orderSource = "none"
    
    // 1. Check App Group container files (.dat) - most reliable for sideloaded
    for id in SharedStorage.appGroupCandidates {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            let url = container.appendingPathComponent("\(orderKey).dat")
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            storage.appendExtensionLog("ORDER_KEY_DEBUG: file[\(id.prefix(10))]=\(fileExists ? "EXISTS" : "NO")")
            if let data = try? Data(contentsOf: url),
               let str = String(data: data, encoding: .utf8), !str.isEmpty {
                orderFound = true
                orderValue = str
                orderSource = "AppGroupFile(\(id.prefix(15)))"
                break
            }
        }
    }
    
    // 2. Check App Group UserDefaults
    if !orderFound {
        for id in SharedStorage.appGroupCandidates {
            if let str = UserDefaults(suiteName: id)?.string(forKey: orderKey), !str.isEmpty {
                orderFound = true
                orderValue = str
                orderSource = "AppGroupUD(\(id.prefix(15)))"
                break
            }
        }
    }
    
    // 3. Check UserDefaults.standard
    if !orderFound {
        if let str = UserDefaults.standard.string(forKey: orderKey), !str.isEmpty {
            orderFound = true
            orderValue = str
            orderSource = "UserDefaults.standard"
        }
    }
    
    // Apply reordering if found
    if orderFound, let orderStr = orderValue {
        let positions = orderStr.split(separator: ",").compactMap { Int($0) }
        if positions.count == finalConfig.items.count {
            var reordered = finalConfig.items
            for (newIndex, oldIndex) in positions.enumerated() {
                if oldIndex >= 0 && oldIndex < reordered.count {
                    reordered[newIndex] = finalConfig.items[oldIndex]
                }
            }
            finalConfig.items = reordered
            storage.appendExtensionLog("ORDER: applied from \(orderSource)")
        }
    } else {
        storage.appendExtensionLog("ORDER: not found for key=\(orderKey.prefix(20))")
    }
    
    // Create debug info string for widget display
    // Show: order source and value, or "DEF:" / "NO:" + last 6 of UUID
    let uuidSuffix = String(normalizedEntityUUID.suffix(6))
    let debugOrderInfo: String
    if orderFound {
        debugOrderInfo = "OK(\(orderSource.prefix(8))):\(orderValue ?? "")"
    } else {
        // Also show if config came from default (random UUID) vs saved config
        let isDefaultConfig = (configID == nil || configID == "none" || 
                               !liveConfigs.contains { $0.id.uuidString.uppercased() == normalizedEntityUUID })
        let prefix = isDefaultConfig ? "DEF:" : "NO:"
        debugOrderInfo = "\(prefix)\(uuidSuffix)"
    }

    // Only keep imageData for the ACTIVE slide. loadConfigurations() eagerly loads
    // every slide's image; holding them all decoded simultaneously easily blows the
    // 30 MB WidgetKit process memory limit and causes a silent blank-widget kill.
    if var slides = finalConfig.slides, !slides.isEmpty {
        let activeIdx = min(finalConfig.currentSlideIndex ?? 0, slides.count - 1)
        for j in slides.indices {
            if j == activeIdx {
                // Ensure the active slide has data (may be nil when config was loaded
                // from the stripped JSON path where saveConfigurations omits imageData).
                if slides[j].imageData == nil, !slides[j].filename.isEmpty {
                    slides[j].imageData = storage.loadWidgetImageData(filename: slides[j].filename)
                }
            } else {
                slides[j].imageData = nil
            }
        }
        finalConfig.slides = slides
    }

    // Grid items: strip imageData entirely. The extension's ItemView has no .image
    // rendering path; keeping full-res image blobs for 7+ items easily exceeds the
    // 30 MB WidgetKit process memory limit and causes a silent blank-widget kill.
    for j in finalConfig.items.indices where finalConfig.items[j].imageData != nil {
        finalConfig.items[j].imageData = nil
    }

    let showLabels = finalConfig.showItemLabels ?? storage.showItemLabels
    let storageName = storage.debugReadSource(forKey: SharedStorage.configKey)
    let configCount = liveConfigs.count
    
    // Fresh config debug info - comprehensive
    let freshConfigInfo: String
    let marker = UserDefaults.standard.string(forKey: "refreshMarker") ?? "NO_MARKER"
    let swapDebug = UserDefaults.standard.string(forKey: "swapDebug") ?? "NO_SWAP_DEBUG"
    
    // Check App Group containers - both UserDefaults and files
    var appGroupStatus = ""
    for id in SharedStorage.appGroupCandidates {
        let hasContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
        let hasData = UserDefaults(suiteName: id)?.data(forKey: SharedStorage.configKey) != nil
        var hasOrderFile = false
        if hasContainer, let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            let orderFileURL = container.appendingPathComponent("\(orderKey).dat")
            hasOrderFile = FileManager.default.fileExists(atPath: orderFileURL.path)
        }
        appGroupStatus += "\(id.prefix(15)):\(hasContainer ? "Y" : "N")/\(hasData ? "D" : "_")/\(hasOrderFile ? "F" : "_") "
    }
    
    // Build info string
    let configIDSample = configID.map { $0.count > 20 ? String($0.prefix(20)) + "..." : $0 } ?? "nil"
    let versionKeyByEntity = "dataVersion_" + entityUUID.uppercased()
    let dataVersion = UserDefaults.standard.integer(forKey: versionKeyByEntity)
    
    // Debug: Show what config we ended up with
    let configSource: String
    if liveConfigs.contains(where: { $0.id.uuidString.uppercased() == entityUUID.uppercased() }) {
        configSource = "liveConfigs"
    } else if latestEncoded != nil {
        configSource = "LATEST_ENC"
    } else if specificEncoded != nil {
        configSource = "SPECIFIC_ENC"
    } else if decodeConfigFromID(configID ?? "") != nil {
        configSource = "EMBEDDED"
    } else {
        configSource = "DEFAULT"
    }
    
    // Get first 3 item names from finalConfig to verify
    let itemNames = finalConfig.items.prefix(3).map { $0.displayType.rawValue }.joined(separator: ",")
    let itemCount = finalConfig.items.count
    
    // Check if order key exists in UserDefaults.standard
    // Check storage accessibility
    var storageChecks: [String] = []
    
    // UserDefaults.standard
    let udData = UserDefaults.standard.data(forKey: SharedStorage.configKey)
    storageChecks.append("UD.std: \(udData != nil ? "HAS(\(udData!.count)B)" : "empty")")
    
    // Keychain
    let kcData = storage.keychainRead(forKey: SharedStorage.configKey)
    storageChecks.append("Keychain: \(kcData != nil ? "HAS(\(kcData!.count)B)" : "empty")")
    
    // App Groups
    for ag in SharedStorage.appGroupCandidates.prefix(2) {
        if let ud = UserDefaults(suiteName: ag) {
            let d = ud.data(forKey: SharedStorage.configKey)
            storageChecks.append("AG[\(ag.prefix(15))]: \(d != nil ? "HAS" : "empty")")
        }
    }
    
    var infoLines: [String] = []
    infoLines.append("=== DEBUG ===")
    infoLines.append("uuid: \(entityUUID.prefix(8)) items: \(itemCount) order: \(debugOrderInfo)")
    infoLines.append("src: \(configSource) | liveConfigs: \(liveConfigs.count)")
    infoLines.append("Storage: \(storageName)")
    infoLines.append("---")
    // Check for FRESH_ENTITY_ID file (written by swap action)
    let freshEntityKey = "FRESH_ENTITY_ID_\(entityUUID)"
    var freshEntityFound = false
    for appGroupID in SharedStorage.appGroupCandidates.prefix(2) {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = container.appendingPathComponent("\(freshEntityKey).txt")
            if let exists = try? fileURL.checkResourceIsReachable(), exists {
                infoLines.append("FRESH_FILE: YES in \(appGroupID.prefix(15))")
                freshEntityFound = true
                break
            }
        }
    }
    if !freshEntityFound {
        infoLines.append("FRESH_FILE: NOT FOUND")
    }
    infoLines.append("---")
    if !note.isEmpty {
        infoLines.append("NOTE: \(note)")
    } else {
        infoLines.append("REFRESH: Uses cached entity")
    }
    freshConfigInfo = infoLines.joined(separator: "\n")
    
    return WidgetEntry(date: Date(), configuration: finalConfig,
                       showItemLabels: showLabels, entityUUID: entityUUID,
                       debugOrderInfo: debugOrderInfo, debugOrderFound: orderFound,
                       debugStorageName: storageName, debugConfigCount: configCount,
                       debugFreshConfigInfo: freshConfigInfo)
}

private func makeTimeline(configID: String?) -> Timeline<WidgetEntry> {
    let entry = makeEntry(configID: configID)
    
    // Check if data version changed - if so, use .atEnd to trigger more frequent refreshes
    let entityUUID = (configID.map { uuidFromEntityID($0) } ?? entry.entityUUID).uppercased()
    let versionKey = "dataVersion_\(entityUUID)"
    let knownVersionKey = "knownVersion_\(entityUUID)"
    
    var currentVersion = 0
    for id in SharedStorage.appGroupCandidates {
        if let v = UserDefaults(suiteName: id)?.integer(forKey: versionKey), v > 0 {
            currentVersion = v; break
        }
    }
    if currentVersion == 0 {
        currentVersion = UserDefaults.standard.integer(forKey: versionKey)
    }
    
    var lastKnownVersion = 0
    for id in SharedStorage.appGroupCandidates {
        if let v = UserDefaults(suiteName: id)?.integer(forKey: knownVersionKey), v > 0 {
            lastKnownVersion = v; break
        }
    }
    if lastKnownVersion == 0 {
        lastKnownVersion = UserDefaults.standard.integer(forKey: knownVersionKey)
    }
    
    // If version changed, use atEnd policy - this tells iOS to call us again
    // when the widget is displayed, which is efficient and battery-friendly
    if currentVersion > 0 && currentVersion != lastKnownVersion {
        // Update known version so we only do this once per change
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(currentVersion, forKey: knownVersionKey)
        }
        UserDefaults.standard.set(currentVersion, forKey: knownVersionKey)
        
        // atEnd = iOS calls us again when widget is displayed
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    // Normal case: refresh in 1 hour
    let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    return Timeline(entries: [entry], policy: .after(next))
}

private func makeClockEntry(position: ClockDigitPosition?) -> WidgetEntry {
    let now = Date()

    var config = WidgetConfig.defaultConfiguration
    config.widgetKind = .clock
    config.clockDigitPosition = position ?? .hour
    config.clockFontSize = 48
    config.backgroundOpacity = 0 // Transparent for iOS 26 clear mode
    
    return WidgetEntry(date: now, configuration: config)
}

private func makeClockTimeline(position: ClockDigitPosition?) -> Timeline<WidgetEntry> {
    let entry = makeClockEntry(position: position)
    // Update every minute
    let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
    return Timeline(entries: [entry], policy: .after(next))
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: SMALL WIDGET — home screen Small (3×3, systemSmall)
// MARK: ─────────────────────────────────────────────────────────────────

struct SmallWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Small Widget")
    }
    static var defaultQuery = SmallWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct SmallWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SmallWidgetEntity] {
        let configs = filteredConfigs(size: .systemSmall)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            // Fresh data from live storage
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return SmallWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            // Reconstruct from embedded config in the stored ID
            if let c = decodeConfigFromID(storedID) {
                return SmallWidgetEntity(id: storedID, name: c.name)
            }
            // Preserve the selection even if config is unavailable
            return SmallWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [SmallWidgetEntity] {
        let list = filteredConfigs(size: .systemSmall)
        if list.isEmpty { return [SmallWidgetEntity(id: "none", name: "No Small Widgets")] }
        return list.map { SmallWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> SmallWidgetEntity? {
        filteredConfigs(size: .systemSmall).first.map { SmallWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectSmallWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Small Widget"
    static var description = IntentDescription("Choose a small (3×3) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: SmallWidgetEntity?
    init() {}
    init(selectedWidget: SmallWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct SmallBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectSmallWidgetIntent, in context: Context) async -> WidgetEntry {
        return makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectSmallWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let storedID = configuration.selectedWidget?.id ?? "nil"
        SharedStorage.shared.appendExtensionLog("SmallTimeline START storedID.len=\(storedID.count)")
        
        // Re-query entities to get FRESH data from SharedStorage (same as reselection!)
        let entities = try? await SmallWidgetQuery().entities(for: [storedID])
        SharedStorage.shared.appendExtensionLog("SmallTimeline entities.count=\(entities?.count ?? -1)")
        
        if let fresh = entities?.first {
            SharedStorage.shared.appendExtensionLog("SmallTimeline: RE-QUERIED fresh entity id.len=\(fresh.id.count) items=\(fresh.name)")
            return makeTimeline(configID: fresh.id)
        }
        
        SharedStorage.shared.appendExtensionLog("SmallTimeline: FALLBACK to storedID")
        return makeTimeline(configID: storedID)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: MEDIUM WIDGET — home screen Medium (6×3, systemMedium)
// MARK: ─────────────────────────────────────────────────────────────────

struct MediumWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Medium Widget")
    }
    static var defaultQuery = MediumWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct MediumWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MediumWidgetEntity] {
        let configs = filteredConfigs(size: .systemMedium)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return MediumWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return MediumWidgetEntity(id: storedID, name: c.name)
            }
            return MediumWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [MediumWidgetEntity] {
        let list = filteredConfigs(size: .systemMedium)
        if list.isEmpty { return [MediumWidgetEntity(id: "none", name: "No Medium Widgets")] }
        return list.map { MediumWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> MediumWidgetEntity? {
        filteredConfigs(size: .systemMedium).first.map { MediumWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectMediumWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Medium Widget"
    static var description = IntentDescription("Choose a medium (6×3) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: MediumWidgetEntity?
    init() {}
    init(selectedWidget: MediumWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct MediumBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectMediumWidgetIntent, in context: Context) async -> WidgetEntry {
        // Re-query entities to get FRESH data from SharedStorage (same as reselection!)
        if let id = configuration.selectedWidget?.id {
            let entities = try? await MediumWidgetQuery().entities(for: [id])
            if let fresh = entities?.first {
                return makeEntry(configID: fresh.id)
            }
        }
        return makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectMediumWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        // CRITICAL: Re-query entities to get FRESH data from SharedStorage!
        if let id = configuration.selectedWidget?.id {
            let entities = try? await MediumWidgetQuery().entities(for: [id])
            if let fresh = entities?.first {
                SharedStorage.shared.appendExtensionLog("Medium timeline: RE-QUERIED fresh entity id.len=\(fresh.id.count)")
                return makeTimeline(configID: fresh.id)
            }
        }
        return makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: LARGE WIDGET — home screen Large (6×6, systemLarge)
// MARK: ─────────────────────────────────────────────────────────────────

struct LargeWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Large Widget")
    }
    static var defaultQuery = LargeWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct LargeWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LargeWidgetEntity] {
        // Debug: check what storage is accessible
        let storage = SharedStorage.shared
        let storageDebug = storage.gatherReadDebug(forKey: SharedStorage.configKey)
        storage.appendExtensionLog("LargeQuery: storage=\(storageDebug.source)")
        
        let configs = filteredConfigs(size: .systemLarge)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return LargeWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return LargeWidgetEntity(id: storedID, name: c.name)
            }
            return LargeWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [LargeWidgetEntity] {
        let list = filteredConfigs(size: .systemLarge)
        if list.isEmpty { return [LargeWidgetEntity(id: "none", name: "No Large Widgets")] }
        return list.map { LargeWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> LargeWidgetEntity? {
        filteredConfigs(size: .systemLarge).first.map { LargeWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectLargeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Large Widget"
    static var description = IntentDescription("Choose a large (6×6) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: LargeWidgetEntity?
    init() {}
    init(selectedWidget: LargeWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct LargeBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectLargeWidgetIntent, in context: Context) async -> WidgetEntry {
        return makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectLargeWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let storedID = configuration.selectedWidget?.id ?? "nil"
        
        // Check storage in query context
        let storageDebug = SharedStorage.shared.gatherReadDebug(forKey: SharedStorage.configKey)
        let queryConfigs = filteredConfigs(size: .systemLarge)
        
        var freshID: String? = nil
        var note: String
        
        if queryConfigs.isEmpty {
            // filteredConfigs returns empty = SharedStorage not accessible
            note = "QRY:EMPTY storage=\(storageDebug.source)"
        } else {
            // Found configs via query - re-query entities
            let entities = try? await LargeWidgetQuery().entities(for: [storedID])
            if let fresh = entities?.first {
                freshID = fresh.id
                note = "QRY:GOT_CONFIGS fresh.id.len=\(fresh.id.count)"
            } else {
                note = "QRY:NO_ENTITY storage=\(storageDebug.source)"
            }
        }
        
        let entry = makeEntryInternal(configID: freshID ?? storedID, debugNote: note)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: LOCK SCREEN WIDGETS (accessory families)
// MARK: ─────────────────────────────────────────────────────────────────

struct LockWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Lock Screen Widget")
    }
    static var defaultQuery = LockWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct LockWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LockWidgetEntity] {
        let configs = allConfigs()
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return LockWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return LockWidgetEntity(id: storedID, name: c.name)
            }
            return LockWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [LockWidgetEntity] {
        // Prefer dedicated lock-screen configs; fall back to all configs
        var list = allConfigs().filter { $0.widgetKind == .lockScreen }
        if list.isEmpty { list = allConfigs() }
        if list.isEmpty { return [LockWidgetEntity(id: "none", name: "No Widgets")] }
        return list.map { LockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> LockWidgetEntity? {
        let ls = allConfigs().filter { $0.widgetKind == .lockScreen }
        let pick = ls.first ?? allConfigs().first
        return pick.map { LockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectLockWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Lock Screen Widget"
    static var description = IntentDescription("Choose a widget for the Lock Screen")
    @Parameter(title: "Widget") var selectedWidget: LockWidgetEntity?
    init() {}
    init(selectedWidget: LockWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct LockBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectLockWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectLockWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: - Legacy / Generic (backwards-compat for any existing placed widgets)

struct WidgetNameEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Widget")
    }
    static var defaultQuery = WidgetNameQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct WidgetNameQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetNameEntity] {
        let configs = allConfigs()
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return WidgetNameEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return WidgetNameEntity(id: storedID, name: c.name)
            }
            return WidgetNameEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        let list = allConfigs()
        if list.isEmpty { return [WidgetNameEntity(id: "none", name: "No Configurations")] }
        return list.map { WidgetNameEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> WidgetNameEntity? {
        allConfigs().first.map { WidgetNameEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Choose which widget configuration to display")
    @Parameter(title: "Widget") var selectedWidget: WidgetNameEntity?
    init() {}
    init(selectedWidget: WidgetNameEntity?) { self.selectedWidget = selectedWidget }
}

struct BroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectWidgetIntent, in context: Context) async -> WidgetEntry {
        // Re-query entities to get FRESH data from SharedStorage (same as reselection!)
        if let id = configuration.selectedWidget?.id {
            let entities = try? await WidgetNameQuery().entities(for: [id])
            if let fresh = entities?.first {
                return makeEntry(configID: fresh.id)
            }
        }
        return makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        // CRITICAL: Re-query entities to get FRESH data from SharedStorage!
        // This mimics what happens during widget reselection.
        if let id = configuration.selectedWidget?.id {
            let entities = try? await WidgetNameQuery().entities(for: [id])
            if let fresh = entities?.first {
                SharedStorage.shared.appendExtensionLog("timeline: RE-QUERIED fresh entity id.len=\(fresh.id.count)")
                return makeTimeline(configID: fresh.id)
            }
        }
        return makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: IMAGE SLIDESHOW WIDGET
// MARK: ─────────────────────────────────────────────────────────────────

private func imageSlideshowConfigs() -> [WidgetConfig] {
    allConfigs().filter { $0.widgetKind == .imageSlideshow }
}

struct ImageWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Code Widget")
    }
    static var defaultQuery = ImageWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct ImageWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ImageWidgetEntity] {
        let configs = imageSlideshowConfigs()
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return ImageWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return ImageWidgetEntity(id: storedID, name: c.name)
            }
            return ImageWidgetEntity(id: storedID, name: "Code Widget")
        }
    }
    func suggestedEntities() async throws -> [ImageWidgetEntity] {
        let list = imageSlideshowConfigs()
        if list.isEmpty { return [ImageWidgetEntity(id: "none", name: "No Code Widgets")] }
        return list.map { ImageWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> ImageWidgetEntity? {
        imageSlideshowConfigs().first.map { ImageWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectImageWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Code Widget"
    static var description = IntentDescription("Choose a code widget")
    @Parameter(title: "Widget") var selectedWidget: ImageWidgetEntity?
    init() {}
    init(selectedWidget: ImageWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct ImageBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectImageWidgetIntent, in context: Context) async -> WidgetEntry {
        // Re-query entities to get FRESH data from SharedStorage (same as reselection!)
        if let id = configuration.selectedWidget?.id {
            let entities = try? await ImageWidgetQuery().entities(for: [id])
            if let fresh = entities?.first {
                return makeEntry(configID: fresh.id)
            }
        }
        return makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectImageWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        // CRITICAL: Re-query entities to get FRESH data from SharedStorage!
        if let id = configuration.selectedWidget?.id {
            let entities = try? await ImageWidgetQuery().entities(for: [id])
            if let fresh = entities?.first {
                SharedStorage.shared.appendExtensionLog("Image timeline: RE-QUERIED fresh entity id.len=\(fresh.id.count)")
                return makeTimeline(configID: fresh.id)
            }
        }
        return makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: - Clock Widget Intent

struct ClockWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Clock Widget")
    }
    static var defaultQuery = ClockWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct ClockWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ClockWidgetEntity] {
        let configs = filteredConfigs(kind: .clock)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return ClockWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return ClockWidgetEntity(id: storedID, name: c.name)
            }
            return ClockWidgetEntity(id: storedID, name: "Clock")
        }
    }
    func suggestedEntities() async throws -> [ClockWidgetEntity] {
        let list = filteredConfigs(kind: .clock)
        if list.isEmpty { return [ClockWidgetEntity(id: "none", name: "No Clock Widgets")] }
        return list.map { ClockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> ClockWidgetEntity? {
        filteredConfigs(kind: .clock).first.map { ClockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectClockWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Clock Widget"
    static var description = IntentDescription("Choose a clock widget configuration")
    @Parameter(title: "Widget") var selectedWidget: ClockWidgetEntity?
    init() {}
    init(selectedWidget: ClockWidgetEntity?) { self.selectedWidget = selectedWidget }
}

enum ClockDigitPositionEntity: String, AppEnum {
    case hour = "hour"
    case minute = "minute"
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Digits" }
    static var caseDisplayRepresentations: [ClockDigitPositionEntity: DisplayRepresentation] {
        [.hour: "Hour (12h)", .minute: "Minute"]
    }
}

struct ClockBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        var config = WidgetConfig.defaultConfiguration
        config.widgetKind = .clock
        config.clockDigitPosition = .hour
        config.clockFontSize = 80
        return WidgetEntry(date: Date(), configuration: config)
    }
    func snapshot(for configuration: SelectClockWidgetIntent, in context: Context) async -> WidgetEntry {
        // Re-query entities to get FRESH data from SharedStorage (same as reselection!)
        if let id = configuration.selectedWidget?.id {
            let entities = try? await ClockWidgetQuery().entities(for: [id])
            if let fresh = entities?.first {
                return makeEntry(configID: fresh.id)
            }
        }
        return makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectClockWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        // CRITICAL: Re-query entities to get FRESH data from SharedStorage!
        var freshID = configuration.selectedWidget?.id
        if let id = freshID {
            let entities = try? await ClockWidgetQuery().entities(for: [id])
            if let fresh = entities?.first {
                SharedStorage.shared.appendExtensionLog("Clock timeline: RE-QUERIED fresh entity id.len=\(fresh.id.count)")
                freshID = fresh.id
            }
        }
        let entry = makeEntry(configID: freshID)
        // Update every minute
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - No-Op Intent (prevents app from opening when empty widget areas are tapped)

/// Placed on every empty grid cell and the widget background so that tapping
/// anywhere without a real action does nothing instead of opening the host app.
struct NoOpIntent: AppIntent {
    static var title: LocalizedStringResource = "No Action"
    static var openAppWhenRun: Bool = false
    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Advance Image Intent (widget Button only — cycles slides in an image slideshow widget)
//
// This intent is compiled into both targets so the widget's Button(intent:) can run it
// inside the extension process. For Shortcuts use, see AdvanceCodeSlideIntent (main app only).

struct AdvanceImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Advance Slide (Widget Button)"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget ID")   var widgetID: String
    @Parameter(title: "Forward")     var forward: Bool
    /// Total number of slides — embedded by the widget view so perform() never needs
    /// to call loadConfigurations() from within the extension.
    @Parameter(title: "Slide Count") var slideCount: Int

    init() { widgetID = ""; forward = true; slideCount = 0 }
    init(widgetID: String, forward: Bool, slideCount: Int) {
        self.widgetID = widgetID; self.forward = forward; self.slideCount = slideCount
    }

    func perform() async throws -> some IntentResult {
        guard slideCount > 1 else { return .result() }

        let idxKey = "slideIdx_\(widgetID)"
        var currentIndex = 0
        for id in SharedStorage.appGroupCandidates {
            if let v = UserDefaults(suiteName: id)?.object(forKey: idxKey) as? Int {
                currentIndex = v; break
            }
        }
        if let v = UserDefaults.standard.object(forKey: idxKey) as? Int {
            currentIndex = v
        }

        let nextIndex = forward
            ? (currentIndex + 1) % slideCount
            : (currentIndex - 1 + slideCount) % slideCount

        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(nextIndex, forKey: idxKey)
            UserDefaults(suiteName: id)?.synchronize()
        }
        UserDefaults.standard.set(nextIndex, forKey: idxKey)
        UserDefaults.standard.synchronize()

        if var configs = try? SharedStorage.shared.loadConfigurations(),
           let idx = configs.firstIndex(where: { $0.id.uuidString == widgetID }) {
            configs[idx].currentSlideIndex = nextIndex
            try? SharedStorage.shared.saveConfigurations(configs)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastImage")
        return .result()
    }
}

// MARK: - Refresh Widget Intent

/// Intent triggered by widget button to refresh the widget with fresh data.
/// This runs in the main app's context, giving full access to SharedStorage.
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"
    static var description = IntentDescription("Refreshes the widget with latest data from storage. Tap after making changes.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget Entity ID")
    var entityUUID: String  // The UUID of the widget config

    init() {}
    init(entityUUID: String) { self.entityUUID = entityUUID }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Simply trigger widget timeline reload - this is the same mechanism iOS uses
        // when the user manually reselects the widget. The widget will rebuild its
        // timeline and read fresh data from SharedStorage.
        WidgetCenter.shared.reloadAllTimelines()
        
        // Also post Darwin notification as backup
        DarwinNotificationCenter.shared.postWidgetUpdate()

        return .result(dialog: IntentDialog(stringLiteral: "Widget refreshed. Tap widget to see changes."))
    }
}
