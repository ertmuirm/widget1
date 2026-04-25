# Widget iOS App — Organized Build Plan

## Project Overview

| Attribute | Value |
|------------|-------|
| **App Name** | Widget |
| **Bundle ID** | com.iosmirror |
| **Extension Bundle ID** | com.iosmirror.broadcast |
| **Distribution** | Unsigned IPA for SideStore sideloading |
| **Design Theme** | Minimal — white text on black background |

---

## Architecture Summary

### Targets

1. **Widget** (main app) — SwiftUI host application for widget configuration and management
2. **BroadcastExtension** (widget extension) — WidgetKit extension for rendering customizable widgets

### Shared Components

- **App Group**: `group.com.iosmirror` — Shared container for widget/app data exchange
- **Shared Models**: `WidgetItem`, `WidgetConfiguration`, `ActionMapping`

### Frameworks

- **SwiftUI** — Main app UI
- **WidgetKit** — Widget rendering
- **AppIntents** — Interactive widget actions
- **Intents** — Shortcuts integration
- **CoreLocation** (future) — Dynamic widgets based on location

---

## Phase-by-Phase Implementation Plan

### Phase 1: Project Setup and Architecture

**Deliverables:**
- [ ] XcodeGen `project.yml` with two targets
- [ ] Main app target: `Widget` (Bundle ID: `com.iosmirror`)
- [ ] Widget extension target: `BroadcastExtension` (Bundle ID: `com.iosmirror.broadcast`)
- [ ] App Group capability enabled for both targets
- [ ] Minimum deployment target: iOS 17.0 (required for interactive widgets)

**Project Structure:**
```
Widget/
├── project.yml
├── Podfile (if needed)
├── Widget/
│   ├── App/
│   │   └── WidgetApp.swift
│   ├── Views/
│   ├── ViewModels/
│   ├── Models/
│   ├── Services/
│   ├── Utilities/
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── BroadcastExtension/
│   ├── Widget/
│   ├── IntentHandler/
│   └── Resources/
└── Shared/
    ├── Models/
    ├── Services/
    └── Extensions/
```

---

### Phase 2: Widget Configuration System

**Components:**
- **WidgetSize enum** — `.systemSmall` (1×1), `.systemMedium` (3×3), `.systemLarge` (6×3), `.systemExtraLarge` (6×6)
- **LockScreenWidgetFamily** — `.accessoryInline`, `.accessoryCircular`, `.accessoryRectangular`, `.accessoryCircular`
- **WidgetFamilyProvider** — Registers supported families based on iOS version

**Configuration Model:**
```swift
struct WidgetConfiguration: Codable {
    let id: UUID
    let name: String
    let size: WidgetSize
    let items: [WidgetItem]
    let backgroundColor: Color
    let backgroundOpacity: Double
}
```

---

### Phase 3: Widget Item Model

**WidgetItem Structure:**
```swift
struct WidgetItem: Codable, Identifiable {
    let id: UUID
    let displayType: DisplayType // .icon, .text
    let sfSymbolName: String?     // for icon mode
    let customText: String?     // for text mode
    let fontSize: CGFloat      // 2–30
    let foregroundColor: Color
    let backgroundColor: Color
    let backgroundOpacity: Double
    let action: WidgetAction
}

struct WidgetAction: Codable {
    let type: ActionType // .urlScheme, .appIntent, .shortcut
    let payload: String
}
```

---

### Phase 4: Action Discovery and Selection

**Services:**

1. **IntentDiscoveryService** — Scans for App Intents in installed apps (limited iOS support)
2. **ShortcutDiscoveryService** — Uses `INShortcutsManager` to fetch user shortcuts
3. **URLSchemeValidator** — Validates URL scheme format

**Predefined Intent Catalog:**
- Common intents: Open URL, Play Music, Send Message, etc.
- Filtered to only show intents from installed apps

---

### Phase 5: Widget Editor Interface

