import UIKit
import UniformTypeIdentifiers

/// Save clothes from Instagram, TikTok or Safari without opening Fitti.
///
/// A share extension gets roughly 120MB — a fraction of what the host app gets —
/// and going over is not an exception you can catch: the kernel kills the process
/// and the sheet simply vanishes with no crash report. A 4032x3024 photo decoded
/// to a bitmap is ~49MB, and re-encoding it holds two of those at once, so the
/// naive `UIImage(data:)` + `jpegData()` path works on screenshots in testing and
/// dies on the first user who shares a portrait photo.
///
/// So this extension NEVER decodes. It copies bytes into the shared container,
/// appends a queue record, and exits — target under half a second. The host app
/// does all the real work on next launch.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleAttachments()
    }

    private func handleAttachments() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments else {
            return finish()
        }

        let group = DispatchGroup()
        var saved = 0

        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            group.enter()

            // loadFileRepresentation, not loadObject(ofClass: UIImage.self).
            // The former hands back a temp file — a byte copy, zero decode. The
            // latter is exactly the decode that gets the extension killed.
            provider.loadFileRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { url, _ in
                defer { group.leave() }
                guard let url else { return }

                // The temp file is deleted the moment this closure returns, so
                // the copy has to happen inside it.
                let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                let filename = "\(UUID().uuidString).\(ext)"
                let destination = AppGroup.url(for: filename)

                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    SharedInbox.append(filename: filename)
                    saved += 1
                } catch {
                    // One failed attachment should not take the rest with it.
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finish(saved: saved)
        }
    }

    private func finish(saved: Int = 0) {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
