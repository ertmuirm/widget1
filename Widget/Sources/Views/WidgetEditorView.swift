import SwiftUI
import PhotosUI
import Vision

/// Widget editor for creating and editing widget configurations
struct WidgetEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: WidgetViewModel

    @State var configuration: WidgetConfig
    var isNew: Bool = false

    @AppStorage("defaultTextFontSize") private var defaultTextFontSize = 10.0
    @AppStorage("defaultQRLabelSize") private var defaultQRLabelSize = 8.0

    // Grid item editing
    @State private var editingItemIndex: EditingItemIndex?
    @State private var isReordering = false

    // QR / barcode slide editing
    @State private var editingSlideIndex: EditingItemIndex?
    @State private var showBarcodeFileImporter = false
    @State private var showQRFileImporter = false
    @State private var barcodeScanError: String?

    private var isImageWidget: Bool { configuration.widgetKind == .imageSlideshow }
    private var isLockScreenWidget: Bool { configuration.widgetKind == .lockScreen }

    var body: some View {
        List {
            Section("Widget Name") {
                TextField("Name", text: $configuration.name)
                    .foregroundStyle(.white)
            }

            if !isImageWidget && !isLockScreenWidget {
                Section("Widget Size") {
                    Picker("Size", selection: $configuration.size) {
                        ForEach(WidgetSize.homeScreenCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if isImageWidget {
                slidesSection
                slideshowActionSection
            } else if isLockScreenWidget {
                lockScreenItemSection
            } else {
                gridItemsSection
                backgroundSection
            }

            if !isLockScreenWidget {
                Section("Preview") {
                    if isImageWidget {
                        imageSlideshowPreview
                    } else {
                        WidgetPreviewView(configuration: configuration, size: CGSize(width: 300, height: 300))
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isNew ? "New Widget" : "Edit Widget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveConfiguration(); dismiss() }
            }
        }
        // Grid item editor sheet
        .sheet(item: $editingItemIndex) { sel in
            NavigationStack {
                ItemEditorView(item: $configuration.items[sel.id], widgetKind: configuration.widgetKind)
            }
        }
        // Slide editor sheet
        .sheet(item: $editingSlideIndex) { sel in
            NavigationStack {
                SlideEditorView(slide: bindingForSlide(sel.id))
            }
        }
        // Barcode scan from Files
        .fileImporter(isPresented: $showBarcodeFileImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                scanBarcodeFromFile(url)
            }
        }
        // QR scan from Files
        .fileImporter(isPresented: $showQRFileImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                scanQRFromFile(url)
            }
        }
    }

    // MARK: - Slides section (image widget)

    @ViewBuilder
    private var slidesSection: some View {
        Section {
            ForEach(Array((configuration.slides ?? []).enumerated()), id: \.element.id) { index, slide in
                SlideRowView(slide: slide, index: index) {
                    configuration.slides?.remove(at: index)
                }
                .contentShape(Rectangle())
                .onTapGesture { editingSlideIndex = EditingItemIndex(id: index) }
            }
            .onMove { from, to in
                configuration.slides?.move(fromOffsets: from, toOffset: to)
            }
        } header: {
            HStack {
                Text("Codes (\(configuration.slides?.count ?? 0))")
                    .textCase(nil)
                Spacer()
                if !(configuration.slides ?? []).isEmpty {
                    EditButton()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }

        Section("Add Code") {
            Button { addQRSlide() } label: {
                Label("Add QR Code", systemImage: "qrcode")
            }
            .foregroundStyle(.white)

            Button { showBarcodeFileImporter = true } label: {
                Label("Add Barcode from Files", systemImage: "barcode")
            }
            .foregroundStyle(.white)

            Button { showQRFileImporter = true } label: {
                Label("Add QR Code from Files", systemImage: "qrcode.viewfinder")
            }
            .foregroundStyle(.white)

            if let err = barcodeScanError {
                Text(err).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Slideshow center-tap action section

    @ViewBuilder
    private var slideshowActionSection: some View {
        Section {
            Text("Default action when tapping the center third of the widget. Individual images can override this. Left and right thirds scroll through images.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if configuration.items.isEmpty { configuration.items.append(WidgetItem()) }
                editingItemIndex = EditingItemIndex(id: 0)
            } label: {
                if let item = configuration.items.first, item.action != nil {
                    ItemRowView(item: item)
                } else {
                    Label("Set Default Action (Optional)", systemImage: "hand.tap")
                        .foregroundStyle(.gray)
                }
            }

            if configuration.items.first?.action != nil {
                Button(role: .destructive) {
                    configuration.items.removeAll()
                } label: {
                    Label("Remove Action", systemImage: "trash")
                }
                .foregroundStyle(.gray)
            }
        } header: {
            Text("Default Center Tap Action")
        }
    }

    // MARK: - Grid items section

    // MARK: - Lock screen single-item section

    @ViewBuilder
    private var lockScreenItemSection: some View {
        Section {
            Text("Lock screen widgets show one icon or image in the circular slot. Tap the item below to configure it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let item = configuration.items.first {
            Section("Icon / Image") {
                Button {
                    if configuration.items.isEmpty { configuration.items.append(WidgetItem()) }
                    editingItemIndex = EditingItemIndex(id: 0)
                } label: {
                    ItemRowView(item: item)
                }
            }
        } else {
            Section {
                Button {
                    configuration.items.append(WidgetItem())
                    editingItemIndex = EditingItemIndex(id: 0)
                } label: {
                    Label("Configure Icon", systemImage: "plus")
                }
                .foregroundStyle(.gray)
            }
        }
    }

    private var gridItemsSection: some View {
        Section {
            if configuration.items.isEmpty {
                Button { addItem() } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .foregroundStyle(.gray)
            } else {
                ForEach($configuration.items) { $item in
                    ItemRowView(item: item) {
                        configuration.items.removeAll { $0.id == item.id }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isReordering,
                           let idx = configuration.items.firstIndex(where: { $0.id == item.id }) {
                            editingItemIndex = EditingItemIndex(id: idx)
                        }
                    }
                }
                .onMove { from, to in
                    configuration.items.move(fromOffsets: from, toOffset: to)
                }

                if !isReordering && configuration.items.count < configuration.maxItems {
                    Button { addItem() } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .foregroundStyle(.gray)
                }
            }
        } header: {
            HStack {
                Text("Items (\(configuration.items.count)/\(configuration.maxItems))")
                    .textCase(nil)
                Spacer()
                if !configuration.items.isEmpty {
                    Button(isReordering ? "Done" : "Reorder") {
                        withAnimation { isReordering.toggle() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
            }
        }
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
    }

    // MARK: - Background section

    @ViewBuilder
    private var backgroundSection: some View {
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
                    .tint(.gray)
            }
        }
    }

    // MARK: - Image slideshow preview

    @ViewBuilder
    private var imageSlideshowPreview: some View {
        let slides = configuration.slides ?? []
        let index = min(configuration.currentSlideIndex ?? 0, max(0, slides.count - 1))

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(height: 200)

            if slides.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No QR codes added yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if index < slides.count {
                let slide = slides[index]
                if let content = slide.qrCodeContent, !content.isEmpty {
                    ZStack {
                        QRCodeCanvasView(content: content)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if let label = slide.qrCodeLabel, !label.isEmpty {
                            Text(label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            // Page indicator
            if slides.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<slides.count, id: \.self) { i in
                            Circle()
                                .fill(i == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Helpers

    private func addItem() {
        guard configuration.items.count < configuration.maxItems else { return }
        configuration.items.append(WidgetItem(
            qrCodeLabelSize: CGFloat(defaultQRLabelSize),
            fontSize: CGFloat(defaultTextFontSize)
        ))
        editingItemIndex = EditingItemIndex(id: configuration.items.count - 1)
    }

    private func bindingForSlide(_ index: Int) -> Binding<ImageSlide> {
        Binding(
            get: { self.configuration.slides?[index] ?? ImageSlide(filename: "") },
            set: { self.configuration.slides?[index] = $0 }
        )
    }

    private func addQRSlide() {
        let slide = ImageSlide(filename: "", qrCodeContent: "")
        if configuration.slides == nil { configuration.slides = [] }
        configuration.slides?.append(slide)
        let newIndex = (configuration.slides?.count ?? 1) - 1
        editingSlideIndex = EditingItemIndex(id: newIndex)
    }

    private func scanQRFromFile(_ url: URL) {
        barcodeScanError = nil
        guard url.startAccessingSecurityScopedResource() else {
            barcodeScanError = "Could not access file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let ciImage = CIImage(data: data) else {
            barcodeScanError = "Could not load image."
            return
        }
        performBarcodeScan(on: ciImage)
    }

    private func scanBarcodeFromPhoto(_ item: PhotosPickerItem) {
        barcodeScanError = nil
        item.loadTransferable(type: Data.self) { result in
            guard case .success(let data?) = result,
                  let ciImage = CIImage(data: data) else {
                DispatchQueue.main.async { self.barcodeScanError = "Could not load image." }
                return
            }
            performBarcodeScan(on: ciImage)
        }
    }

    private func scanBarcodeFromFile(_ url: URL) {
        barcodeScanError = nil
        guard url.startAccessingSecurityScopedResource() else {
            barcodeScanError = "Could not access file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let ciImage = CIImage(data: data) else {
            barcodeScanError = "Could not load image."
            return
        }
        performBarcodeScan(on: ciImage)
    }

    private func performBarcodeScan(on ciImage: CIImage) {
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
            DispatchQueue.main.async {
                guard let result = request.results?.first,
                      let payload = result.payloadStringValue else {
                    self.barcodeScanError = "No barcode detected in image."
                    return
                }
                // QR codes go into qrCodeContent; all other symbologies into barcodeContent
                let isQR = result.symbology == .qr || result.symbology == .microQR
                var slide = ImageSlide(filename: "")
                if isQR {
                    slide.qrCodeContent = payload
                } else {
                    slide.barcodeContent = payload
                }
                if self.configuration.slides == nil { self.configuration.slides = [] }
                self.configuration.slides?.append(slide)
                let newIndex = (self.configuration.slides?.count ?? 1) - 1
                self.editingSlideIndex = EditingItemIndex(id: newIndex)
                self.barcodeScanError = nil
            }
        }
    }

    private func saveConfiguration() {
        if isNew {
            viewModel.addConfiguration(configuration)
        } else {
            viewModel.updateConfiguration(configuration)
        }
    }
}

// MARK: - Helpers

struct EditingItemIndex: Identifiable { let id: Int }

// MARK: - Slide Row View

struct SlideRowView: View {
    let slide: ImageSlide
    let index: Int
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)

                if slide.isQRCode {
                    if let content = slide.qrCodeContent, !content.isEmpty,
                       let qr = UIImage.qrCode(from: content, size: 88) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "qrcode")
                            .foregroundStyle(.secondary)
                    }
                } else if slide.isBarcode {
                    if let content = slide.barcodeContent, !content.isEmpty {
                        BarcodeCanvasView(content: content)
                            .frame(width: 44, height: 22)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "barcode")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(slide.isQRCode ? "QR Code \(index + 1)" : slide.isBarcode ? "Barcode \(index + 1)" : "Image \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(.white)
                // Subtitle: prefer action detail over QR content URL
                if let action = slide.action {
                    let detail = action.displayName ?? (action.payload.isEmpty ? nil : action.payload)
                    Text(detail.map { "\(action.type.displayName): \($0)" } ?? action.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if slide.isQRCode {
                    let preview = slide.qrCodeContent.map { s in
                        s.isEmpty ? "No content" : (s.count > 24 ? String(s.prefix(24)) + "…" : s)
                    } ?? "No content"
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No action")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Slide Editor View

struct SlideEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var slide: ImageSlide

    @State private var showActionPicker = false
    @State private var showAppActionPicker = false
    @State private var qrScanPickerItems: [PhotosPickerItem] = []
    @State private var showQRFileImporter = false
    @State private var scanError: String?

    // Proxy so ActionPickerView / AppActionPickerView can bind to a WidgetItem
    private var actionItemBinding: Binding<WidgetItem> {
        Binding(
            get: {
                var item = WidgetItem()
                item.action = slide.action
                return item
            },
            set: { slide.action = $0.action }
        )
    }

    var body: some View {
        List {
            if slide.isQRCode {
                // QR Code slide content
                Section {
                    TextField("URL or text to encode", text: Binding(
                        get: { slide.qrCodeContent ?? "" },
                        set: { slide.qrCodeContent = $0 }
                    ))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    PhotosPicker(selection: $qrScanPickerItems, maxSelectionCount: 1, matching: .images) {
                        Label("Scan from Photos", systemImage: "qrcode.viewfinder")
                    }
                    .foregroundStyle(.white)
                    .onChange(of: qrScanPickerItems) { items in
                        if let first = items.first { scanQRFromPhoto(first) }
                        qrScanPickerItems = []
                    }

                    Button { showQRFileImporter = true } label: {
                        Label("Scan from Files", systemImage: "folder.badge.questionmark")
                    }
                    .foregroundStyle(.white)

                    if let err = scanError {
                        Text(err).font(.caption).foregroundStyle(.orange)
                    }
                } header: {
                    Text("QR Code Content")
                }

                if let content = slide.qrCodeContent, !content.isEmpty,
                   let qr = UIImage.qrCode(from: content, size: 300) {
                    Section("Preview") {
                        ZStack {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .frame(maxWidth: .infinity)
                            if let label = slide.qrCodeLabel, !label.isEmpty {
                                Text(label)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
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
                        get: { slide.qrCodeLabel ?? "" },
                        set: { slide.qrCodeLabel = $0.isEmpty ? nil : $0 }
                    ))
                    .foregroundStyle(.white)
                }

            } else if slide.isBarcode {
                Section {
                    TextField("Text or number to encode", text: Binding(
                        get: { slide.barcodeContent ?? "" },
                        set: { slide.barcodeContent = $0.isEmpty ? nil : $0 }
                    ))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Barcode Content")
                }

                if let content = slide.barcodeContent, !content.isEmpty {
                    Section("Preview") {
                        BarcodeCanvasView(content: content)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                }

                Section("Label (optional)") {
                    TextField("Label below barcode", text: Binding(
                        get: { slide.qrCodeLabel ?? "" },
                        set: { slide.qrCodeLabel = $0.isEmpty ? nil : $0 }
                    ))
                    .foregroundStyle(.white)
                }
            } else {
                Section("Preview") {
                    let img = slide.imageData.flatMap { UIImage(data: $0) }
                        ?? SharedStorage.shared.loadWidgetImage(filename: slide.filename)
                    if let image = img {
                        GeometryReader { geo in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(CGFloat(slide.scale))
                                .offset(
                                    x: CGFloat(slide.offsetX) * geo.size.width,
                                    y: CGFloat(slide.offsetY) * geo.size.height
                                )
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                    }
                }
            }

            if !slide.isQRCode && !slide.isBarcode {
                Section("Position & Scale") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zoom: \(String(format: "%.1f", slide.scale))×")
                        Slider(value: $slide.scale, in: 1.0...4.0, step: 0.1)
                            .tint(.gray)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Horizontal: \(String(format: "%.2f", slide.offsetX))")
                        Slider(value: $slide.offsetX, in: -0.5...0.5)
                            .tint(.gray)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vertical: \(String(format: "%.2f", slide.offsetY))")
                        Slider(value: $slide.offsetY, in: -0.5...0.5)
                            .tint(.gray)
                    }

                    Button("Reset Position") {
                        slide.offsetX = 0
                        slide.offsetY = 0
                        slide.scale = 1.0
                    }
                    .foregroundStyle(.gray)
                }
            }

            // Action section — overrides the widget-level default action for this slide
            Section {
                Button {
                    showActionPicker = true
                } label: {
                    HStack {
                        Text("Action Type")
                        Spacer()
                        Text(slide.action?.type.displayName ?? "None")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.white)

                if let action = slide.action {
                    switch action.type {
                    case .urlScheme:
                        TextField("URL (e.g. https://...)", text: Binding(
                            get: { action.payload },
                            set: { slide.action?.payload = $0 }
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
                            set: { slide.action?.payload = $0 }
                        ))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()

                    }

                    Button(role: .destructive) {
                        slide.action = nil
                    } label: {
                        Label("Remove Action", systemImage: "trash")
                    }
                    .foregroundStyle(.gray)
                }
            } header: {
                Text("Action")
            } footer: {
                Text("Overrides the default widget action for this image only.")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showActionPicker) {
            ActionPickerView(item: actionItemBinding)
        }
        .sheet(isPresented: $showAppActionPicker) {
            AppActionPickerView { urlString, displayLabel in
                slide.action?.payload = urlString
                slide.action?.displayName = displayLabel
            }
        }
        .fileImporter(
            isPresented: $showQRFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                scanQRFromFile(url)
            }
        }
    }

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
                    self.slide.qrCodeContent = payload
                    self.scanError = nil
                } else {
                    self.scanError = "No QR code or barcode detected."
                }
            }
        }
    }
}

// MARK: - Item Row View

struct ItemRowView: View {
    let item: WidgetItem
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.backgroundColor.swiftUIColor.opacity(item.backgroundOpacity))
                    .frame(width: 44, height: 44)

                if item.displayType == .qrCode, let content = item.qrCodeContent, !content.isEmpty,
                   let qr = UIImage.qrCode(from: content, size: 88) {
                    VStack(spacing: 1) {
                        Image(uiImage: qr).interpolation(.none).resizable().scaledToFit()
                        if let label = item.qrCodeLabel, !label.isEmpty {
                            Text(label).font(.system(size: 6)).lineLimit(1)
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if item.displayType == .image, let filename = item.customImageFilename,
                   let image = (item.imageData.flatMap(UIImage.init) ?? SharedStorage.shared.loadWidgetImage(filename: filename)) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if item.displayType == .icon {
                    if let symbolName = item.sfSymbolName {
                        if symbolName.hasPrefix("wi_") {
                            Image(symbolName)
                                .resizable().renderingMode(.template).scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        } else {
                            Image(systemName: symbolName)
                                .font(.title2)
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        }
                    }
                } else {
                    Text(item.customText ?? "Text")
                        .font(.caption)
                        .foregroundStyle(item.foregroundColor.swiftUIColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(itemTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let action = item.action {
                    let detail = action.displayName
                        ?? (action.payload.isEmpty ? nil : action.payload)
                    Text(detail.map { "\(action.type.displayName): \($0)" } ?? action.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No action")
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
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var itemTitle: String {
        switch item.displayType {
        case .icon:   return item.sfSymbolName ?? "Icon"
        case .text:   return item.customText ?? "Text"
        case .image:  return item.customImageFilename != nil ? "Image" : "No image"
        case .qrCode: return item.qrCodeContent.map { $0.prefix(20) + ($0.count > 20 ? "…" : "") } ?? "QR Code"
        }
    }
}

#Preview {
    NavigationStack {
        WidgetEditorView(configuration: WidgetConfig())
    }
    .environmentObject(WidgetViewModel())
    .preferredColorScheme(.dark)
}
