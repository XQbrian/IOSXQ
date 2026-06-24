import SwiftUI

/// Bottom-nav shell. Mirrors the prototype's 3-tab IA:
///   Files · Messages · Now
/// Profile is reached from the top-right avatar on each top-level screen
/// (the prototype's pattern), presented as a sheet via AppCoordinator.
/// The AI tab was merged into Now → Ask; the Settings tab was consolidated
/// into Profile. `AppTab.ai` and `AppTab.settings` remain in the enum for
/// back-compat with other code that still references them.
struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            FileBrowserView()
                .tabItem {
                    let on = coordinator.selectedTab == .files
                    Label("Files", systemImage: on ? AppIcon.filesFill : AppIcon.files)
                }
                .tag(AppCoordinator.AppTab.files)

            EmailInboxView()
                .tabItem {
                    let on = coordinator.selectedTab == .messages
                    Label("Messages", systemImage: on ? AppIcon.messagesFill : AppIcon.messages)
                }
                .tag(AppCoordinator.AppTab.messages)

            NowTabView()
                .tabItem {
                    let on = coordinator.selectedTab == .alerts
                    Label("Now", systemImage: on ? AppIcon.alertsFill : AppIcon.alerts)
                }
                .tag(AppCoordinator.AppTab.alerts)
        }
        .tint(Color(red: 0.239, green: 0.353, blue: 0.996))
        .sheet(isPresented: $coordinator.showingProfile) {
            ProfileView()
                .environmentObject(coordinator)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppCoordinator())
}
