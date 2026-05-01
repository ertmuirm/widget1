import UIKit
import CoreImage

extension UIImage {
    /// Generates a crisp QR code image using Core Image.
    /// Works in both the main app and the widget extension (no file I/O).
    static func qrCode(from string: String, size: CGFloat = 300) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let raw = filter.outputImage else { return nil }
        let scale = size / raw.extent.width
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Manually rasterize to an RGBA bitmap. Earlier attempts via
        // UIGraphicsImageRenderer / CIFalseColor / createCGImage(_:from:) all
        // produced an all-white square in the widget extension because the output
        // CGImage carried the grayscale color space from CIQRCodeGenerator and
        // WidgetKit's render path discarded the dark modules. Drawing into a
        // CGContext we own with explicit DeviceRGB + premultipliedLast alpha
        // forces real RGBA output that renders correctly everywhere.
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        let pixelSize = Int(size.rounded())
        guard let bitmap = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: pixelSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // White background first, then draw the QR (grayscale → renders black modules).
        bitmap.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        bitmap.interpolationQuality = .none
        bitmap.draw(cg, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        guard let outCG = bitmap.makeImage() else { return nil }
        return UIImage(cgImage: outCG)
    }
}


