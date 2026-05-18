import SwiftUI
import XQCore
import XQSecurity
import MSAL

@main
struct XQSecureWorkspacesApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .onOpenURL { url in
                    // Hand MSAL redirect URIs (msauth.<bundle-id>://auth) back to
                    // the MSAL runtime so it can complete the interactive sign-in flow.
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                ) { _ in coordinator.handleForeground() }
        }
    }
}
