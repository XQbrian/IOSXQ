import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppCoordinator.AppTab.home)

            FileBrowserView()
                .tabItem { Label("Files", systemImage: "folder.fill") }
                .tag(AppCoordinator.AppTab.files)

            EmailInboxView()
                .tabItem { Label("Email", systemImage: "envelope.fill") }
                .tag(AppCoordinator.AppTab.email)

            SharingCenterView()
                .tabItem { Label("Sharing", systemImage: "arrow.up.forward.circle.fill") }
                .tag(AppCoordinator.AppTab.sharing)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppCoordinator.AppTab.settings)
        }
        .tint(Color(red: 0.239, green: 0.353, blue: 0.996))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppCoordinator())
}
