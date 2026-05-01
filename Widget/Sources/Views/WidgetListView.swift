import SwiftUI

/// List of all widget configurations
struct WidgetListView: View {

    @EnvironmentObject var viewModel: WidgetViewModel
    @AppStorage("defaultWidgetSize") private var defaultWidgetSize = WidgetSize.systemMedium.rawValue
    @State private var showAddSheet = false
    @State private var showAddImageSheet = false
    @State private var showAddLockScreenSheet = false
    @State private var showSettingsSheet = false

    var body: some View {
        List {
            if viewModel.configurations.isEmpty {
                emptyView
            } else {
                ForEach(viewModel.configurations) { config in
                    ZStack {
                        // Invisible NavigationLink drives navigation
                        NavigationLink(value: config.id) { EmptyView() }.opacity(0)
                        WidgetRowView(configuration: config) {
                            if let idx = viewModel.configurations.firstIndex(where: { $0.id == config.id }) {
                                viewModel.deleteConfiguration(at: IndexSet([idx]))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Widgets")
        .navigationDestination(for: UUID.self) { id in
            if let config = viewModel.configurations.first(where: { $0.id == id }) {
                WidgetEditorView(configuration: config)
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
                        Label("Image Widget", systemImage: "photo.on.rectangle.angled")
                    }
                    Button {
                        showAddLockScreenSheet = true
                    } label: {
                        Label("Lock Screen Widget", systemImage: "lock.display")
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

                let itemCount = configuration.widgetKind == .imageSlideshow
                    ? (configuration.slides?.count ?? 0)
                    : configuration.items.count
                let unit = configuration.widgetKind == .imageSlideshow ? "image" : "item"
                Text("\(itemCount) \(unit)\(itemCount == 1 ? "" : "s")")
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
                    let slides = configuration.slides ?? []
                    let idx = min(configuration.currentSlideIndex ?? 0, max(0, slides.count - 1))
                    if slides.isEmpty {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    } else {
                        let slide = slides[idx]
                        if slide.isQRCode, let content = slide.qrCodeContent, !content.isEmpty,
                           let qr = UIImage.qrCode(from: content, size: 120) {
                            ZStack {
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                if let label = slide.qrCodeLabel, !label.isEmpty {
                                    Text(label)
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 2)
                                        .padding(.vertical, 1)
                                        .background(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                }
                            }
                        } else {
                            let img = slide.imageData.flatMap { UIImage(data: $0) }
                                ?? SharedStorage.shared.loadWidgetImage(filename: slide.filename)
                            if let img {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .scaleEffect(CGFloat(slide.scale))
                            } else {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
