import SwiftUI

struct ContentView: View {
    @Environment(AccountStore.self) private var accountStore

    var body: some View {
        if let account = accountStore.accounts.first {
            MainTabView(account: account)
        } else {
            OnboardingView()
        }
    }
}
