import WidgetKit
import SwiftUI

@main
struct BroadcastExtensionBundle: WidgetBundle {
    var body: some Widget {
        BroadcastSmallWidget()
        BroadcastMediumWidget()
        BroadcastLargeWidget()
        BroadcastLockWidget()
    }
}
