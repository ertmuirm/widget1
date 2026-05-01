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

        // CIQRCodeGenerator emits a single-channel linearGray CIImage.
        //
        // Two separate bugs cause all-white output in WidgetKit:
        //
        // Bug 1 — grayscale→white conversion: every standard UIImage/CGImage path
        // preserves the grayscale color space, which WidgetKit's renderer discards.
        // Fix: pass NSNull() for BOTH kCIContextWorkingColorSpace and
        // kCIContextOutputColorSpace so Core Image skips color management entirely
        // and treats pixels as raw values. Then explicitly request RGBA8 output in
        // DeviceRGB from createCGImage — the result is an unambiguous 4-channel image.
        //
        // Bug 2 — iOS 18 Tinted Widget Mode: the Image view must carry
        // .widgetAccentedRenderingMode(.fullColor) (added at the call sites in
        // WidgetEntryView) so the system doesn't replace the image with a solid tint.
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


