import SwiftUI
import AuthenticationServices
import FittiDesign

/// The only screen a signed-out person sees.
///
/// No tour, no carousel, no "maybe later". Fitti is worthless without a closet
/// and a closet is worthless without somewhere to keep it, so the sign-in options
/// are the whole screen.
struct WelcomeView: View {
    var onSignedIn: (Session) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var linkSent = false
    @State private var error: String?
    @State private var busy = false

    private let palette = Palette(.butter)

    private static let tagline = "your closet, but it knows what's in it"

    var body: some View {
        WelcomeSequence(palette: palette, tagline: Self.tagline) { beat in
            content(beat)
        }
    }

    @ViewBuilder
    private func content(_ beat: WelcomeBeat) -> some View {
        ZStack {
            palette.ground.ignoresSafeArea()

            // The blobs are pushed outward by the landing, so the impact has a
            // consequence beyond the mascot itself.

            VStack(spacing: Space.lg) {
                #if DEBUG
                // Development only. Lets the app be driven without a real
                // account while the product is still being shaped. Compiled out
                // of release, so it cannot ship — a skip button in a shipped
                // build is a hidden feature under App Store guideline 2.3.1.
                HStack {
                    Spacer()
                    Button("Skip") {
                        onSignedIn(Session(userID: "local-preview",
                                           email: "you@fitti.app",
                                           displayName: "Matthew"))
                    }
                    .font(.fittiCallout)
                    .foregroundStyle(palette.onGroundSoft)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xxs)
                    .background(palette.groundLift, in: Capsule())
                }
                .padding(.top, Space.xs)
                #endif

                Spacer()

                RiveMascot(size: 130)
                    .scaleEffect(x: 2 - beat.mascotStretch, y: beat.mascotStretch,
                                 anchor: .bottom)
                    .offset(y: beat.mascotDrop)

                VStack(spacing: Space.xs) {
                    Text("Fitti")
                        .font(.fittiDisplay)
                        .foregroundStyle(palette.onGround)
                        .opacity(beat.wordmark)
                        .offset(y: (1 - beat.wordmark) * 18)

                    WritingText(text: Self.tagline,
                                visibleWords: beat.taglineWords,
                                palette: palette)
                    // Narrow enough to break into two balanced lines rather
                    // than one long line and an orphan.
                    .frame(maxWidth: 220)
                }

                Spacer()

                VStack(spacing: Space.sm) {
                    appleButton
                    magicLinkField
                    googleButton
                }
                .opacity(beat.controls)
                .offset(y: (1 - beat.controls) * 26)
                // Nothing is tappable until the app has finished introducing
                // itself — a button that moves under a finger is worse than a
                // button that arrives a moment later.
                .allowsHitTesting(beat.controls > 0.9)

                if let error {
                    Text(error)
                        .font(.fittiCallout)
                        .foregroundStyle(palette.accent)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Text("By continuing you agree to the Terms and Privacy Policy.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onGroundSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.xxs)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .animation(Motion.settle, value: linkSent)
        .animation(Motion.settle, value: error)
    }

    // MARK: - Apple

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                Task { await completeApple(auth) }
            case .failure(let failure):
                // Code 1001 is the user dismissing the sheet. Telling someone
                // "you cancelled" after they chose to cancel is noise.
                let nsError = failure as NSError
                if nsError.code != ASAuthorizationError.canceled.rawValue {
                    error = "Couldn't sign in with Apple. Try again?"
                }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    private func completeApple(_ auth: ASAuthorization) async {
        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            error = "Apple didn't return a usable sign-in. Try again?"
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        do {
            let session = try await AuthProvider.current.signInWithApple(
                identityToken: token,
                fullName: name.isEmpty ? nil : name
            )
            onSignedIn(session)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Magic link

    @ViewBuilder
    private var magicLinkField: some View {
        if linkSent {
            HStack(spacing: Space.xs) {
                Image(systemName: "envelope.badge")
                Text("Check \(email)")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.fittiCallout)
            .foregroundStyle(palette.onGround)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(palette.groundLift, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        } else {
            HStack(spacing: Space.xs) {
                // Drawn rather than using TextField's own placeholder. Neither
                // .foregroundStyle nor .tint reliably governs that placeholder's
                // colour, and it kept rendering in the system accent, which made
                // it read as a tappable link rather than as a hint.
                TextField("", text: $email)
                    .foregroundStyle(palette.onGround)
                    .overlay(alignment: .leading) {
                        if email.isEmpty {
                            Text("you@email.com")
                                .font(.fittiBody)
                                .foregroundStyle(palette.onGroundSoft)
                                .allowsHitTesting(false)
                        }
                    }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.fittiBody)
                    .foregroundStyle(palette.onGround)
                    .submitLabel(.go)
                    .onSubmit { Task { await sendLink() } }

                Button {
                    Task { await sendLink() }
                } label: {
                    Image(systemName: busy ? "ellipsis" : "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Fixed.ink)
                        .frame(width: 38, height: 38)
                        .background(Fixed.yellow, in: Circle())
                }
                .buttonStyle(.squash)
                .disabled(email.isEmpty || busy)
                .accessibilityLabel("Send sign-in link")
            }
            .padding(.horizontal, Space.sm)
            .frame(height: 52)
            .background(palette.groundLift, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .tint(palette.onGround)
        }
    }

    private func sendLink() async {
        busy = true
        defer { busy = false }
        do {
            try await AuthProvider.current.sendMagicLink(to: email)
            linkSent = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Google

    private var googleButton: some View {
        Button {
            Task {
                do { onSignedIn(try await AuthProvider.current.signInWithGoogle()) }
                catch { self.error = error.localizedDescription }
            }
        } label: {
            Text("Continue with Google")
                .font(.fittiHeadline)
                .foregroundStyle(palette.onGround)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(palette.groundLift, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(.squash)
    }
}
