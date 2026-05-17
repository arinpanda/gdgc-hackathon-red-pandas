import SwiftUI

struct MainTabView: View {
    let account: Account

    var body: some View {
        TabView {
            NavigationStack {
                IdentityView(account: account)
            }
            .tabItem { Label("Identity", systemImage: "touchid") }

            NavigationStack {
                TrustView(account: account)
            }
            .tabItem { Label("Trust", systemImage: "qrcode") }

            NavigationStack {
                HistoryView(account: account)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                SettingsView(account: account)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.black)
    }
}
