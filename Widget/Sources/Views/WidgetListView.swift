import SwiftUI

/// List of all widget configurations
struct WidgetListView: View {
    
    @EnvironmentObject var viewModel: WidgetViewModel
    @State private var showAddSheet = false
    @State private var showSettingsSheet = false
    @State private var showDebugSheet = false
    @State private var showDebugOverlay = false
    
    var body: some View {
        ZStack {
            List {
                if viewModel.configurations.isEmpty {
                    emptyView
                } else {
                    ForEach(viewModel.configurations) { config in
                        NavigationLink(destination: WidgetEditorView(configuration: config)) {
                            WidgetRowView(configuration: config)
                        }
                    }
                    .onDelete(perform: viewModel.deleteConfiguration)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Widgets")
            
            // Floating debug overlay
            if showDebugOverlay {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        DebugOverlayView()
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }
                .background(.ultraThinMaterial)
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
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Debug Overlay") {
                        showDebugOverlay.toggle()
                    }
                    Button("Debug Logs") {
                        showDebugSheet = true
                    }
                } label: {
                    Image(systemName: "doc.text")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            let newConfig = WidgetConfig()
            NavigationStack {
                WidgetEditorView(configuration: newConfig, isNew: true)
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: $showDebugSheet) {
            NavigationStack {
                DebugLogView()
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Widget preview
            WidgetPreviewView(configuration: configuration, size: CGSize(width: 60, height: 60))
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(configuration.size.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\(configuration.items.count) item\(configuration.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
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
                // Background
                configuration.backgroundColor.swiftUIColor
                    .opacity(configuration.backgroundOpacity)
                
                // Items grid
                if configuration.items.isEmpty {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: configuration.size.columns), spacing: 2) {
                        ForEach(Array(configuration.truncatedItems.enumerated()), id: \.element.id) { _, item in
                            ItemPreviewView(item: item, size: itemSize)
                        }
                    }
                    .padding(4)
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
            
            if item.displayType == .icon {
                if let symbolName = item.sfSymbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: size.width * 0.5))
                        .foregroundStyle(item.foregroundColor.swiftUIColor)
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