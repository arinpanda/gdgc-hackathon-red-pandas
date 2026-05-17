import SwiftUI

struct AccountListView: View {
    @Environment(AccountStore.self) private var accountStore
    @Binding var selectedUserId: String?
    var onNew: () -> Void
    var onWipe: () -> Void

    var body: some View {
        List(accountStore.accounts, selection: $selectedUserId) { account in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(account.name).fontWeight(.medium)
                    if account.isSuperuser {
                        Text("super").font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.8)).cornerRadius(4)
                    }
                    if account.userId == accountStore.activeUserId {
                        Text("active").font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.accentColor).foregroundStyle(.white).cornerRadius(4)
                    }
                }
                Text(String(format: "Trust %.2f", account.trustLevel))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .tag(account.userId)
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNew) { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Wipe all", role: .destructive, action: onWipe)
                    .font(.footnote)
            }
        }
    }
}
