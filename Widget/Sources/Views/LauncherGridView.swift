import SwiftUI

/// Full-screen launcher grid overlay.
/// Presented as a fullScreenCover; dismisses after tapping any item.
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
                .padding(.top, 56)
                .padding(.bottom, 16)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
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

#Preview {
    LauncherGridView(
        config: LauncherConfig(
            name: "Quick Launch",
            items: (1...12).map { i in
                LauncherItem(
                    name: "Item \(i)",
                    action: WidgetAction(type: .urlScheme, payload: "https://example.com")
                )
            }
        ),
        onDismiss: {}
    )
}
