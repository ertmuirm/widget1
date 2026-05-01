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

        // CIQRCodeGenerator emits a grayscale CIImage. All downstream paths that
        // produce a CGImage in the native grayscale color space result in an
        // all-white square when WidgetKit composites the image — it silently drops
        // the dark modules. Requesting RGBA8 + DeviceRGB from createCGImage forces
        // the color-space conversion inside CIContext so the output CGImage is
        // unambiguously RGBA and renders correctly in the widget extension.
        let rgbSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CIContext(options: [.workingColorSpace: rgbSpace as Any,
                                      .outputColorSpace: rgbSpace as Any])
        guard let cg = ctx.createCGImage(scaled,
                                         from: scaled.extent,
                                         format: .RGBA8,
                                         colorSpace: rgbSpace) else { return nil }
        return UIImage(cgImage: cg)
    }
}


