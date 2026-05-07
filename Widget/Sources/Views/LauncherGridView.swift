import SwiftUI

/// Full-screen launcher grid overlay.
/// Dismissed by swiping in any direction (min 60 pt drag) or tapping the
/// invisible hit-target in the top-right corner.
struct LauncherGridView: View {
    let config: LauncherConfig
    var onDismiss: () -> Void

    @AppStorage("launcherFontSize")  private var fontSize: Double = 16
    @AppStorage("launcherRowHeight") private var rowHeight: Double = 44

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 0
                ) {
                    ForEach(config.items) { item in
                        Button {
                            onDismiss()
                            openAction(item.action)
                        } label: {
                            Text(item.name)
                                .font(.system(size: fontSize))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: rowHeight)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 16)
            }

            // Invisible dismiss target in the top-right corner (44×44 tap area, no visual).
            Button(action: dismissAndSuspend) {
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        // Dismiss on any swipe with at least 60 pt travel in any direction.
        .gesture(
            DragGesture(minimumDistance: 60, coordinateSpace: .local)
                .onEnded { _ in dismissAndSuspend() }
        )
    }

    // MARK: - Dismiss

    private func dismissAndSuspend() {
        onDismiss()
        UIApplication.shared.perform(NSSelectorFromString("suspend"))
    }

    // MARK: - Action

    private func openAction(_ action: WidgetAction) {
        let url: URL?
        switch action.type {
        case .urlScheme:
            url = URL(string: action.payload)
        case .shortcut:
            let enc = action.payload
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? action.payload
            url = URL(string: "shortcuts://run-shortcut?name=\(enc)")
        case .appIntent:
            url = URL(string: "openapp://launch?bundle=\(action.payload)")
        }
        guard let url else { return }
        // Use the non-async callback form — fire-and-forget, no waiting for the app-switch
        // animation to complete. iOS backgrounds this app naturally when the target opens.
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
