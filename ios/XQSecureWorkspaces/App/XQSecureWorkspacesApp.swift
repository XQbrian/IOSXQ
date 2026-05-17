import SwiftUI
import XQCore
import XQSecurity

@main
struct XQSecureWorkspacesApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                ) { _ in coordinator.handleForeground() }
        }
    }
}
