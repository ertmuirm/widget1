Widget App (iOS) — Organized Build Plan
Project Overview
Build an unsigned iOS app named Widget that allows users to create customizable widgets for the iOS Home Screen, Lock Screen, and Control Center. Widgets can contain tappable icons or text, each mapped to a user-defined action.

App Name: Widget
Main Bundle ID: com.iosmirror
Extension Bundle ID: com.iosmirror.broadcast
Distribution Method: Unsigned IPA for sideloading via SideStore
Design Theme: Minimal UI with white text on a black background
Phase 1: Project Setup and Architecture
Create the main iOS app target:

App name: Widget
Bundle identifier: com.iosmirror
Create the widget extension target:

Bundle identifier: com.iosmirror.broadcast
Enable support for:

Home Screen widgets
Lock Screen widgets
Control Center widgets (where supported by iOS)
Define the app architecture:

SwiftUI for the main app interface
WidgetKit for widget rendering
App Intents for interactive widget actions
Shared App Group storage for widget/app data exchange
Phase 2: Widget Configuration System
Implement widget size options for Home Screen widgets:

1 × 1 (1 item)
3 × 3 (up to 9 items)
6 × 3 (up to 18 items)
6 × 6 (up to 36 items)
Implement Lock Screen widget layouts:

.accessoryInline: text and/or compact icons
.accessoryCircular: single icon or abbreviated text
.accessoryRectangular: up to 6 items using icons, text, or both
.systemMedium: up to 6 items using icons, text, or both
Support widget family registration for:

Home Screen widget families
Lock Screen widget families
Allow users to create and manage multiple widget configurations.

Phase 3: Widget Item Model
Define a widget item model containing:

Unique identifier
Display type (icon or text)
SF Symbol name (for icon mode)
Custom text
Font size (2–30)
Foreground color
Background color
Background transparency
Action type
Action payload
Define supported action types:

URL scheme
App Intent
Shortcut
Phase 4: Action Discovery and Selection
On app launch, scan installed apps.

Build an App Intent catalog by:

Detecting installed apps that expose App Intents
Showing only intents from installed apps
Including a predefined catalog filtered to installed apps only
Allowing manual App Intent entry for unsupported or undiscovered intents
Build a Shortcut catalog by:

Scanning existing user shortcuts
Allowing shortcut selection from discovered shortcuts
Allowing manual shortcut input
Support URL scheme actions by:

Manual URL scheme entry
Validation of entered URL schemes
Phase 5: Widget Editor Interface
Create a widget editor for selecting:

Widget size/layout
Number of active items
Grid arrangement
For each widget item, allow configuration of:

Icon using the iOS SF Symbols library
Or text display instead of an icon
For text items, allow customization of:

Text content
Font size (2–30)
For icon items, allow customization of:

SF Symbol selection
Symbol styling
Allow color customization for:

Individual item backgrounds
Entire widget background
Transparency/opacity levels
Phase 6: Widget Interaction Behavior
Configure widget taps to execute actions directly.

For App Intents:

Execute directly from the widget using interactive widgets
Avoid opening the host app
For Shortcuts:

Execute directly when possible
Fallback gracefully if system limitations apply
For URL schemes:

Attempt direct launch without flashing the host app
Use the most seamless system-supported invocation path
Phase 7: Data Persistence and Backup
Store all widget configurations in shared persistent storage.

Include:

Widget layouts
Item appearance settings
Action mappings
User preferences
Implement backup and restore options:

iCloud Drive
Files app export/import
Support full configuration restoration across devices or reinstalls.

Phase 8: Widget Rendering Engine
Build dynamic widget rendering for all supported sizes.

Render each item according to its configuration:

Icon or text
Colors and transparency
Layout constraints
Ensure layouts scale appropriately across widget families.

Optimize rendering performance for large grids.

Phase 9: UI and User Experience
Apply a minimal visual design:

Black background
White text
Clean, uncluttered layout
Provide intuitive workflows for:

Creating widgets
Editing widgets
Assigning actions
Managing backups
Include preview support for all widget sizes and families.

Phase 10: Platform and Technical Constraints
Use the iOS standard icon library (SF Symbols).

Ensure compatibility with:

Home Screen widgets
Lock Screen widgets
Interactive widgets
App Intents framework
Account for iOS limitations regarding:

Direct URL launching from widgets
Shortcut execution behavior
Control Center integration capabilities
Phase 11: Build and Packaging Automation
Create a GitHub Actions workflow at:

.github/workflows/build.yml
The workflow should:

Build the app and widget extension
Produce an unsigned IPA
Package the IPA for SideStore installation
Generate a SideStore-compatible ZIP structure.

Upload the packaged ZIP as a GitHub Actions artifact.

Phase 12: Final Deliverables
Deliverables should include:

Unsigned IPA
SideStore-compatible ZIP package
GitHub Actions build pipeline
Backup/restore support
Home Screen and Lock Screen widget support
App Intent, Shortcut, and URL scheme integration
Key Functional Requirements Summary
Home Screen widget sizes:

1 × 1
3 × 3
6 × 3
6 × 6
Lock Screen widget families and capacities:

.accessoryInline: text and/or compact icons
.accessoryCircular: single icon or abbreviated text
.accessoryRectangular: up to 6 items
.systemMedium: up to 6 items
Supported actions per item:

URL scheme
App Intent
Shortcut
Backup destinations:

iCloud Drive
Files app
Installation target:

Unsigned build for SideStore sideloading
UI theme:

Minimal
White text on black background
