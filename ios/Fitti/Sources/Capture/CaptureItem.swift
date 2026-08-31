import Foundation

/// One garment on its way into the closet.
///
/// The id is generated on device before a single byte moves, so a retried upload
/// is idempotent for free and the tile can be drawn with its final identity the
/// instant the shutter fires.
struct CaptureItem: Identifiable, Codable, Sendable, Equatable {
    enum State: String, Codable, Sendable {
        case pending      // bytes on disk, nothing done yet
        case deriving     // cutting out, downsampling
        case uploading
        case processing   // server is tagging and embedding
        case ready
        case failed
    }

    enum Source: String, Codable, Sendable {
        case camera, library, shareExtension
    }

    let id: UUID
    let source: Source
    let createdAt: Date

    /// Filename inside the App Group container, never an absolute path — the
    /// container's URL changes between app launches and OS upgrades, so a stored
    /// absolute path silently rots.
    var originalFile: String
    var thumbnailFile: String?
    var cutoutFile: String?

    var state: State
    var attempts: Int
    var nextAttemptAt: Date
    var lastError: String?

    init(source: Source, originalFile: String) {
        id = UUID()
        self.source = source
        createdAt = Date()
        self.originalFile = originalFile
        state = .pending
        attempts = 0
        nextAttemptAt = Date()
    }

    /// Exponential backoff with jitter, so a server hiccup doesn't produce a
    /// thundering herd when fifty queued items all retry on the same second.
    mutating func markFailed(_ reason: String) {
        attempts += 1
        lastError = reason
        state = attempts >= 6 ? .failed : .pending
        let delay = min(300, pow(2, Double(attempts)))
        nextAttemptAt = Date().addingTimeInterval(delay * (0.5 + Double.random(in: 0...0.5)))
    }
}
