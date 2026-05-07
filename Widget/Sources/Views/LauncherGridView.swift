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
                            executeAction(item.action)
                            onDismiss()
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
            Button(action: onDismiss) {
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
                .onEnded { _ in onDismiss() }
        )
    }

    private func executeAction(_ action: WidgetAction) {
        switch action.type {
        case .urlScheme:
            guard let url = URL(string: action.payload) else { return }
            Task { await UIApplication.shared.open(url) }

        case .shortcut:
            let name = action.payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? action.payload
            guard let url = URL(string: "shortcuts://run-shortcut?name=\(name)") else { return }
            Task { await UIApplication.shared.open(url) }

        case .appIntent:
            guard let url = URL(string: "openapp://launch?bundle=\(action.payload)") else { return }
            Task { await UIApplication.shared.open(url) }
        }
    }
}
