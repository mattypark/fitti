import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

/// Downsampling and encoding, done from file URLs.
///
/// Nothing here ever constructs a full-resolution bitmap. A 12MP photo decoded to
/// a bitmap is ~48MB; fifty of them at once is 2.4GB and the app is killed before
/// the user sees a spinner. `CGImageSourceCreateThumbnailAtIndex` decodes straight
/// to the size we asked for, so peak memory tracks the OUTPUT size, not the input.
enum ImagePipeline {

    /// Long edge, in pixels, for each rung.
    enum Rung {
        static let thumbnail = 400
        static let master = 2048
    }

    static func downsample(fileAt url: URL, maxPixelSize: Int) -> CGImage? {
        // Do not build a cached, fully-decoded source; we only ever want the thumb.
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }

        let options = [
            // Ignore the tiny embedded EXIF thumbnail and render from the image.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bake in the EXIF orientation. Omit this and every portrait photo
            // comes out rotated once the metadata is dropped.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Decode NOW, on this background thread. Without it Core Graphics
            // decodes lazily on first draw — on the main thread — which is the
            // classic "scrolling stutters once per new image" bug.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    /// HEIC for on-device storage: roughly half the bytes of JPEG at the same
    /// quality. It is never served to the web, where nothing but Safari decodes it.
    static func encodeHEIC(_ image: CGImage, quality: CGFloat = 0.72) -> Data? {
        encode(image, as: UTType.heic, quality: quality)
    }

    /// PNG when there is an alpha channel to preserve — a cutout's transparency
    /// is the whole point of the cutout.
    static func encodePNG(_ image: CGImage) -> Data? {
        encode(image, as: UTType.png, quality: 1)
    }

    private static func encode(_ image: CGImage, as type: UTType, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, type.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
