import Foundation

/// Which auth service the app uses.
///
/// Same rule as the web side: the PRESENCE of configuration is the switch. With no
/// Supabase URL set the app runs on the mock and is fully usable offline; with one
/// set it talks to the real thing. No feature flag to fall out of sync with reality.
enum AuthConfiguration {
    static func install() {
        guard let urlString = value(for: "SUPABASE_URL"),
              let url = URL(string: urlString),
              let key = value(for: "SUPABASE_ANON_KEY"),
              !key.isEmpty else {
            return  // MockAuthService stays in place
        }
        AuthProvider.current = SupabaseAuthService(url: url, anonKey: key)
    }

    /// Read from Info.plist, populated at build time from an xcconfig. Keys never
    /// live in source, and the anon key is safe on a device by design — it is
    /// RLS-scoped and grants nothing on its own.
    private static func value(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !raw.isEmpty,
              !raw.hasPrefix("$(") else { return nil }
        return raw
    }
}
