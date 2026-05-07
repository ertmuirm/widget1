import Foundation

/// Parses and generates Shortcuts .shortcut binary plist files.
/// Format: binary plist with WFWorkflowActions array.
/// A "Choose from Menu" shortcut uses is.workflow.actions.choosefrommenu with
/// WFControlFlowMode 0 (start), 1 (item), 2 (end).
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

    /// Parses a binary-plist .shortcut file and returns LauncherItems derived from
    /// its "Choose from Menu" structure.
    static func importItems(from data: Data) throws -> [LauncherItem] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let root = plist as? [String: Any],
              let actions = root["WFWorkflowActions"] as? [[String: Any]]
        else { throw ShortcutError.invalidFile }

        return try parseMenuItems(from: actions)
    }

    // MARK: - Export

    /// Builds a binary-plist .shortcut that opens this app with the launcher URL for each item.
    static func exportData(from config: LauncherConfig) throws -> Data {
        let actions = buildMenuActions(for: config)
        let root: [String: Any] = [
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowClientVersion": "1268.0.1",
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 255,
                "WFWorkflowIconGlyphNumber": 59511
            ],
            "WFWorkflowInputContentItemClasses": [] as [String],
            "WFWorkflowTypes": ["NCWidget", "WatchKit"] as [String],
            "WFWorkflowOutputContentItemClasses": [] as [String],
            "WFWorkflowActions": actions
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
        // Locate the choosefrommenu start block (WFControlFlowMode == 0)
        guard let startIdx = actions.firstIndex(where: {
            ($0["WFWorkflowActionIdentifier"] as? String) == "is.workflow.actions.choosefrommenu"
            && controlFlowMode($0) == 0
        }) else { throw ShortcutError.noMenuFound }

        let startAction = actions[startIdx]
        let startParams = startAction["WFWorkflowActionParameters"] as? [String: Any]
        let groupID = startParams?["GroupingIdentifier"] as? String ?? ""

        // Collect item-block actions (WFControlFlowMode == 1) matching the same groupID,
        // paired with the next sub-action (the actual command).
        var items: [LauncherItem] = []
        var i = startIdx + 1
        while i < actions.count {
            let a = actions[i]
            guard (a["WFWorkflowActionIdentifier"] as? String) == "is.workflow.actions.choosefrommenu",
                  controlFlowMode(a) == 1,
                  let params = a["WFWorkflowActionParameters"] as? [String: Any],
                  (params["GroupingIdentifier"] as? String) == groupID
            else {
                if (a["WFWorkflowActionIdentifier"] as? String) == "is.workflow.actions.choosefrommenu",
                   controlFlowMode(a) == 2 { break }
                i += 1
                continue
            }
            let title = params["WFMenuItemTitle"] as? String ?? "Item \(items.count + 1)"
            // Sub-action immediately follows
            let subAction = i + 1 < actions.count ? actions[i + 1] : nil
            let action = widgetAction(from: subAction)
            items.append(LauncherItem(name: title, action: action))
            i += 2
        }
        return items
    }

    private static func controlFlowMode(_ action: [String: Any]) -> Int? {
        guard let params = action["WFWorkflowActionParameters"] as? [String: Any] else { return nil }
        return params["WFControlFlowMode"] as? Int
    }

    private static func widgetAction(from action: [String: Any]?) -> WidgetAction {
        guard let action,
              let params = action["WFWorkflowActionParameters"] as? [String: Any]
        else { return WidgetAction(type: .urlScheme, payload: "") }

        let id = action["WFWorkflowActionIdentifier"] as? String ?? ""
        switch id {
        case "is.workflow.actions.openurl":
            let url = wfTextValue(params["WFURLActionURL"]) ?? ""
            return WidgetAction(type: .urlScheme, payload: url)
        case "is.workflow.actions.runworkflow":
            let name = wfTextValue(params["WFWorkflowName"]) ?? ""
            return WidgetAction(type: .shortcut, payload: name)
        default:
            return WidgetAction(type: .urlScheme, payload: "")
        }
    }

    /// Extracts the string value from a WFTextTokenString dict or raw String.
    private static func wfTextValue(_ v: Any?) -> String? {
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

        // Start of menu block
        actions.append([
            "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
            "WFWorkflowActionParameters": [
                "WFControlFlowMode": 0,
                "GroupingIdentifier": groupID,
                "WFMenuPrompt": config.name,
                "WFMenuItemTitles": config.items.map(\.name)
            ]
        ])

        for item in config.items {
            // Item case header
            actions.append([
                "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
                "WFWorkflowActionParameters": [
                    "WFControlFlowMode": 1,
                    "GroupingIdentifier": groupID,
                    "WFMenuItemTitle": item.name
                ]
            ])
            // Item action
            actions.append(actionDict(for: item.action))
        }

        // End of menu block
        actions.append([
            "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
            "WFWorkflowActionParameters": [
                "WFControlFlowMode": 2,
                "GroupingIdentifier": groupID
            ]
        ])

        return actions
    }

    private static func actionDict(for action: WidgetAction) -> [String: Any] {
        switch action.type {
        case .shortcut:
            return [
                "WFWorkflowActionIdentifier": "is.workflow.actions.runworkflow",
                "WFWorkflowActionParameters": [
                    "WFWorkflowName": wfTextTokenString(action.payload)
                ]
            ]
        case .urlScheme, .appIntent:
            let url = action.type == .appIntent
                ? "openapp://launch?bundle=\(action.payload)"
                : action.payload
            return [
                "WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
                "WFWorkflowActionParameters": [
                    "WFURLActionURL": wfTextTokenString(url)
                ]
            ]
        }
    }

    private static func wfTextTokenString(_ value: String) -> [String: Any] {
        [
            "Value": [
                "attachmentsByRange": [:] as [String: Any],
                "string": value
            ],
            "WFSerializationType": "WFTextTokenString"
        ]
    }
}
