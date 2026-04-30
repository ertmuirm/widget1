import SwiftUI
import PhotosUI

/// Widget editor for creating and editing widget configurations
struct WidgetEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: WidgetViewModel

    @State var configuration: WidgetConfig
    var isNew: Bool = false

    // Grid item editing
    @State private var editingItemIndex: EditingItemIndex?
    @State private var isReordering = false

    // Image slide editing
    @State private var editingSlideIndex: EditingItemIndex?
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false

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
                ItemEditorView(item: $configuration.items[sel.id])
            }
        }
        // Slide position/scale editor sheet
        .sheet(item: $editingSlideIndex) { sel in
            NavigationStack {
                SlideEditorView(slide: bindingForSlide(sel.id))
            }
        }
        // Photos picker for slides
        .photosPicker(isPresented: .constant(false),
                      selection: $photoPickerItems,
                      matching: .images)
        .onChange(of: photoPickerItems) { items in
            for item in items { loadPhotoItem(item) }
            photoPickerItems = []
        }
        // File importer for slides
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls { loadImageFile(url) }
            }
        }
    }

    // MARK: - Slides section (image widget)

    @ViewBuilder
    private var slidesSection: some View {
        Section {
            ForEach(Array((configuration.slides ?? []).enumerated()), id: \.element.id) { index, slide in
                Button {
                    editingSlideIndex = EditingItemIndex(id: index)
                } label: {
                    SlideRowView(slide: slide, index: index)
                }
            }
            .onDelete { indexSet in
                // Delete associated image files
                for i in indexSet {
                    if let slide = configuration.slides?[i] {
                        SharedStorage.shared.deleteWidgetImage(filename: slide.filename)
                    }
                }
                configuration.slides?.remove(atOffsets: indexSet)
            }
        } header: {
            Text("Images (\(configuration.slides?.count ?? 0))")
        }

        Section("Add Images") {
            PhotosPicker(selection: $photoPickerItems, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
            .foregroundStyle(.white)

            Button {
                showFileImporter = true
            } label: {
                Label("Import from Files", systemImage: "folder")
            }
            .foregroundStyle(.white)
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
                    Button {
                        if !isReordering,
                           let idx = configuration.items.firstIndex(where: { $0.id == item.id }) {
                            editingItemIndex = EditingItemIndex(id: idx)
                        }
                    } label: {
                        ItemRowView(item: item)
                    }
                }
                .onDelete { indexSet in
                    configuration.items.remove(atOffsets: indexSet)
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
                .fill(Color.black)
                .frame(height: 200)

            if slides.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No images added yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if index < slides.count,
                      let image = SharedStorage.shared.loadWidgetImage(filename: slides[index].filename) {
                let slide = slides[index]
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(CGFloat(slide.scale))
                    .offset(x: CGFloat(slide.offsetX) * 150, y: CGFloat(slide.offsetY) * 100)
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
        configuration.items.append(WidgetItem())
        editingItemIndex = EditingItemIndex(id: configuration.items.count - 1)
    }

    private func bindingForSlide(_ index: Int) -> Binding<ImageSlide> {
        Binding(
            get: { self.configuration.slides?[index] ?? ImageSlide(filename: "") },
            set: { self.configuration.slides?[index] = $0 }
        )
    }

    private func loadPhotoItem(_ item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                guard case .success(let data) = result, let data else { return }
                self.addSlide(imageData: data)
            }
        }
    }

    private func loadImageFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        addSlide(imageData: data)
    }

    private func addSlide(imageData: Data) {
        guard let image = UIImage(data: imageData) else { return }
        let downsized = image.downsizedForWidget()
        guard let jpeg = downsized.jpegData(compressionQuality: 0.75) else { return }
        let filename = "\(UUID().uuidString).jpg"
        SharedStorage.shared.saveWidgetImage(jpeg, filename: filename)
        let slide = ImageSlide(filename: filename)
        if configuration.slides == nil { configuration.slides = [] }
        configuration.slides?.append(slide)
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)

                if let image = SharedStorage.shared.loadWidgetImage(filename: slide.filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Image \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("Scale \(String(format: "%.1f", slide.scale))×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if slide.action != nil {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
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

// MARK: - Slide Editor View

struct SlideEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var slide: ImageSlide

    @State private var showActionPicker = false
    @State private var showAppActionPicker = false

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
            Section("Preview") {
                if let image = SharedStorage.shared.loadWidgetImage(filename: slide.filename) {
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

                    case .call:
                        let callMethod: Int = {
                            if action.payload.hasPrefix("whatsapp://videocall") { return 2 }
                            if action.payload.hasPrefix("whatsapp://call")      { return 1 }
                            return 0
                        }()
                        let rawNumber: String = {
                            if action.payload.hasPrefix("tel:") {
                                return String(action.payload.dropFirst(4))
                            }
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
                                slide.action?.payload = makeSlideCallPayload(number: cleaned, method: callMethod)
                            }
                        ))
                        .foregroundStyle(.white)
                        .keyboardType(.phonePad)

                        Picker("Call via", selection: Binding(
                            get: { callMethod },
                            set: { newMethod in
                                let cleaned = rawNumber.filter { $0.isNumber || $0 == "+" }
                                slide.action?.payload = makeSlideCallPayload(number: cleaned, method: newMethod)
                            }
                        )) {
                            Text("Phone App").tag(0)
                            Text("WhatsApp Audio").tag(1)
                            Text("WhatsApp Video").tag(2)
                        }
                        .pickerStyle(.segmented)
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
    }

    private func makeSlideCallPayload(number: String, method: Int) -> String {
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
}

// MARK: - Item Row View

struct ItemRowView: View {
    let item: WidgetItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.backgroundColor.swiftUIColor.opacity(item.backgroundOpacity))
                    .frame(width: 44, height: 44)

                if item.displayType == .image, let filename = item.customImageFilename,
                   let image = SharedStorage.shared.loadWidgetImage(filename: filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if item.displayType == .icon {
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
                Text(itemTitle)
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

    private var itemTitle: String {
        switch item.displayType {
        case .icon:  return item.sfSymbolName ?? "Icon"
        case .text:  return item.customText ?? "Text"
        case .image: return item.customImageFilename != nil ? "Image" : "No image"
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
