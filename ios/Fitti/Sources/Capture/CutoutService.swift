import Foundation
import Vision
import CoreImage

/// Lifts a garment off its background, on device.
///
/// `GenerateForegroundInstanceMaskRequest` is the API behind iOS "lift subject
/// from photo". It runs on the Neural Engine in a few hundred milliseconds, costs
/// nothing, works offline, and the photo never leaves the phone. Doing this in the
/// cloud instead would be roughly $9,000/month at ten thousand users — see
/// docs/DECISIONS.md.
protocol CutoutService: Sendable {
    /// Returns a transparent-background cutout, cropped to the garment, or nil if
    /// no subject was found.
    func cutout(from image: CGImage) async throws -> CGImage?
}

enum CutoutError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Couldn't separate the garment on this device."
    }
}

struct VisionCutoutService: CutoutService {
    private let context = CIContext()

    func cutout(from image: CGImage) async throws -> CGImage? {
        // Vision's subject lifting does not exist in the Simulator — it fails with
        // "Could not create inference context". Returning nil lets the pipeline
        // keep the original photo and carry on, so the app is still usable there.
        #if targetEnvironment(simulator)
        return nil
        #else
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty else { return nil }

        // croppedToInstancesExtent trims to the garment's own bounds. Doing this
        // once here rather than at render time is what keeps every tile in the
        // grid framed identically — otherwise each variant is padded differently
        // and the closet never lines up.
        let masked = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )

        let ciImage = CIImage(cvPixelBuffer: masked)
        return context.createCGImage(ciImage, from: ciImage.extent)
        #endif
    }
}

/// Swap point for the cloud fallback (BiRefNet) used by web uploads.
enum CutoutProvider {
    /// Set at launch, never afterwards. See the note on `AuthProvider.current`.
    nonisolated(unsafe) static var current: any CutoutService = VisionCutoutService()
}
