import SwiftUI
import PhotosUI
import Vision

/// Editor for individual widget items
struct ItemEditorView: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var item: WidgetItem
    /// Pass the widget kind so QR code is only offered for image-widget items.
    var widgetKind: WidgetKind? = nil

    @State private var showSymbolPicker = false
    @State private var showActionPicker = false
    @State private var showAppActionPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var qrScanPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var fileImporterPurpose: FileImporterPurpose? = nil
    @State private var scanError: String?

    private enum FileImporterPurpose { case loadImage, scanQR }

    private var allowedDisplayTypes: [DisplayType] {
        if widgetKind == .imageSlideshow {
            return DisplayType.allCases
        }
        // Grid and lock screen widgets: remove image upload (causes entire widget
        // to fail to render) and QR code (only supported in image slideshow).
        return DisplayType.allCases.filter { $0 != .qrCode && $0 != .image }
    }

    var body: some View {
        List {
            // Display type section
            Section("Display Type") {
                Picker("Type", selection: $item.displayType) {
                    ForEach(allowedDisplayTypes, id: \.self) { type in
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
                        fileImporterPurpose = .loadImage
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

                    // Scan QR / barcode from Photos
                    PhotosPicker(selection: $qrScanPickerItems, maxSelectionCount: 1, matching: .images) {
                        Label("Scan from Photos", systemImage: "qrcode.viewfinder")
                    }
                    .foregroundStyle(.white)
                    .onChange(of: qrScanPickerItems) { items in
                        if let first = items.first { scanQRFromPhoto(first) }
                        qrScanPickerItems = []
                    }

                    // Scan QR / barcode from Files
                    Button {
                        fileImporterPurpose = .scanQR
                        showFileImporter = true
                    } label: {
                        Label("Scan from Files", systemImage: "folder.badge.questionmark")
                    }
                    .foregroundStyle(.white)

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
                        ZStack {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .frame(maxWidth: .infinity)
                            if let label = item.qrCodeLabel, !label.isEmpty {
                                Text(label)
                                    .font(.system(size: item.qrCodeLabelSize, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                }

                Section("Center Label (optional)") {
                    TextField("Label in center of QR code", text: Binding(
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
            // Capture purpose before clearing — showFileImporter going false would
            // otherwise race with a binding-set nil that kills fileImporterPurpose.
            let purpose = fileImporterPurpose
            fileImporterPurpose = nil
            if case .success(let urls) = result, let url = urls.first {
                if purpose == .loadImage { loadImageFile(url) }
                else if purpose == .scanQR { scanQRFromFile(url) }
            }
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
        // Embed data in item so it crosses the process boundary on SideStore
        item.imageData = saveData
    }

    // MARK: - QR/barcode scan

    private func scanQRFromPhoto(_ photoItem: PhotosPickerItem) {
        scanError = nil
        photoItem.loadTransferable(type: Data.self) { result in
            guard case .success(let data?) = result,
                  let ciImage = CIImage(data: data) else {
                DispatchQueue.main.async { self.scanError = "Could not load image." }
                return
            }
            performQRScan(on: ciImage)
        }
    }

    private func scanQRFromFile(_ url: URL) {
        scanError = nil
        guard url.startAccessingSecurityScopedResource() else {
            scanError = "Could not access file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let ciImage = CIImage(data: data) else {
            scanError = "Could not load image."
            return
        }
        performQRScan(on: ciImage)
    }

    private func performQRScan(on ciImage: CIImage) {
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

// MARK: - Symbol Picker View

private struct SymbolEntry: Identifiable {
    let name: String
    let label: String
    var id: String { name }
}

struct SymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSymbol: String

    @State private var searchText = ""

    // ~100 modern flat SF Symbols organised by searchable label.
    // Grid shows icons only; labels power the search.
    private let sfSymbolEntries: [SymbolEntry] = [
        // Communication
        SymbolEntry(name: "phone.fill",             label: "phone call"),
        SymbolEntry(name: "message.fill",            label: "message sms"),
        SymbolEntry(name: "envelope.fill",           label: "email mail"),
        SymbolEntry(name: "bubble.left.fill",        label: "chat bubble"),
        SymbolEntry(name: "bell.fill",               label: "notification bell alert"),
        SymbolEntry(name: "mic.fill",                label: "microphone mic"),
        SymbolEntry(name: "video.fill",              label: "video call facetime"),
        SymbolEntry(name: "antenna.radiowaves.left.and.right", label: "radio signal broadcast"),
        // Media & Entertainment
        SymbolEntry(name: "play.fill",               label: "play media"),
        SymbolEntry(name: "music.note",              label: "music song"),
        SymbolEntry(name: "headphones",              label: "headphones audio"),
        SymbolEntry(name: "camera.fill",             label: "camera photo"),
        SymbolEntry(name: "photo.fill",              label: "photo image picture"),
        SymbolEntry(name: "film.fill",               label: "film movie video"),
        SymbolEntry(name: "tv.fill",                 label: "television tv screen"),
        SymbolEntry(name: "gamecontroller.fill",     label: "game controller"),
        SymbolEntry(name: "airpods.gen3",            label: "airpods earbuds"),
        SymbolEntry(name: "speaker.wave.2.fill",     label: "speaker volume sound"),
        // Productivity & Documents
        SymbolEntry(name: "doc.fill",                label: "document file"),
        SymbolEntry(name: "doc.text.fill",           label: "text document notes"),
        SymbolEntry(name: "folder.fill",             label: "folder directory"),
        SymbolEntry(name: "calendar",                label: "calendar date schedule"),
        SymbolEntry(name: "clock.fill",              label: "clock time"),
        SymbolEntry(name: "timer",                   label: "timer stopwatch"),
        SymbolEntry(name: "pencil",                  label: "pencil edit write"),
        SymbolEntry(name: "bookmark.fill",           label: "bookmark save"),
        SymbolEntry(name: "tag.fill",                label: "tag label"),
        SymbolEntry(name: "checkmark.circle.fill",   label: "done check complete"),
        SymbolEntry(name: "list.bullet",             label: "list tasks"),
        SymbolEntry(name: "note.text",               label: "note memo"),
        SymbolEntry(name: "archivebox.fill",         label: "archive box"),
        SymbolEntry(name: "tray.fill",               label: "inbox tray"),
        // Finance & Shopping
        SymbolEntry(name: "creditcard.fill",         label: "credit card payment"),
        SymbolEntry(name: "dollarsign.circle.fill",  label: "dollar money finance"),
        SymbolEntry(name: "banknote.fill",           label: "banknote cash money"),
        SymbolEntry(name: "chart.line.uptrend.xyaxis", label: "chart trend stocks"),
        SymbolEntry(name: "chart.bar.fill",          label: "bar chart analytics"),
        SymbolEntry(name: "building.columns.fill",   label: "bank building finance"),
        SymbolEntry(name: "cart.fill",               label: "shopping cart"),
        SymbolEntry(name: "bag.fill",                label: "shopping bag"),
        SymbolEntry(name: "gift.fill",               label: "gift present"),
        SymbolEntry(name: "qrcode",                  label: "qr code scan"),
        // Health & Fitness
        SymbolEntry(name: "heart.fill",              label: "heart health love"),
        SymbolEntry(name: "figure.walk",             label: "walk steps"),
        SymbolEntry(name: "figure.run",              label: "run jog"),
        SymbolEntry(name: "figure.yoga",             label: "yoga stretch"),
        SymbolEntry(name: "dumbbell.fill",           label: "gym workout dumbbell"),
        SymbolEntry(name: "lungs.fill",              label: "lungs breathing"),
        SymbolEntry(name: "pills.fill",              label: "pills medicine"),
        SymbolEntry(name: "stethoscope",             label: "stethoscope doctor"),
        SymbolEntry(name: "bandage.fill",            label: "bandage first aid"),
        SymbolEntry(name: "fork.knife",              label: "food restaurant meal"),
        SymbolEntry(name: "cup.and.saucer.fill",     label: "coffee cup drink"),
        SymbolEntry(name: "wineglass",               label: "wine glass drink"),
        // Transportation & Travel
        SymbolEntry(name: "car.front.fill",          label: "car vehicle drive"),
        SymbolEntry(name: "airplane",                label: "airplane flight travel"),
        SymbolEntry(name: "ferry.fill",              label: "ferry boat ship"),
        SymbolEntry(name: "bicycle",                 label: "bicycle bike cycle"),
        SymbolEntry(name: "scooter",                 label: "scooter moped"),
        SymbolEntry(name: "bus.fill",                label: "bus public transport"),
        SymbolEntry(name: "tram.fill",               label: "tram train metro"),
        SymbolEntry(name: "suitcase.fill",           label: "suitcase luggage travel"),
        SymbolEntry(name: "fuelpump.fill",           label: "fuel petrol gas station"),
        SymbolEntry(name: "parkingsign.circle.fill", label: "parking"),
        // Home & Smart Home
        SymbolEntry(name: "house.fill",              label: "home house"),
        SymbolEntry(name: "lightbulb.fill",          label: "light bulb idea"),
        SymbolEntry(name: "fan.fill",                label: "fan air"),
        SymbolEntry(name: "lock.fill",               label: "lock security"),
        SymbolEntry(name: "key.fill",                label: "key"),
        SymbolEntry(name: "door.left.hand.closed",   label: "door entry"),
        SymbolEntry(name: "washer.fill",             label: "washer laundry"),
        SymbolEntry(name: "bed.double.fill",         label: "bed bedroom sleep"),
        SymbolEntry(name: "sofa.fill",               label: "sofa couch living room"),
        SymbolEntry(name: "trash.fill",              label: "trash delete remove"),
        // Devices & Tech
        SymbolEntry(name: "iphone",                  label: "iphone mobile phone"),
        SymbolEntry(name: "laptopcomputer",          label: "laptop macbook computer"),
        SymbolEntry(name: "desktopcomputer",         label: "desktop mac computer"),
        SymbolEntry(name: "wifi",                    label: "wifi internet wireless"),
        SymbolEntry(name: "bolt.fill",               label: "bolt power energy"),
        SymbolEntry(name: "gear",                    label: "settings gear configure"),
        SymbolEntry(name: "cpu.fill",                label: "cpu processor chip"),
        SymbolEntry(name: "externaldrive.fill",      label: "drive storage"),
        SymbolEntry(name: "printer.fill",            label: "printer print"),
        SymbolEntry(name: "paperclip",               label: "attachment paperclip"),
        // Nature & Weather
        SymbolEntry(name: "sun.max.fill",            label: "sun sunny"),
        SymbolEntry(name: "moon.fill",               label: "moon night"),
        SymbolEntry(name: "cloud.fill",              label: "cloud cloudy"),
        SymbolEntry(name: "cloud.rain.fill",         label: "rain shower"),
        SymbolEntry(name: "snowflake",               label: "snow cold winter"),
        SymbolEntry(name: "wind",                    label: "wind breeze"),
        SymbolEntry(name: "flame.fill",              label: "fire flame"),
        SymbolEntry(name: "leaf.fill",               label: "leaf nature eco"),
        SymbolEntry(name: "tree.fill",               label: "tree park nature"),
        SymbolEntry(name: "drop.fill",               label: "water drop rain"),
        SymbolEntry(name: "mountain.2.fill",         label: "mountain hiking"),
        // Security & Privacy
        SymbolEntry(name: "shield.fill",             label: "shield protection secure"),
        SymbolEntry(name: "eye.fill",                label: "eye view"),
        SymbolEntry(name: "faceid",                  label: "face id biometric"),
        SymbolEntry(name: "hand.raised.fill",        label: "privacy stop"),
        // People & Social
        SymbolEntry(name: "person.fill",             label: "person user"),
        SymbolEntry(name: "person.2.fill",           label: "group team people"),
        SymbolEntry(name: "person.crop.circle.fill", label: "profile avatar account"),
        SymbolEntry(name: "star.fill",               label: "star favourite"),
        SymbolEntry(name: "hand.thumbsup.fill",      label: "thumbs up like"),
        SymbolEntry(name: "globe",                   label: "globe world internet"),
        SymbolEntry(name: "safari.fill",             label: "safari browser compass"),
        SymbolEntry(name: "map.fill",                label: "map navigate"),
        SymbolEntry(name: "location.fill",           label: "location gps pin"),
        // Misc
        SymbolEntry(name: "wand.and.stars",          label: "magic wand effects"),
        SymbolEntry(name: "sparkle",                 label: "sparkle shine"),
        SymbolEntry(name: "paintbrush.fill",         label: "paint brush design"),
        SymbolEntry(name: "scissors",                label: "scissors cut"),
        SymbolEntry(name: "magnifyingglass",         label: "search magnify"),
        SymbolEntry(name: "square.grid.2x2.fill",    label: "grid apps"),
        SymbolEntry(name: "ellipsis.circle.fill",    label: "more options"),
        SymbolEntry(name: "waveform",                label: "waveform audio signal"),
    ]

    private let gridColumns = [GridItem(.adaptive(minimum: 56, maximum: 72))]

    private var filteredSFEntries: [SymbolEntry] {
        guard !searchText.isEmpty else { return sfSymbolEntries }
        let q = searchText.lowercased()
        return sfSymbolEntries.filter {
            $0.label.localizedCaseInsensitiveContains(q) ||
            $0.name.localizedCaseInsensitiveContains(q)
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !filteredCustomIcons.isEmpty {
                        iconSection(title: "Custom Icons") {
                            ForEach(filteredCustomIcons, id: \.name) { icon in
                                iconCell(name: icon.name, isCustom: true)
                            }
                        }
                    }
                    if !filteredSFEntries.isEmpty {
                        iconSection(title: "Icons") {
                            ForEach(filteredSFEntries) { entry in
                                iconCell(name: entry.name, isCustom: false)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search icons")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func iconSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            LazyVGrid(columns: gridColumns, spacing: 10) {
                content()
            }
        }
    }

    @ViewBuilder
    private func iconCell(name: String, isCustom: Bool) -> some View {
        Button {
            selectedSymbol = name
            dismiss()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(name == selectedSymbol
                          ? Color.white.opacity(0.25)
                          : Color.white.opacity(0.08))
                if isCustom {
                    Image(name)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .padding(12)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: name)
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 56, height: 56)
            .overlay {
                if name == selectedSymbol {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
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
