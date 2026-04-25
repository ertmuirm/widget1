import SwiftUI

/// Editor for individual widget items
struct ItemEditorView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var item: WidgetItem
    
    @State private var showSymbolPicker = false
    @State private var showActionPicker = false
    
    var body: some View {
        List {
            // Display type section
            Section("Display Type") {
                Picker("Type", selection: $item.displayType) {
                    ForEach(DisplayType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Icon section
            if item.displayType == .icon {
                Section("Icon") {
                    Button {
                        showSymbolPicker = true
                    } label: {
                        HStack {
                            Text("SF Symbol")
                            Spacer()
                            if let symbolName = item.sfSymbolName {
                                Image(systemName: symbolName)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.sfSymbolName ?? "Select...")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.white)
                }
            } else {
                // Text section
                Section("Text") {
                    TextField("Text", text: Binding(
                        get: { item.customText ?? "" },
                        set: { item.customText = $0 }
                    ))
                    .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Size: \(Int(item.fontSize))")
                        Slider(value: $item.fontSize, in: 2...30, step: 1)
                            .tint(.white)
                    }
                }
            }
            
            // Colors section
            Section("Colors") {
                HStack {
                    Text("Foreground")
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { item.foregroundColor.swiftUIColor },
                        set: { item.foregroundColor = CodableColor($0) }
                    ))
                    .labelsHidden()
                }
                .foregroundStyle(.white)
                
                HStack {
                    Text("Background")
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { item.backgroundColor.swiftUIColor },
                        set: { item.backgroundColor = CodableColor($0) }
                    ))
                    .labelsHidden()
                }
                .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background Opacity: \(Int(item.backgroundOpacity * 100))%")
                    Slider(value: $item.backgroundOpacity, in: 0...1)
                        .tint(.white)
                }
            }
            
            // Action section
            Section("Action") {
                Button {
                    showActionPicker = true
                } label: {
                    HStack {
                        Text("Action")
                        Spacer()
                        if let action = item.action {
                            Text(action.type.displayName)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select action...")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.white)
                
                if let action = item.action, action.type == .urlScheme {
                    TextField("URL Scheme", text: Binding(
                        get: { action.payload },
                        set: { item.action?.payload = $0 }
                    ))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                
                if let action = item.action, (action.type == .appIntent || action.type == .shortcut) {
                    TextField(action.type == .appIntent ? "App Intent Name" : "Shortcut Name", text: Binding(
                        get: { action.payload },
                        set: { item.action?.payload = $0 }
                    ))
                    .foregroundStyle(.white)
                }
                
                if item.action != nil {
                    Button(role: .destructive) {
                        item.action = nil
                    } label: {
                        Label("Remove Action", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Item Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: Binding(
                get: { item.sfSymbolName ?? "star.fill" },
                set: { item.sfSymbolName = $0 }
            ))
        }
        .sheet(isPresented: $showActionPicker) {
            ActionPickerView(item: $item)
        }
    }
}

// MARK: - Symbol Picker View

struct SymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSymbol: String
    
    @State private var searchText = ""
    
    private let symbols = [
        "star.fill", "house.fill", "gear", "heart.fill", "bolt.fill", "flame.fill",
        "sun.max.fill", "moon.fill", "cloud.fill", "snow", "wind", "drop.fill",
        "leaf.fill", "camera.fill", "mic.fill", "music.note", "phone.fill", "envelope.fill",
        "message.fill", "bell.fill", "tag.fill", "cart.fill", "creditcard.fill", "gift.fill",
        "airplane", "car.fill", "bus.fill", "tram.fill", "bicycle", "figure.walk",
        "figure.run", "sportscourt.fill", "gamecontroller.fill", "paintbrush.fill", "pencil",
        "scissors", "doc.fill", "folder.fill", "trash.fill", "archivebox.fill"
    ]
    
    private var filteredSymbols: [String] {
        if searchText.isEmpty {
            return symbols
        }
        return symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredSymbols, id: \.self) { symbol in
                Button {
                    selectedSymbol = symbol
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: symbol)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(symbol)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if symbol == selectedSymbol {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("SF Symbols")
            .searchable(text: $searchText, prompt: "Search symbols")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Action Picker View

struct ActionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var item: WidgetItem
    
    var body: some View {
        List {
            ForEach(ActionType.allCases, id: \.self) { actionType in
                let isSelected = item.action?.type == actionType
                
                Button {
                    item.action = WidgetAction(type: actionType, payload: "")
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(actionType.displayName)
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text(actionType.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Action")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ItemEditorView(item: .constant(WidgetItem()))
    }
    .preferredColorScheme(.dark)
}