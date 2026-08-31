import Foundation
import Supabase

/// Real auth, against Supabase.
///
/// The session lives in the Keychain rather than UserDefaults, and token refresh
/// is the SDK's job — that pair is the entire reason to take the dependency
/// instead of hand-rolling OAuth. Auth bugs live in refresh logic.
actor SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    var currentSession: Session? {
        get async {
            guard let session = try? await client.auth.session else { return nil }
            return Self.map(session.user)
        }
    }

    func signInWithApple(identityToken: String, fullName: String?) async throws -> Session {
        let response = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: identityToken)
        )

        // Apple hands over a name only on the very first authorization, ever, so
        // it is stored the one time it appears. Overwriting with nil on a later
        // sign-in would erase it permanently.
        if let fullName, !fullName.isEmpty {
            try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(fullName)]))
        }

        return Self.map(response.user)
    }

    func sendMagicLink(to email: String) async throws {
        guard email.contains("@"), email.contains(".") else { throw AuthError.invalidEmail }
        do {
            try await client.auth.signInWithOTP(email: email, redirectTo: URL(string: "fitti://auth-callback"))
        } catch {
            throw AuthError.failed("Couldn't send that link. Check the address?")
        }
    }

    func signInWithGoogle() async throws -> Session {
        // Google goes through the browser, so the app cannot return a session
        // synchronously — it arrives via the fitti:// callback below.
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "fitti://auth-callback")
        )
        guard let session = await currentSession else {
            throw AuthError.failed("Google sign-in didn't complete.")
        }
        return session
    }

    /// Called from the app's URL handler when the browser hands control back.
    func handleCallback(_ url: URL) async throws -> Session {
        try await client.auth.session(from: url)
        guard let session = await currentSession else {
            throw AuthError.failed("That sign-in link has expired.")
        }
        return session
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    private static func map(_ user: User) -> Session {
        Session(
            userID: user.id.uuidString,
            email: user.email,
            displayName: user.userMetadata["full_name"]?.stringValue
        )
    }
}
