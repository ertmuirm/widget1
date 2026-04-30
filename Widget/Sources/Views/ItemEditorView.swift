import SwiftUI
import PhotosUI

/// Editor for individual widget items
struct ItemEditorView: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var item: WidgetItem

    @State private var showSymbolPicker = false
    @State private var showActionPicker = false
    @State private var showAppActionPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false

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
            } else if item.displayType == .image {
                // Image section (for lock screen / item-level images)
                Section("Image") {
                    if let filename = item.customImageFilename,
                       let image = SharedStorage.shared.loadWidgetImage(filename: filename) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }

                    PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 1, matching: .images) {
                        Label(item.customImageFilename == nil ? "Choose from Photos" : "Replace Image",
                              systemImage: "photo.on.rectangle")
                    }
                    .foregroundStyle(.white)
                    .onChange(of: photoPickerItems) { items in
                        if let first = items.first { loadPhotoItem(first) }
                        photoPickerItems = []
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label(item.customImageFilename == nil ? "Import from Files" : "Replace from Files",
                              systemImage: "folder")
                    }
                    .foregroundStyle(.white)

                    if item.customImageFilename != nil {
                        Button(role: .destructive) {
                            if let fn = item.customImageFilename {
                                SharedStorage.shared.deleteWidgetImage(filename: fn)
                            }
                            item.customImageFilename = nil
                        } label: {
                            Label("Remove Image", systemImage: "trash")
                        }
                        .foregroundStyle(.red)
                    }
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
                            .tint(.gray)
                    }
                }
            }

            // Colors section (not shown for image type)
            if item.displayType != .image {
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
                            .tint(.gray)
                    }
                }
            }

            // Action section
            Section("Action") {
                Button {
                    showActionPicker = true
                } label: {
                    HStack {
                        Text("Action Type")
                        Spacer()
                        Text(item.action?.type.displayName ?? "None")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.white)

                if let action = item.action {
                    switch action.type {
                    case .urlScheme:
                        TextField("URL (e.g. concurmobile://)", text: Binding(
                            get: { action.payload },
                            set: { item.action?.payload = $0 }
                        ))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    case .appIntent:
                        Button {
                            showAppActionPicker = true
                        } label: {
                            HStack {
                                Text("App Action")
                                Spacer()
                                Text(action.displayName ?? (action.payload.isEmpty ? "Select…" : action.payload))
                                    .foregroundStyle(action.payload.isEmpty ? .tertiary : .secondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.white)

                    case .shortcut:
                        TextField("Shortcut Name", text: Binding(
                            get: { action.payload },
                            set: { item.action?.payload = $0 }
                        ))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()

                    case .call:
                        // 0 = Phone, 1 = WhatsApp Audio, 2 = WhatsApp Video
                        let callMethod: Int = {
                            if action.payload.hasPrefix("whatsapp://videocall") { return 2 }
                            if action.payload.hasPrefix("whatsapp://call")      { return 1 }
                            return 0
                        }()
                        let rawNumber: String = {
                            if action.payload.hasPrefix("tel:") {
                                return String(action.payload.dropFirst(4))
                            }
                            // Payloads now stored with leading + (E.164)
                            if action.payload.hasPrefix("whatsapp://call?phone=") {
                                return String(action.payload.dropFirst("whatsapp://call?phone=".count))
                            }
                            if action.payload.hasPrefix("whatsapp://videocall?phone=") {
                                return String(action.payload.dropFirst("whatsapp://videocall?phone=".count))
                            }
                            return ""
                        }()

                        TextField("Phone number (+15551234567)", text: Binding(
                            get: { rawNumber },
                            set: { val in
                                let cleaned = val.filter { $0.isNumber || $0 == "+" }
                                item.action?.payload = makeCallPayload(number: cleaned, method: callMethod)
                            }
                        ))
                        .foregroundStyle(.white)
                        .keyboardType(.phonePad)

                        Picker("Call via", selection: Binding(
                            get: { callMethod },
                            set: { newMethod in
                                let cleaned = rawNumber.filter { $0.isNumber || $0 == "+" }
                                item.action?.payload = makeCallPayload(number: cleaned, method: newMethod)
                            }
                        )) {
                            Text("Phone App").tag(0)
                            Text("WhatsApp Audio").tag(1)
                            Text("WhatsApp Video").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        item.action = nil
                    } label: {
                        Label("Remove Action", systemImage: "trash")
                    }
                    .foregroundStyle(.gray)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Item Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
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
        .sheet(isPresented: $showAppActionPicker) {
            AppActionPickerView { urlString, displayLabel in
                item.action?.payload = urlString
                item.action?.displayName = displayLabel
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                loadImageFile(url)
            }
        }
    }

    // MARK: - Call payload builder

    /// Builds the stored payload for a .call action.
    /// Phone: `tel:+NUMBER`  |  WhatsApp audio: `whatsapp://call?phone=NUMBER`
    ///                          WhatsApp video: `whatsapp://videocall?phone=NUMBER`
    /// method: 0 = Phone, 1 = WhatsApp Audio, 2 = WhatsApp Video
    private func makeCallPayload(number: String, method: Int) -> String {
        let cleaned = number.filter { $0.isNumber || $0 == "+" }
        // WhatsApp requires E.164 format with leading +
        let e164 = cleaned.isEmpty ? "" : (cleaned.hasPrefix("+") ? cleaned : "+\(cleaned)")
        switch method {
        case 1:  return "whatsapp://call?phone=\(e164)"
        case 2:  return "whatsapp://videocall?phone=\(e164)"
        default: return "tel:\(cleaned)"
        }
    }

    // MARK: - Image loading

    private func loadPhotoItem(_ item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                guard case .success(let data) = result, let data else { return }
                self.saveImageData(data)
            }
        }
    }

    private func loadImageFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        saveImageData(data)
    }

    private func saveImageData(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        // Use PNG for .image display type to preserve alpha transparency
        let saveData: Data?
        let ext: String
        if item.displayType == .image {
            saveData = image.pngData()
            ext = "png"
        } else {
            saveData = image.jpegData(compressionQuality: 0.8)
            ext = "jpg"
        }
        guard let saveData else { return }
        if let old = item.customImageFilename {
            SharedStorage.shared.deleteWidgetImage(filename: old)
        }
        let filename = "\(UUID().uuidString).\(ext)"
        SharedStorage.shared.saveWidgetImage(saveData, filename: filename)
        item.customImageFilename = filename
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
        searchText.isEmpty ? symbols : symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
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
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("SF Symbols")
            .searchable(text: $searchText, prompt: "Search symbols")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Action")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
