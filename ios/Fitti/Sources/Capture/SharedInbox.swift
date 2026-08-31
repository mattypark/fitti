import Foundation

/// The hand-off note between the share extension and the app.
///
/// Deliberately not the app's `CaptureQueue`: two processes appending to the same
/// file needs coordination, and getting that subtly wrong corrupts the user's
/// whole queue. A separate file that only the extension writes and only the app
/// drains has no such race.
enum SharedInbox {
    private static var url: URL { AppGroup.container.appending(path: "shared-inbox.txt") }

    static func append(filename: String) {
        guard let data = (filename + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Returns what the extension left and clears the note. Called on app launch.
    @discardableResult
    static func drain() -> [String] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        try? FileManager.default.removeItem(at: url)
        return contents.split(separator: "\n").map(String.init)
    }
}