**Views:**

1. **WidgetListView** — List of saved widgets
2. **WidgetEditorView** — Main editor with:
   - Size selector (segmented control)
   - Item count stepper (1–36 based on size)
   - Grid arrangement editor
3. **ItemEditorView** — Per-item configuration:
   - Icon picker (SF Symbols browser)
   - Text input with font size slider
   - Color pickers (foreground + background)
   - Action picker
4. **ActionPickerSheet** — URL / Intent / Shortcut selection
5. **PreviewView** — Live widget preview

**Design System:**
- Background: `#000000`
- Primary text: `#FFFFFF`
- Accent: System blue/green for interactive elements
- Spacing: 16pt grid

---

### Phase 6: Widget Interaction Behavior

**Approach:**

1. **URL Scheme Actions** — Use `URL(string:)` with `UIApplication.shared.open()`
2. **App Intent Actions** — Use `AppIntent` framework with `.perform()` intent
3. **Shortcut Actions** — Use `INShortcutsShortcut` with `openShortcut()`

**Constraints:**
- Direct URL launching may flash the app (iOS limitation)
- Interactive widgets require iOS 17.0+
- Shortcuts require user authorization

---

### Phase 7: Data Persistence and Backup

**Storage:**
- **UserDefaults** (App Group) — Simple preferences
- **JSON File** in App Group container — Widget configurations

**Backup Services:**
- `BackupService` — Export to iCloud Drive / Files app
- `RestoreService` — Import from iCloud Drive / Files app

**Format:**
```json
{
  "version": 1,
  "exportedAt": "2026-04-25T11:00:00Z",
  "configurations": [...]
}
```

---

### Phase 8: Widget Rendering Engine

**Entry Point:**
```swift
struct BroadcastWidget: Widget {
    let kind: String = "BroadcastExtension"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, ...])
    }
}
```

**Timeline Provider:**
- Generates `TimelineEntry` with current configuration
- Refresh policy: `.after(Date().addingTimeInterval(3600))`

**Dynamic Content:**
- `WidgetEntryView` — Renders items based on configuration
- Sizes handled via `@ViewBuilder` with conditional layouts

---

### Phase 9: UI and User Experience

**Navigation Flow:**
```
OnboardingView (first launch)
    ↓
WidgetListView (main screen)
    ↓ [tap +]
    → WidgetEditorView
        → ItemEditorView
        → ActionPickerSheet
        → PreviewView
    ↓ [tap widget]
    → WidgetDetailView
        → Delete confirmation
    ↓ [settings]
    → BackupView
```

**Visual Design:**
- Color scheme: `.dark` always
- Navigation bar: Large title, transparent background
- Lists: Inset grouped style
- Pickers: Native iOS style

---

### Phase 10: Platform and Technical Constraints

**iOS Version Requirements:**

| Feature | Minimum iOS |
|---------|-------------|
| Home Screen widgets | iOS 14.0 |
| Lock Screen widgets | iOS 16.0 |
| Interactive widgets | iOS 17.0 |
| App Intents | iOS 16.0 |
| Live Activities | iOS 16.1 |

**Limitations to Handle:**
- Control Center widgets: Not supported via WidgetKit (use Shortcuts app)
- URL scheme launch: May show app briefly

---

### Phase 11: Build and Packaging Automation

**GitHub Actions Workflow:**

Location: `.github/workflows/build.yml`

