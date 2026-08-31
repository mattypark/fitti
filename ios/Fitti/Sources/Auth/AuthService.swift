import Foundation

/// Who is signed in.
struct Session: Equatable, Sendable {
    let userID: String
    let email: String?
    let displayName: String?
}

enum AuthMethod: String, CaseIterable, Sendable {
    case apple, magicLink, google
}

enum AuthError: LocalizedError {
    case cancelled
    case invalidEmail
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            // Not surfaced — a user who backed out does not need to be told.
            return nil
        case .invalidEmail:
            return "That doesn't look like an email address."
        case .failed(let reason):
            return reason
        }
    }
}

/// The boundary between the app and whoever is actually holding the session.
///
/// Everything downstream talks to this, so swapping the mock for Supabase later
/// touches one file rather than every screen. Same shape as the service protocols
/// in the other apps here.
protocol AuthService: Sendable {
    var currentSession: Session? { get async }

    func signInWithApple(identityToken: String, fullName: String?) async throws -> Session
    func sendMagicLink(to email: String) async throws
    func signInWithGoogle() async throws -> Session
    func signOut() async

    /// Permanently deletes the account and its server-side data.
    /// App Store guideline 5.1.1(v) — not optional for any app with accounts.
    func deleteAccount() async
}

/// Swap point. `AuthProvider.current = SupabaseAuthService()` once the SDK lands.
enum AuthProvider {
    static var current: any AuthService = MockAuthService()
}
