import SwiftUI

@main
struct FittiApp: App {
    init() {
        // Swaps the mock for Supabase when the app is configured for it.
        AuthConfiguration.install()
    }

    var body: some Scene {
        WindowGroup {
            RootGate()
                .onOpenURL { url in
                    // Magic links and Google both return here.
                    Task {
                        if let service = AuthProvider.current as? SupabaseAuthService {
                            _ = try? await service.handleCallback(url)
                        }
                    }
                }
        }
    }
}
