import SwiftUI

/// List of all widget configurations
struct WidgetListView: View {

    @EnvironmentObject var viewModel: WidgetViewModel
    @AppStorage("defaultWidgetSize") private var defaultWidgetSize = WidgetSize.systemMedium.rawValue
    @State private var showAddSheet = false
    @State private var showAddImageSheet = false
    @State private var showAddLockScreenSheet = false
    @State private var showAddClockSheet = false
    @State private var showAddLauncherSheet = false
    @State private var showSettingsSheet = false
    @State private var showRemoteControlSheet = false
    @State private var hasRemoteControl = !SharedStorage.shared.allowedSSID.isEmpty

    var body: some View {
        List {
            // Widget configurations
            if !viewModel.configurations.isEmpty {
                Section("Home & Lock Screen Widgets") {
                    ForEach(viewModel.configurations) { config in
                        ZStack {
                            NavigationLink(value: config.id) { EmptyView() }.opacity(0)
                            WidgetRowView(configuration: config) {
                                if let idx = viewModel.configurations.firstIndex(where: { $0.id == config.id }) {
                                    viewModel.deleteConfiguration(at: IndexSet([idx]))
                                }
                            }
                        }
                    }
                    .onMove { from, to in viewModel.moveConfiguration(from: from, to: to) }
                }
            }

            // Launcher grids
            if !viewModel.launcherConfigs.isEmpty {
                Section("Launcher Grids") {
                    ForEach(viewModel.launcherConfigs) { launcher in
                        ZStack {
                            NavigationLink(value: launcher.id) { EmptyView() }.opacity(0)
                            LauncherRowView(config: launcher) {
                                viewModel.deleteLauncherConfig(launcher)
                            }
                        }
                    }
                    .onMove { from, to in viewModel.moveLauncherConfig(from: from, to: to) }
                }
            }

            // Remote Control (shown once configured, always accessible via +)
            if hasRemoteControl {
                Section("Remote Control") {
                    RemoteControlRowView(onDelete: {
                        SharedStorage.shared.allowedSSID = ""
                        SharedStorage.shared.savePushCommandEntries([])
                        LocalActionServer.shared.stop()
                        hasRemoteControl = false
                    })
                    .contentShape(Rectangle())
                    .onTapGesture { showRemoteControlSheet = true }
                }
            }

            if viewModel.configurations.isEmpty && viewModel.launcherConfigs.isEmpty && !hasRemoteControl {
                emptyView
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Widgets")
        .navigationDestination(for: UUID.self) { id in
            if let config = viewModel.configurations.first(where: { $0.id == id }) {
                WidgetEditorView(configuration: config)
            } else if let launcher = viewModel.launcherConfigs.first(where: { $0.id == id }) {
                LauncherEditorView(config: launcher)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gear")
                        .font(.title3)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Grid Widget", systemImage: "square.grid.2x2")
                    }
                    Button {
                        showAddImageSheet = true
                    } label: {
                        Label("Code Widget", systemImage: "qrcode")
                    }
                    Button {
                        showAddLockScreenSheet = true
                    } label: {
                        Label("Lock Screen Widget", systemImage: "lock.display")
                    }
                    Button {
                        showAddClockSheet = true
                    } label: {
                        Label("Clock Widget", systemImage: "clock")
                    }
                    if viewModel.launcherConfigs.count < LauncherConfig.maxConfigs {
                        Button {
                            showAddLauncherSheet = true
                        } label: {
                            Label("Launcher Grid", systemImage: "rectangle.grid.2x2")
                        }
                    }
                    Button {
                        showRemoteControlSheet = true
                    } label: {
                        Label("Remote Control", systemImage: "network")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            let size = WidgetSize(rawValue: defaultWidgetSize) ?? .systemMedium
            let newConfig = WidgetConfig(size: size)
            NavigationStack {
                WidgetEditorView(configuration: newConfig, isNew: true)
            }
        }
        .sheet(isPresented: $showAddImageSheet) {
            let newConfig = WidgetConfig(
                name: "Code Widget",
                size: .systemSmall,
                widgetKind: .imageSlideshow,
                slides: []
            )
            NavigationStack {
                WidgetEditorView(configuration: newConfig, isNew: true)
            }
        }
        .sheet(isPresented: $showAddLockScreenSheet) {
            let newConfig = WidgetConfig(
                name: "Lock Screen Widget",
                size: .systemSmall,
                items: [WidgetItem()],
                widgetKind: .lockScreen
            )
            NavigationStack {
                WidgetEditorView(configuration: newConfig, isNew: true)
            }
        }
        .sheet(isPresented: $showAddClockSheet) {
            let newConfig = WidgetConfig(
                name: "Clock Widget",
                size: .systemSmall,
                widgetKind: .clock,
                clockDigitPosition: .hour,
                clockFontSize: 80
            )
            NavigationStack {
                WidgetEditorView(configuration: newConfig, isNew: true)
            }
        }
        .sheet(isPresented: $showAddLauncherSheet) {
            NavigationStack {
                LauncherEditorView(config: LauncherConfig(), isNew: true)
                    .environmentObject(viewModel)
            }
        }
        .sheet(isPresented: $showRemoteControlSheet, onDismiss: {
            hasRemoteControl = !SharedStorage.shared.allowedSSID.isEmpty
        }) {
            NavigationStack {
                RemoteControlEditorView()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Widgets Yet")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Tap + to create your first widget")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Launcher Row View

struct LauncherRowView: View {
    let config: LauncherConfig
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "rectangle.grid.2x2")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Launcher Grid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(config.items.count) item\(config.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Widget Row View

struct WidgetRowView: View {
    let configuration: WidgetConfig
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            WidgetPreviewView(configuration: configuration, size: CGSize(width: 60, height: 60))
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(configuration.widgetKind?.displayName ?? configuration.size.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if configuration.widgetKind == .lockScreen,
                   let action = configuration.items.first?.action {
                    Text(action.displayName ?? action.payload)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    let itemCount = configuration.widgetKind == .imageSlideshow
                        ? (configuration.slides?.count ?? 0)
                        : configuration.items.count
                    let unit = configuration.widgetKind == .imageSlideshow ? "code" : "item"
                    Text("\(itemCount) \(unit)\(itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Widget Preview

struct WidgetPreviewView: View {
    let configuration: WidgetConfig
    let size: CGSize

    var body: some View {
        GeometryReader { geometry in
            let itemSize = calculateItemSize(containerSize: geometry.size)

            ZStack {
                configuration.backgroundColor.swiftUIColor
                    .opacity(configuration.backgroundOpacity)

                if configuration.widgetKind == .imageSlideshow {
                    Color.white
                    let slides = configuration.slides ?? []
                    let idx = min(configuration.currentSlideIndex ?? 0, max(0, slides.count - 1))
                    if slides.isEmpty {
                        Image(systemName: "qrcode")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    } else {
                        let slide = slides[idx]
                        if let content = slide.qrCodeContent, !content.isEmpty {
                            QRCodeCanvasView(content: content)
                        } else if let content = slide.barcodeContent, !content.isEmpty {
                            BarcodeCanvasView(content: content)
                                .frame(maxWidth: .infinity)
                                .frame(height: geometry.size.height * 0.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Image(systemName: "qrcode")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if configuration.widgetKind == .lockScreen {
                    if let item = configuration.items.first,
                       item.displayType == .icon, let symbolName = item.sfSymbolName {
                        if symbolName.hasPrefix("wi_") {
                            Image(symbolName)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.5)
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        } else {
                            Image(systemName: symbolName)
                                .font(.system(size: geometry.size.width * 0.4))
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        }
                    } else {
                        Image(systemName: "lock.display")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else if configuration.widgetKind == .clock {
                    clockDigitsPreview
                } else if configuration.items.isEmpty {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: configuration.size.columns), spacing: 1) {
                        ForEach(Array(configuration.truncatedItems.enumerated()), id: \.element.id) { _, item in
                            ItemPreviewView(item: item, size: itemSize)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var clockDigitsPreview: some View {
        let position = configuration.clockDigitPosition ?? .hour
        let cal = Calendar.current
        let now = Date()
        let h24 = cal.component(.hour, from: now)
        let min = cal.component(.minute, from: now)
        let displayHour = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
        let fontSize = configuration.clockFontSize ?? 80
        if position == .time {
            let hourTens  = String((displayHour / 10) % 10)
            let hourUnits = String(displayHour % 10)
            let minTens   = String((min / 10) % 10)
            let minUnits  = String(min % 10)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(hourTens)
                        .font(clockPreviewFont(size: fontSize))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    Text(hourUnits)
                        .font(clockPreviewFont(size: fontSize))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 0) {
                    Text(minTens)
                        .font(clockPreviewFont(size: fontSize))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    Text(minUnits)
                        .font(clockPreviewFont(size: fontSize))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, -20)
            .padding(.vertical, -16)
        } else {
            let value = position == .hour ? displayHour : min
            let tens = String((value / 10) % 10)
            let units = String(value % 10)
            HStack(spacing: 0) {
                Text(tens)
                    .font(clockPreviewFont(size: fontSize))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                Text(units)
                    .font(clockPreviewFont(size: fontSize))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(.horizontal, -20)
            .padding(.vertical, -16)
            .offset(x: -2)
        }
    }

    private func clockPreviewFont(size: CGFloat) -> Font {
        if let name = configuration.clockFontName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .bold)
    }

    private func calculateItemSize(containerSize: CGSize) -> CGSize {
        let columns = configuration.size.columns
        let spacing: CGFloat = 2
        let availableWidth = containerSize.width - (CGFloat(columns - 1) * spacing)
        let itemWidth = availableWidth / CGFloat(columns)
        return CGSize(width: itemWidth, height: itemWidth)
    }
}

struct ItemPreviewView: View {
    let item: WidgetItem
    let size: CGSize

    var body: some View {
        ZStack {
            item.backgroundColor.swiftUIColor.opacity(item.backgroundOpacity)

            if item.displayType == .qrCode, let content = item.qrCodeContent, !content.isEmpty,
               let qr = UIImage.qrCode(from: content, size: max(size.width, 60) * 2) {
                ZStack {
                    Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().padding(2)
                    if let label = item.qrCodeLabel, !label.isEmpty {
                        Text(label)
                            .font(.system(size: max(item.qrCodeLabelSize * size.width / 40, 5), weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.4)
                            .padding(.horizontal, 2).padding(.vertical, 1)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            } else if item.displayType == .image, let fn = item.customImageFilename,
                      let img = (item.imageData.flatMap(UIImage.init) ?? SharedStorage.shared.loadWidgetImage(filename: fn)) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: size.width, height: size.height).clipped()
            } else if item.displayType == .icon {
                if let symbolName = item.sfSymbolName {
                    if symbolName.hasPrefix("wi_") {
                        Image(symbolName)
                            .resizable().renderingMode(.template).scaledToFit()
                            .frame(width: size.width * 0.55, height: size.width * 0.55)
                            .foregroundStyle(item.foregroundColor.swiftUIColor)
                    } else {
                        Image(systemName: symbolName)
                            .font(.system(size: size.width * 0.5))
                            .foregroundStyle(item.foregroundColor.swiftUIColor)
                    }
                }
            } else {
                Text(item.customText ?? "")
                    .font(.system(size: size.width * 0.25))
                    .foregroundStyle(item.foregroundColor.swiftUIColor)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WidgetListView()
            .environmentObject(WidgetViewModel())
    }
    .preferredColorScheme(.dark)
}
