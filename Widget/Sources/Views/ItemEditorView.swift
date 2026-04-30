import SwiftUI
import PhotosUI
import Vision

/// Editor for individual widget items
struct ItemEditorView: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var item: WidgetItem

    @State private var showSymbolPicker = false
    @State private var showActionPicker = false
    @State private var showAppActionPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var qrScanPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var scanError: String?

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
                            Text("Icon")
                            Spacer()
                            if let symbolName = item.sfSymbolName {
                                if symbolName.hasPrefix("wi_") {
                                    Image(symbolName)
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: symbolName)
                                        .foregroundStyle(.secondary)
                                }
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
            } else if item.displayType == .qrCode {
                Section {
                    TextField("URL or text to encode", text: Binding(
                        get: { item.qrCodeContent ?? "" },
                        set: { item.qrCodeContent = $0.isEmpty ? nil : $0 }
                    ))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    // Scan QR / barcode from a photo
                    PhotosPicker(selection: $qrScanPickerItems, maxSelectionCount: 1, matching: .images) {
                        Label("Scan from Image", systemImage: "qrcode.viewfinder")
                    }
                    .foregroundStyle(.white)
                    .onChange(of: qrScanPickerItems) { items in
                        if let first = items.first { scanQRFromPhoto(first) }
                        qrScanPickerItems = []
                    }

                    if let err = scanError {
                        Text(err).font(.caption).foregroundStyle(.orange)
                    }
                } header: {
                    Text("QR Code Content")
                } footer: {
                    Text("Type a URL or text, or pick an image containing a QR/barcode to extract its content automatically.")
                        .font(.caption)
                }

                // Live QR preview
                if let content = item.qrCodeContent, !content.isEmpty,
                   let qr = UIImage.qrCode(from: content, size: 300) {
                    Section("Preview") {
                        VStack(spacing: 6) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .frame(maxWidth: .infinity)
                            if let label = item.qrCodeLabel, !label.isEmpty {
                                Text(label)
                                    .font(.system(size: item.qrCodeLabelSize, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                }

                Section("Label (optional)") {
                    TextField("Label shown below QR code", text: Binding(
                        get: { item.qrCodeLabel ?? "" },
                        set: { item.qrCodeLabel = $0.isEmpty ? nil : $0 }
                    ))
                    .foregroundStyle(.white)

                    if item.qrCodeLabel?.isEmpty == false {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Label Font Size: \(Int(item.qrCodeLabelSize)) pt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $item.qrCodeLabelSize, in: 6...24, step: 1)
                                .tint(.gray)
                        }
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

            // Colors section (not shown for image or QR code type)
            if item.displayType != .image && item.displayType != .qrCode {
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
                            // WhatsApp payloads store digits-only; prefix + for display
                            if action.payload.hasPrefix("whatsapp://call?phone=") {
                                let d = String(action.payload.dropFirst("whatsapp://call?phone=".count))
                                    .filter { $0.isNumber }
                                return d.isEmpty ? "" : "+\(d)"
                            }
                            if action.payload.hasPrefix("whatsapp://videocall?phone=") {
                                let d = String(action.payload.dropFirst("whatsapp://videocall?phone=".count))
                                    .filter { $0.isNumber }
                                return d.isEmpty ? "" : "+\(d)"
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
    /// Phone: `tel:+NUMBER`
    /// WhatsApp audio: `whatsapp://call?phone=DIGITS`
    /// WhatsApp video: `whatsapp://videocall?phone=DIGITS`
    /// WhatsApp uses digits-only (no + prefix); + in URL query strings is decoded
    /// as a space by WhatsApp's URL parser, causing "invalid call link".
    private func makeCallPayload(number: String, method: Int) -> String {
        let cleaned = number.filter { $0.isNumber || $0 == "+" }
        let digits = cleaned.filter { $0.isNumber }
        switch method {
        case 1:  return "whatsapp://call?phone=\(digits)"
        case 2:  return "whatsapp://videocall?phone=\(digits)"
        default:
            let e164 = cleaned.isEmpty ? "" : (cleaned.hasPrefix("+") ? cleaned : "+\(cleaned)")
            return "tel:\(e164)"
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
        let downsized = image.downsizedForWidget()
        // PNG preserves alpha for .image display type; JPEG for others
        let saveData: Data?
        let ext: String
        if item.displayType == .image {
            saveData = downsized.pngData()
            ext = "png"
        } else {
            saveData = downsized.jpegData(compressionQuality: 0.75)
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

    // MARK: - QR/barcode scan from photo

    private func scanQRFromPhoto(_ photoItem: PhotosPickerItem) {
        scanError = nil
        photoItem.loadTransferable(type: Data.self) { result in
            guard case .success(let data?) = result,
                  let ciImage = CIImage(data: data) else {
                DispatchQueue.main.async { self.scanError = "Could not load image." }
                return
            }
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
                DispatchQueue.main.async {
                    if let payload = request.results?.first?.payloadStringValue {
                        self.item.qrCodeContent = payload
                        self.scanError = nil
                    } else {
                        self.scanError = "No QR code or barcode detected in the image."
                    }
                }
            }
        }
    }
}

// MARK: - Symbol Picker View

struct SymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSymbol: String

    @State private var searchText = ""

    private let sfSymbols = [
        "star.fill", "house.fill", "gear", "heart.fill", "bolt.fill", "flame.fill",
        "sun.max.fill", "moon.fill", "cloud.fill", "snow", "wind", "drop.fill",
        "leaf.fill", "camera.fill", "mic.fill", "music.note", "phone.fill", "envelope.fill",
        "message.fill", "bell.fill", "tag.fill", "cart.fill", "creditcard.fill", "gift.fill",
        "airplane", "car.fill", "bus.fill", "tram.fill", "bicycle", "figure.walk",
        "figure.run", "sportscourt.fill", "gamecontroller.fill", "paintbrush.fill", "pencil",
        "scissors", "doc.fill", "folder.fill", "trash.fill", "archivebox.fill",
        "clock.fill", "timer", "calendar", "map.fill", "location.fill",
        "wifi", "lock.fill", "eye.fill", "sparkle", "wand.and.stars"
    ]

    private var filteredSFSymbols: [String] {
        searchText.isEmpty ? sfSymbols : sfSymbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredCustomIcons: [(name: String, label: String)] {
        searchText.isEmpty ? CustomIcons.all :
            CustomIcons.all.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.label.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredCustomIcons.isEmpty {
                    Section("Custom Icons") {
                        ForEach(filteredCustomIcons, id: \.name) { icon in
                            symbolRow(name: icon.name, label: icon.label, isCustom: true)
                        }
                    }
                }
                if !filteredSFSymbols.isEmpty {
                    Section("SF Symbols") {
                        ForEach(filteredSFSymbols, id: \.self) { symbol in
                            symbolRow(name: symbol, label: symbol, isCustom: false)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose Icon")
            .searchable(text: $searchText, prompt: "Search icons")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func symbolRow(name: String, label: String, isCustom: Bool) -> some View {
        Button {
            selectedSymbol = name
            dismiss()
        } label: {
            HStack {
                Group {
                    if isCustom {
                        Image(name)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: name)
                            .font(.title2)
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(label)
                    .foregroundStyle(.white)

                Spacer()

                if name == selectedSymbol {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.gray)
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
