import SwiftUI

/// Widget editor for creating and editing widget configurations
struct WidgetEditorView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: WidgetViewModel
    
    @State var configuration: WidgetConfig
    var isNew: Bool = false
    
    @State private var selectedItemIndex: Int?
    @State private var showItemEditor = false
    
    var body: some View {
        List {
            // Name section
            Section("Widget Name") {
                TextField("Name", text: $configuration.name)
                    .foregroundStyle(.white)
            }
            
            // Size section
            Section("Widget Size") {
                Picker("Size", selection: $configuration.size) {
                    ForEach(WidgetSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Items section
            Section("Items (\(configuration.items.count)/\(configuration.maxItems))") {
                if configuration.items.isEmpty {
                    Button {
                        addItem()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .foregroundStyle(.blue)
                } else {
                    ForEach(Array(configuration.items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            selectedItemIndex = index
                            showItemEditor = true
                        } label: {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete { indexSet in
                        configuration.items.remove(atOffsets: indexSet)
                    }
                    
                    if configuration.items.count < configuration.maxItems {
                        Button {
                            addItem()
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            
            // Background section
            Section("Background") {
                HStack {
                    Text("Color")
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { configuration.backgroundColor.swiftUIColor },
                        set: { configuration.backgroundColor = CodableColor($0) }
                    ))
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Opacity: \(Int(configuration.backgroundOpacity * 100))%")
                    Slider(value: $configuration.backgroundOpacity, in: 0...1)
                        .tint(.white)
                }
            }
            
            // Preview section
            Section("Preview") {
                WidgetPreviewView(configuration: configuration, size: CGSize(width: 300, height: 300))
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isNew ? "New Widget" : "Edit Widget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveConfiguration()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showItemEditor) {
            if let index = selectedItemIndex {
                NavigationStack {
                    ItemEditorView(item: $configuration.items[index])
                }
            }
        }
    }
    
    private func addItem() {
        guard configuration.items.count < configuration.maxItems else { return }
        
        let newItem = WidgetItem()
        configuration.items.append(newItem)
        selectedItemIndex = configuration.items.count - 1
        showItemEditor = true
    }
    
    private func saveConfiguration() {
        if isNew {
            viewModel.addConfiguration(configuration)
        } else {
            viewModel.updateConfiguration(configuration)
        }
    }
}

// MARK: - Item Row View

struct ItemRowView: View {
    let item: WidgetItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Item preview
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.backgroundColor.swiftUIColor.opacity(item.backgroundOpacity))
                    .frame(width: 44, height: 44)
                
                if item.displayType == .icon {
                    if let symbolName = item.sfSymbolName {
                        Image(systemName: symbolName)
                            .font(.title2)
                            .foregroundStyle(item.foregroundColor.swiftUIColor)
                    }
                } else {
                    Text(item.customText ?? "Text")
                        .font(.caption)
                        .foregroundStyle(item.foregroundColor.swiftUIColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayType == .icon ? (item.sfSymbolName ?? "Icon") : (item.customText ?? "Text"))
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let action = item.action {
                    Text(action.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No action")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WidgetEditorView(configuration: WidgetConfig())
    }
    .environmentObject(WidgetViewModel())
    .preferredColorScheme(.dark)
}