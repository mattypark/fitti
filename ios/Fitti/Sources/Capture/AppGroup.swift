import Foundation

/// The shared container. The share extension writes here and the app drains it,
/// which is the only way the two can hand work to each other.
enum AppGroup {
    static let identifier = "group.com.matthewpark.fitti"

    /// Falls back to the app's own Documents directory when the App Group is not
    /// provisioned — which is the case until the capability is added in the
    /// developer portal. The app then works normally; only the share extension
    /// would be unable to hand items over.
    static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? URL.documentsDirectory
    }

    static var inbox: URL {
        let url = container.appending(path: "inbox", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // Derived data. Excluding it from backup keeps a multi-gigabyte capture
        // queue out of the user's iCloud.
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
        return url
    }

    static func url(for file: String) -> URL {
        inbox.appending(path: file)
    }
}
