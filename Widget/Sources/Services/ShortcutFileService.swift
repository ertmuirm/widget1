import Foundation

/// Parses and generates Shortcuts .shortcut binary plist files.
/// Based on the iOS 26 / Shortcuts 4610 "Choose from Menu" format.
enum ShortcutFileService {

    enum ShortcutError: LocalizedError {
        case invalidFile
        case noMenuFound
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .invalidFile:  return "Could not read the .shortcut file."
            case .noMenuFound:  return "No 'Choose from Menu' action found in the shortcut."
            case .exportFailed: return "Failed to generate the .shortcut file."
            }
        }
    }

    // MARK: - Import

    /// Parses a binary-plist .shortcut file and returns LauncherItems from its
    /// "Choose from Menu" structure.  Handles both flat root and WFWorkflow-wrapped formats.
    static func importItems(from data: Data) throws -> [LauncherItem] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { throw ShortcutError.invalidFile }

        let root: [String: Any]
        if let r = plist as? [String: Any] {
            // Prefer unwrapped root; fall back to WFWorkflow envelope
            root = (r["WFWorkflow"] as? [String: Any]) ?? r
        } else {
            throw ShortcutError.invalidFile
        }

        guard let actions = root["WFWorkflowActions"] as? [[String: Any]]
        else { throw ShortcutError.invalidFile }

        return try parseMenuItems(from: actions)
    }

    // MARK: - Export

    /// Builds a binary-plist .shortcut using the iOS 26 / Shortcuts 4610 flat format.
    static func exportData(from config: LauncherConfig) throws -> Data {
        let actions = buildMenuActions(for: config)

        let inputClasses: [String] = [
            "WFAppContentItem", "WFAppStoreAppContentItem", "WFArticleContentItem",
            "WFContactContentItem", "WFDateContentItem", "WFEmailAddressContentItem",
            "WFFolderContentItem", "WFGenericFileContentItem", "WFImageContentItem",
            "WFiTunesProductContentItem", "WFLocationContentItem",
            "WFDCMapsLinkContentItem", "WFAVAssetContentItem", "WFPDFContentItem",
            "WFPhoneNumberContentItem", "WFRichTextContentItem",
            "WFSafariWebPageContentItem", "WFStringContentItem", "WFURLContentItem"
        ]

        let root: [String: Any] = [
            "WFQuickActionSurfaces":              [] as NSArray,
            "WFWorkflowActions":                  actions,
            "WFWorkflowClientVersion":            "4610",
            "WFWorkflowHasOutputFallback":        false,
            "WFWorkflowHasShortcutInputVariables": false,
            "WFWorkflowIcon": [
                "WFWorkflowIconGlyphNumber": NSNumber(value: 62214),
                "WFWorkflowIconStartColor":  NSNumber(value: 255)
            ] as [String: Any],
            "WFWorkflowImportQuestions":           [] as NSArray,
            "WFWorkflowInputContentItemClasses":  inputClasses,
            "WFWorkflowMinimumClientVersion":     NSNumber(value: 900),
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowOutputContentItemClasses": [] as NSArray,
            "WFWorkflowTypes": ["Watch", "WFWorkflowTypeShowInSearch"]
        ]

        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: root,
            format: .binary,
            options: 0)
        else { throw ShortcutError.exportFailed }
        return data
    }

    // MARK: - Private helpers

    private static func parseMenuItems(from actions: [[String: Any]]) throws -> [LauncherItem] {
        guard let startIdx = actions.firstIndex(where: {
            actionID($0) == "is.workflow.actions.choosefrommenu" && controlFlowMode($0) == 0
        }) else { throw ShortcutError.noMenuFound }

        let startParams = actions[startIdx]["WFWorkflowActionParameters"] as? [String: Any]
        let groupID = startParams?["GroupingIdentifier"] as? String ?? ""

        var items: [LauncherItem] = []
        var i = startIdx + 1
        while i < actions.count {
            let a = actions[i]
            // End block — stop
            if actionID(a) == "is.workflow.actions.choosefrommenu", controlFlowMode(a) == 2 { break }
            // Item block
            guard actionID(a) == "is.workflow.actions.choosefrommenu",
                  controlFlowMode(a) == 1,
                  let params = a["WFWorkflowActionParameters"] as? [String: Any],
                  (params["GroupingIdentifier"] as? String) == groupID
            else { i += 1; continue }

            let title = params["WFMenuItemTitle"] as? String ?? "Item \(items.count + 1)"
            let subAction = i + 1 < actions.count ? actions[i + 1] : nil
            items.append(LauncherItem(name: title, action: widgetAction(from: subAction)))
            i += 2
        }
        return items
    }

    private static func actionID(_ action: [String: Any]) -> String? {
        action["WFWorkflowActionIdentifier"] as? String
    }

    private static func controlFlowMode(_ action: [String: Any]) -> Int? {
        let params = action["WFWorkflowActionParameters"] as? [String: Any]
        return (params?["WFControlFlowMode"] as? NSNumber)?.intValue
    }

    private static func widgetAction(from action: [String: Any]?) -> WidgetAction {
        guard let action,
              let params = action["WFWorkflowActionParameters"] as? [String: Any]
        else { return WidgetAction(type: .urlScheme, payload: "") }

        switch actionID(action) {
        case "is.workflow.actions.openurl":
            // iOS 26 uses WFInput; older exports used WFURLActionURL (WFTextTokenString)
            let url = (params["WFInput"] as? String)
                ?? wfStringValue(params["WFURLActionURL"])
                ?? ""
            return WidgetAction(type: .urlScheme, payload: url)

        case "is.workflow.actions.openapp":
            let bundle = (params["WFAppIdentifier"] as? String)
                ?? (params["WFSelectedApp"] as? [String: Any])?["BundleIdentifier"] as? String
                ?? ""
            let name   = (params["WFSelectedApp"] as? [String: Any])?["Name"] as? String
            return WidgetAction(type: .appIntent, payload: bundle, displayName: name)

        case "is.workflow.actions.runworkflow":
            let name = (params["WFWorkflowName"] as? String)
                ?? wfStringValue(params["WFWorkflowName"])
                ?? ""
            return WidgetAction(type: .shortcut, payload: name)

        default:
            return WidgetAction(type: .urlScheme, payload: "")
        }
    }

    /// Extracts a plain string from either a bare String or a WFTextTokenString dict.
    private static func wfStringValue(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let d = v as? [String: Any] {
            return d["Value"] as? String
                ?? (d["Value"] as? [String: Any])?["string"] as? String
        }
        return nil
    }

    private static func buildMenuActions(for config: LauncherConfig) -> [[String: Any]] {
        let groupID = config.id.uuidString
        var actions: [[String: Any]] = []

        // Start block — no WFMenuPrompt / WFMenuItemTitles in iOS 26 format
        actions.append([
            "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
            "WFWorkflowActionParameters": [
                "GroupingIdentifier": groupID,
                "WFControlFlowMode":  NSNumber(value: 0)
            ]
        ])

        for item in config.items {
            // Item case header
            actions.append([
                "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
                "WFWorkflowActionParameters": [
                    "GroupingIdentifier": groupID,
                    "WFControlFlowMode":  NSNumber(value: 1),
                    "WFMenuItemTitle":    item.name
                ]
            ])
            // Item sub-action
            actions.append(actionDict(for: item.action))
        }

        // End block
        actions.append([
            "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
            "WFWorkflowActionParameters": [
                "GroupingIdentifier": groupID,
                "UUID":              UUID().uuidString,
                "WFControlFlowMode": NSNumber(value: 2)
            ]
        ])

        return actions
    }

    private static func actionDict(for action: WidgetAction) -> [String: Any] {
        let uuid = UUID().uuidString
        switch action.type {
        case .urlScheme:
            return [
                "WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
                "WFWorkflowActionParameters": [
                    "UUID":    uuid,
                    "WFInput": action.payload
                ]
            ]

        case .appIntent:
            return [
                "WFWorkflowActionIdentifier": "is.workflow.actions.openapp",
                "WFWorkflowActionParameters": [
                    "UUID":           uuid,
                    "WFAppIdentifier": action.payload,
                    "WFSelectedApp": [
                        "BundleIdentifier": action.payload,
                        "Name": action.displayName ?? action.payload,
                        "TeamIdentifier": ""
                    ] as [String: Any]
                ]
            ]

        case .shortcut:
            return [
                "WFWorkflowActionIdentifier": "is.workflow.actions.runworkflow",
                "WFWorkflowActionParameters": [
                    "UUID":            uuid,
                    "WFWorkflowName":  action.payload
                ]
            ]
        }
    }
}
