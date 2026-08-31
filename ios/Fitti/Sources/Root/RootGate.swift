import SwiftUI
import FittiDesign

/// Signed out or signed in. Nothing in Fitti works without an account, so this is
/// the first thing the app decides.
struct RootGate: View {
    @State private var session: Session?
    @State private var checking = true

    var body: some View {
        Group {
            if checking {
                // A brief, quiet hold while the stored session is read. Showing
                // the welcome screen first and then yanking it away would flash
                // a sign-in prompt at someone who is already signed in.
                ZStack {
                    Palette(.butter).ground.ignoresSafeArea()
                    Mascot(size: 96)
                }
            } else if let session {
                RootView(session: session) {
                    Task {
                        await AuthProvider.current.signOut()
                        withAnimation(Motion.settle) { self.session = nil }
                    }
                }
            } else {
                WelcomeView { newSession in
                    withAnimation(Motion.settle) { session = newSession }
                }
                .transition(.opacity)
                // Without this the system accent leaks into text fields and
                // makes placeholder text look like a link.
                .tint(Palette(.butter).onGround)
            }
        }
        .task {
            session = await AuthProvider.current.currentSession
            checking = false
        }
    }
}
