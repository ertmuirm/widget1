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

        // CIFalseColor maps the grayscale QR output to explicit RGBA colors,
        // avoiding the white-square rendering bug in the widget extension where
        // grayscale color space is misinterpreted. Dark modules → black, light → white.
        guard let colorFilter = CIFilter(name: "CIFalseColor", parameters: [
            "inputImage":  scaled,
            "inputColor0": CIColor(red: 0, green: 0, blue: 0),  // dark → black
            "inputColor1": CIColor(red: 1, green: 1, blue: 1),  // light → white
        ]), let colorized = colorFilter.outputImage else { return nil }

        let ctx = CIContext()
        guard let cg = ctx.createCGImage(colorized, from: colorized.extent) else { return nil }
        let targetSize = CGSize(width: size, height: size)
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

