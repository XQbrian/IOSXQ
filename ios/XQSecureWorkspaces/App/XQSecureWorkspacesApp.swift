import SwiftUI
import XQCore
import XQSecurity
import MSAL

@main
struct XQSecureWorkspacesApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var appTheme = AppTheme()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .environmentObject(appTheme)
                .preferredColorScheme(appTheme.mode.preferredColorScheme)
                .tint(appTheme.mode.brandColor)
                .onOpenURL { url in
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                ) { _ in coordinator.handleForeground() }
        }
    }
}
