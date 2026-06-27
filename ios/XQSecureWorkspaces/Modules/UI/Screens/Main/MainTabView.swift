import SwiftUI

/// Bottom-nav shell. Mirrors the prototype's 5-tab IA:
///   Home · Files · Email · Sharing · Settings
/// Profile is reached from the top-right avatar on each top-level screen,
/// presented as a sheet via AppCoordinator.
struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {

            HomeView()
                .tabItem {
                    Label("Home",
                          systemImage: coordinator.selectedTab == .home
                              ? "house.fill" : "house")
                }
                .tag(AppCoordinator.AppTab.home)

            FileBrowserView()
                .tabItem {
                    Label("Files",
                          systemImage: coordinator.selectedTab == .files
                              ? "folder.fill" : "folder")
                }
                .tag(AppCoordinator.AppTab.files)

            EmailInboxView()
                .tabItem {
                    Label("Email",
                          systemImage: coordinator.selectedTab == .email
                              ? "envelope.fill" : "envelope")
                }
                .tag(AppCoordinator.AppTab.email)

            SharingCenterView()
                .tabItem {
                    Label("Sharing",
                          systemImage: coordinator.selectedTab == .sharing
                              ? "arrowshape.turn.up.right.fill"
                              : "arrowshape.turn.up.right")
                }
                .tag(AppCoordinator.AppTab.sharing)

            SettingsView()
                .tabItem {
                    Label("Settings",
                          systemImage: coordinator.selectedTab == .settings
                              ? "gearshape.fill" : "gearshape")
                }
                .tag(AppCoordinator.AppTab.settings)
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
        .environmentObject(AppTheme())
}
