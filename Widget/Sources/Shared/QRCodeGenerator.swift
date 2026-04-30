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
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
