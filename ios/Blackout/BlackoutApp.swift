import SwiftUI

@main
struct BlackoutApp: App {
    @State private var accountStore = AccountStore()
    @State private var vouchStore   = VouchStore()
    @State private var orgStore     = OrgStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(accountStore)
                .environment(vouchStore)
                .environment(orgStore)
        }
    }
}
