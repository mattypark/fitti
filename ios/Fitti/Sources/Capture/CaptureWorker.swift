import Foundation
import CoreGraphics
import ImageIO

/// Drains the queue in the background: derive a thumbnail, lift the garment out,
/// mark it ready.
///
/// Concurrency is capped at two, and the cap is a MEMORY budget rather than a CPU
/// one. Each in-flight item decodes at most a 2048px image (~16MB), so two is
/// comfortable and four starts to be risky on older phones under memory pressure.
/// `activeProcessorCount` would suggest eight and get the app killed.
actor CaptureWorker {
    static let shared = CaptureWorker()

    private var running = false
    private let maxConcurrent = 2

    func drain() async {
        guard !running else { return }
        running = true
        defer { running = false }

        var work = await CaptureQueue.shared.pending()
        while !work.isEmpty {
            let batch = Array(work.prefix(maxConcurrent))
            work.removeFirst(batch.count)

            await withTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask { await Self.process(item) }
                }
            }
        }
    }

    private static func process(_ item: CaptureItem) async {
        var item = item
        item.state = .deriving
        await CaptureQueue.shared.update(item)

        let source = AppGroup.url(for: item.originalFile)

        // Thumbnail first. It is what the grid draws, so producing it early is
        // what makes a just-captured tile appear filled rather than blank.
        guard let thumb = ImagePipeline.downsample(fileAt: source,
                                                   maxPixelSize: ImagePipeline.Rung.thumbnail),
              let thumbData = ImagePipeline.encodeHEIC(thumb) else {
            item.markFailed("Couldn't read that photo.")
            await CaptureQueue.shared.update(item)
            return
        }

        let thumbName = "\(item.id.uuidString)-thumb.heic"
        try? thumbData.write(to: AppGroup.url(for: thumbName), options: .atomic)
        item.thumbnailFile = thumbName
        await CaptureQueue.shared.update(item)

        // Then the cutout, from the 2048px master rather than the full-resolution
        // original — Vision gains nothing from the extra pixels and costs time.
        if let master = ImagePipeline.downsample(fileAt: source,
                                                 maxPixelSize: ImagePipeline.Rung.master) {
            do {
                if let cut = try await CutoutProvider.current.cutout(from: master),
                   let cutData = ImagePipeline.encodePNG(cut) {
                    let cutName = "\(item.id.uuidString)-cutout.png"
                    try? cutData.write(to: AppGroup.url(for: cutName), options: .atomic)
                    item.cutoutFile = cutName
                }
            } catch {
                // A failed cutout is not a failed capture. The garment is still in
                // the closet, just with its background — better than losing it.
                item.lastError = "Kept the original; couldn't cut it out."
            }
        }

        item.state = .ready
        await CaptureQueue.shared.update(item)
    }
}
