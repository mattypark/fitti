import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Bulk import from the photo library.
///
/// `PHPickerViewController` runs out of process and needs NO photo-library
/// permission at all — the user picks, and the app only ever receives what they
/// picked. That is one fewer scary permission prompt, less PII (it returns no
/// location data), and one fewer App Store review liability, all at once.
///
/// Fifty selections loaded as `UIImage` would be ~2.4GB of bitmaps and a jetsam
/// kill, so this loads file representations and copies bytes. Nothing is decoded
/// here; the worker downsamples from disk afterwards.
struct LibraryImport: UIViewControllerRepresentable {
    var onImported: (Int) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0            // unlimited
        config.selection = .ordered
        // Avoid a HEIC -> JPEG transcode on the way out; we want the original bytes.
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImported: onImported) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImported: (Int) -> Void
        init(onImported: @escaping (Int) -> Void) { self.onImported = onImported }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return onImported(0) }

            Task {
                var imported = 0
                for result in results {
                    guard let data = await Self.copyBytes(from: result.itemProvider) else { continue }
                    if (try? await CaptureQueue.shared.enqueue(data, source: .library)) != nil {
                        imported += 1
                    }
                }
                onImported(imported)
                await CaptureWorker.shared.drain()
            }
        }

        /// Reads the file representation as raw bytes. Never `loadObject(ofClass:)`.
        private static func copyBytes(from provider: NSItemProvider) async -> Data? {
            await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(
                    forTypeIdentifier: UTType.image.identifier
                ) { url, _ in
                    // The temp file dies when this closure returns, so read inside it.
                    guard let url, let data = try? Data(contentsOf: url) else {
                        return continuation.resume(returning: nil)
                    }
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
