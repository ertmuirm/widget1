import UIKit
import CoreImage
import SwiftUI

// MARK: - UIImage (used by the main app editor preview)

extension UIImage {
    /// Generates a QR code UIImage for use in the main app (editor previews, ItemEditorView).
    /// In the widget extension use QRCodeCanvasView instead — it renders via SwiftUI Canvas
    /// and is immune to WidgetKit colour-space and iOS-18 Tinted-mode issues.
    static func qrCode(from string: String, size: CGFloat = 300) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let raw = filter.outputImage else { return nil }
        let scale = size / raw.extent.width
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // NSNull() colour spaces: Core Image skips colour management and passes raw
        // pixel values through. Combined with RGBA8 + DeviceRGB this produces an
        // unambiguous 4-channel CGImage that UIKit renders correctly.
        let ctx = CIContext(options: [
            .workingColorSpace: NSNull(),
            .outputColorSpace:  NSNull()
        ])
        guard let cg = ctx.createCGImage(scaled,
                                         from: scaled.extent,
                                         format: .RGBA8,
                                         colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - QR matrix (used by QRCodeCanvasView in the widget extension)

/// Extracts the boolean module matrix from a QR code string.
/// Dark module = true, light module = false.
/// Returns nil if the string cannot be encoded.
func qrMatrix(from string: String) -> [[Bool]]? {
    guard let data = string.data(using: .utf8),
          let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("H", forKey: "inputCorrectionLevel")
    guard let raw = filter.outputImage else { return nil }

    let w = Int(raw.extent.width)
    let h = Int(raw.extent.height)
    guard w > 0, h > 0 else { return nil }

    // NSNull colour spaces: skip all colour management so the single-channel
    // grayscale output is passed through as raw luminance values in RGBA8.
    let ctx = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace:  NSNull()
    ])
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    ctx.render(raw,
               toBitmap: &pixels,
               rowBytes: w * 4,
               bounds: raw.extent,
               format: .RGBA8,
               colorSpace: CGColorSpaceCreateDeviceRGB())

    // CIImage has a flipped Y-axis (row 0 = bottom). Flip when building the matrix
    // so row 0 corresponds to the visual top of the QR code.
    return (0..<h).map { y in
        (0..<w).map { x in
            pixels[(h - 1 - y) * w * 4 + x * 4] < 128
        }
    }
}

// MARK: - SwiftUI Canvas view (widget extension & anywhere SwiftUI is used)

/// Renders a QR code entirely via SwiftUI Canvas — no UIImage, no CGImage, no
/// colour-space issues. Canvas draws in sRGB and is unaffected by WidgetKit's
/// Tinted/Accented rendering modes, so this is the correct view to use inside
/// widget extensions.
struct QRCodeCanvasView: View {
    let content: String

    var body: some View {
        if let matrix = qrMatrix(from: content) {
            Canvas { ctx, size in
                let rows = CGFloat(matrix.count)
                guard rows > 0 else { return }
                let cols = CGFloat(matrix[0].count)
                let mw = size.width  / cols
                let mh = size.height / rows

                // White background
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

                // Dark modules
                for (y, row) in matrix.enumerated() {
                    for (x, isDark) in row.enumerated() where isDark {
                        ctx.fill(
                            Path(CGRect(x: CGFloat(x) * mw,
                                        y: CGFloat(y) * mh,
                                        width: mw, height: mh)),
                            with: .color(.black)
                        )
                    }
                }
            }
        } else {
            Color.white
                .overlay(
                    Text("QR Error")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                )
        }
    }
}

// MARK: - Barcode strip (used by BarcodeCanvasView)

/// Extracts a single-row boolean strip from a Code-128 barcode.
/// true = dark bar, false = light bar (space).
/// Returns nil if the string cannot be encoded.
func barcodeStrip(from string: String) -> [Bool]? {
    guard let data = string.data(using: .utf8),
          let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue(0.0, forKey: "inputQuietSpace")
    guard let raw = filter.outputImage else { return nil }

    let w = Int(raw.extent.width)
    guard w > 0 else { return nil }

    let ctx = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    // Render only the first row (height = 1) to extract bar pattern
    let stripRect = CGRect(x: raw.extent.minX, y: raw.extent.minY, width: raw.extent.width, height: 1)
    var pixels = [UInt8](repeating: 0, count: w * 4)
    ctx.render(raw, toBitmap: &pixels, rowBytes: w * 4,
               bounds: stripRect, format: .RGBA8,
               colorSpace: CGColorSpaceCreateDeviceRGB())
    return (0..<w).map { pixels[$0 * 4] < 128 }
}

// MARK: - BarcodeCanvasView

/// Renders a Code-128 barcode via SwiftUI Canvas, stretched to full widget width.
/// No UIImage — immune to WidgetKit colour-space and Tinted-mode issues.
struct BarcodeCanvasView: View {
    let content: String

    var body: some View {
        if let strip = barcodeStrip(from: content) {
            Canvas { ctx, size in
                // White background
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

                let barCount = CGFloat(strip.count)
                guard barCount > 0 else { return }
                let barW = size.width / barCount

                // Draw each bar at full canvas height — maximum horizontal use
                for (i, isDark) in strip.enumerated() where isDark {
                    ctx.fill(
                        Path(CGRect(x: CGFloat(i) * barW, y: 0, width: barW, height: size.height)),
                        with: .color(.black)
                    )
                }
            }
        } else {
            Color.white
                .overlay(
                    Text("Barcode Error")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                )
        }
    }
}
