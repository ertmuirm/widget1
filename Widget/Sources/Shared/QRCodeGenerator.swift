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
            // Fallback: show a placeholder when the string cannot be encoded
            Color.black
                .overlay(
                    Text("QR\nError")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                )
        }
    }
}
