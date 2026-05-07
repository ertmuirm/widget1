import Foundation

// MARK: - Launcher Item

struct LauncherItem: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var action: WidgetAction

    init(id: UUID = UUID(), name: String = "", action: WidgetAction = WidgetAction()) {
        self.id = id
        self.name = name
        self.action = action
    }
}

// MARK: - Launcher Config

struct LauncherConfig: Codable, Identifiable, Equatable {
    static let maxItems = 80
    static let maxConfigs = 5

    let id: UUID
    var name: String
    var items: [LauncherItem]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String = "Launcher Grid",
         items: [LauncherItem] = [],
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var triggerURL: URL {
        URL(string: "widgetar://launcher?id=\(id.uuidString)")!
    }
}