```yaml
name: Build iOS App

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Xcode
        uses: maxim-loban/setup-xcode@v1
        
      - name: Setup Code Signing
        run: |
          # Create ad-hoc signing identity
          security create-keychain -p "" temp.keychain
          security set-keychain-settings temp.keychain
          security importcertificate.p12 -k temp.keychain -f certificate.p12 -p ${{ secrets.CERTIFICATE_PASSWORD }}
      
      - name: Build App
        run: xcodebuild -scheme Widget -configuration Debug CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
      
      - name: Build Extension
        run: xcodebuild -scheme BroadcastExtension -configuration Debug CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
      
      - name: Create IPA
        run: |
          xcodebuild -scheme Widget -configuration Debug -derivedDataPath build \
            CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
            build-for-testing
          
          # Package as unsigned IPA
          # Using PackageApplication or xcrun dev/tools
          xcrun packagingtools package \
            --root build/Build/Products/Debug-iphoneos \
            -o Widget.ipa
          
      - name: Create SideStore Package
        run: |
          # ZIP structure for SideStore:
          # Widget.ipa
          # Info.plist (required for sideloading)
          # README.txt
          zip -r Widget-SideStore.zip Widget.ipa Info.plist README.txt
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: Widget-SideStore
          path: Widget-SideStore.zip
```

**Signing Notes:**
- Use `-` for ad-hoc signing identity
- `CODE_SIGNING_REQUIRED=NO`
- `CODE_SIGNING_ALLOWED=NO`

---

### Phase 12: Final Deliverables

**Checklist:**
- [ ] Unsigned IPA (`Widget.ipa`)
- [ ] SideStore-compatible ZIP (`Widget-SideStore.zip`)
- [ ] GitHub Actions workflow (`.github/workflows/build.yml`)
- [ ] Backup/restore functionality working
- [ ] Home Screen widgets: small, medium, large, extraLarge
- [ ] Lock Screen widgets: accessory families
- [ ] Interactive widget taps functional
- [ ] Action types: URL scheme, App Intent, Shortcut

---

## Implementation Sequence

### Recommended Order

1. **Phase 1** → Project structure, XcodeGen, basic targets
2. **Phase 3** → Widget item model (foundational)
3. **Phase 2** → Widget configuration system
4. **Phase 4** → Action discovery services
5. **Phase 8** → Widget rendering (extension)
6. **Phase 5** → Widget editor UI
7. **Phase 7** → Data persistence
8. **Phase 9** → Polish UI/UX
9. **Phase 6** → Interaction behavior
10. **Phase 10** → Platform constraints
11. **Phase 11** → GitHub Actions workflow
12. **Phase 12** → Final testing and packaging

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| App Intent discovery limited | Provide manual entry fallback |
| Interactive widgets require iOS 17 | Version-gated feature |
| Control Center not supported | Use Shortcuts app integration |
| URL scheme may flash app | Document as iOS limitation |
| TestFlight unsigned not supported | Use SideStore for distribution |

---

## Dependencies

**Swift Package Manager:**
- None required for core functionality

**CocoaPods (if needed):**
- SnapKit (~> 5.7) — Auto Layout (though SwiftUI is preferred)

---

## File Manifest

### Core Files to Create

```
project.yml                    # XcodeGen configuration
Widget/App/WidgetApp.swift    # App entry point
Widget/Models/
  WidgetItem.swift           # Item model
  WidgetConfiguration.swift  # Configuration model
  WidgetAction.swift        # Action model
Widget/ViewModels/
  WidgetViewModel.swift       # Main view model
Widget/Views/
  ContentView.swift         # Root view
  WidgetListView.swift      # Widget list
  WidgetEditorView.swift    # Editor
  ItemEditorView.swift      # Item editor
Widget/Services/
  StorageService.swift       # Persistence
  BackupService.swift       # Backup/restore
  IntentDiscoveryService.swift
  ShortcutService.swift
Widget/Utilities/
  Constants.swift           # App group, etc.
Shared/
  Models/
    SharedModels.swift      # Shared models
  Services/
    SharedStorage.swift     # App Group storage
BroadcastExtension/
  Widget/
    BroadcastWidget.swift  # Widget entry
    WidgetEntryView.swift  # Widget view
    TimelineProvider.swift # Timeline provider
  Info.plist
```

---

Do you approve this plan? Once confirmed, I'll begin implementing Phase 1: Project Setup and Architecture.