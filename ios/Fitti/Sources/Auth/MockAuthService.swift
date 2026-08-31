import Foundation

/// Signs anyone in, locally, with no network and no keys.
///
/// This is the same "runs with zero configuration" rule the rest of the codebase
/// follows: absence of credentials switches to a working local path rather than
/// producing a dead screen. It means the app is demoable and the UI is reviewable
/// before a Supabase project exists.
actor MockAuthService: AuthService {
    private var session: Session?
    private let store = UserDefaults.standard
    private let key = "fitti.mock.session"

    init() {
        if let saved = store.dictionary(forKey: key),
           let id = saved["id"] as? String {
            session = Session(userID: id,
                              email: saved["email"] as? String,
                              displayName: saved["name"] as? String)
        }
    }

    var currentSession: Session? { session }

    func signInWithApple(identityToken: String, fullName: String?) async throws -> Session {
        // Apple only returns a name on the very first authorization, ever. Keeping
        // whatever we already stored avoids blanking it on subsequent sign-ins —
        // a bug that is invisible in testing and permanent in production.
        return persist(Session(userID: "apple-\(identityToken.prefix(12))",
                        email: session?.email,
                        displayName: fullName ?? session?.displayName))
    }

    func sendMagicLink(to email: String) async throws {
        guard email.contains("@"), email.contains(".") else { throw AuthError.invalidEmail }
        try? await Task.sleep(for: .milliseconds(600))
    }

    func signInWithGoogle() async throws -> Session {
        try? await Task.sleep(for: .milliseconds(400))
        return persist(Session(userID: "google-local",
                               email: "you@example.com",
                               displayName: nil))
    }

    func signOut() async {
        session = nil
        store.removeObject(forKey: key)
    }

    func deleteAccount() async {
        await signOut()
    }

    @discardableResult
    private func persist(_ new: Session) -> Session {
        session = new
        store.set(["id": new.userID,
                   "email": new.email as Any,
                   "name": new.displayName as Any], forKey: key)
        return new
    }
}
