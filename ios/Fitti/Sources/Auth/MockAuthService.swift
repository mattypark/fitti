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
        #if DEBUG
        // Screenshot and UI-test affordance: start signed in so automation can
        // reach the tabs without driving the sign-in screen. DEBUG-only, so it
        // cannot ship — a launch argument that survived into release would be a
        // hidden feature under App Store guideline 2.3.1.
        if ProcessInfo.processInfo.arguments.contains("-fittiSignedIn") {
            session = Session(userID: "preview-user",
                              email: "you@fitti.app",
                              displayName: "Matthew")
            return
        }
        #endif

        if let saved = store.dictionary(forKey: key) as? [String: String],
           let id = saved["id"] {
            session = Session(userID: id,
                              email: saved["email"],
                              displayName: saved["name"])
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

        // Only real values go in. `nil as Any` is not a property-list type, and
        // UserDefaults throws rather than skipping it — which is how signing in
        // with Apple crashed the app, since Apple returns no email on any sign-in
        // after the first.
        var stored: [String: String] = ["id": new.userID]
        if let email = new.email { stored["email"] = email }
        if let name = new.displayName { stored["name"] = name }
        store.set(stored, forKey: key)

        return new
    }
}
