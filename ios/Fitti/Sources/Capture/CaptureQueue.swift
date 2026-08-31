import Foundation
import Observation

/// The durable queue between "shutter fired" and "garment exists".
///
/// The rule this enforces: between the tap and the UI updating there are exactly
/// two operations — one file write and one queue append. Cutting out,
/// downsampling, uploading and tagging all happen downstream. If any of them sat
/// on the tap, the app would feel exactly like the ones this product exists to
/// beat, where adding a piece takes minutes.
///
/// Persistence is an append-only log. A rewrite-the-whole-file store would rewrite
/// N records per capture, which is quadratic across a fifty-photo import; appending
/// is constant, and a truncated final line from a crash costs one record rather
/// than the entire queue.
actor CaptureQueue {
    static let shared = CaptureQueue()

    private var items: [UUID: CaptureItem] = [:]
    private var order: [UUID] = []
    private var loaded = false

    private var logURL: URL { AppGroup.container.appending(path: "queue.jsonl") }

    // MARK: - Reading

    func all() -> [CaptureItem] {
        load()
        return order.compactMap { items[$0] }
    }

    func pending() -> [CaptureItem] {
        let now = Date()
        return all().filter { $0.state == .pending && $0.nextAttemptAt <= now }
    }

    // MARK: - Writing

    /// The only thing on the critical path. Writes the bytes, appends one record,
    /// returns. Everything else is someone else's problem.
    @discardableResult
    func enqueue(_ data: Data, source: CaptureItem.Source) throws -> CaptureItem {
        load()
        let filename = "\(UUID().uuidString).heic"
        try data.write(to: AppGroup.url(for: filename), options: .atomic)

        let item = CaptureItem(source: source, originalFile: filename)
        append(item)
        return item
    }

    func update(_ item: CaptureItem) {
        load()
        append(item)
    }

    /// Drops the source bytes once the server has the item. This is what stops the
    /// app growing to several gigabytes: originals are the largest thing here and
    /// the only reason to keep one is that the upload has not landed yet.
    func discardOriginal(for id: UUID) {
        load()
        guard var item = items[id], item.state == .ready else { return }
        try? FileManager.default.removeItem(at: AppGroup.url(for: item.originalFile))
        item.originalFile = ""
        append(item)
    }

    // MARK: - Storage

    private func append(_ item: CaptureItem) {
        if items[item.id] == nil { order.append(item.id) }
        items[item.id] = item

        guard let line = try? JSONEncoder().encode(item) else { return }
        var record = line
        record.append(0x0A)

        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: record)
        } else {
            try? record.write(to: logURL, options: .atomic)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: logURL) else { return }

        let decoder = JSONDecoder()
        for line in data.split(separator: 0x0A) {
            // A later record for the same id supersedes an earlier one, so replaying
            // the log in order rebuilds the current state. A half-written final line
            // from a crash simply fails to decode and is skipped.
            guard let item = try? decoder.decode(CaptureItem.self, from: line) else { continue }
            if items[item.id] == nil { order.append(item.id) }
            items[item.id] = item
        }
    }

    /// Rewrites the log without superseded records. Cheap to run at launch; without
    /// it the file grows forever, since every state change appends.
    func compact() {
        load()
        let current = order.compactMap { items[$0] }
        var rebuilt = Data()
        let encoder = JSONEncoder()
        for item in current {
            guard let line = try? encoder.encode(item) else { continue }
            rebuilt.append(line)
            rebuilt.append(0x0A)
        }
        try? rebuilt.write(to: logURL, options: .atomic)
    }
}
