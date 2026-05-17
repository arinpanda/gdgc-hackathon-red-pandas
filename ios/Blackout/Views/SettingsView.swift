import SwiftUI

struct SettingsView: View {
    @Environment(AccountStore.self) private var accountStore
    @Environment(VouchStore.self)   private var vouchStore
    @Environment(OrgStore.self)     private var orgStore
    let account: Account

    @State private var showCreateOrg  = false
    @State private var showInvite     = false
    @State private var showScanInvite = false
    @State private var showDelete     = false

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Name", value: account.name)
                LabeledContent("Age", value: "\(account.age)")
                LabeledContent("Location", value: account.locale.isEmpty ? "—" : account.locale)
                LabeledContent("Key") {
                    Text(account.fingerprint())
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Color.appOnSurfaceVariant)
                }
                LabeledContent("Created", value: formattedDate(account.createdAt))
            }

            Section("Organisation") {
                if account.isSuperuser {
                    Button { showCreateOrg = true } label: {
                        Label("Create Organisation", systemImage: "building.2")
                    }
                }
                let memberships = orgStore.memberships(for: account.userId)
                if memberships.contains(where: { $0.canInvite }) {
                    Button { showInvite = true } label: {
                        Label("Show Invite QR", systemImage: "person.badge.plus")
                    }
                }
                Button { showScanInvite = true } label: {
                    Label("Scan Org Invite", systemImage: "qrcode.viewfinder")
                }
            }

            Section {
                Button("Delete Account", role: .destructive) {
                    showDelete = true
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showCreateOrg)  { CreateOrgView(founder: account) }
        .sheet(isPresented: $showInvite)     { ShowInviteView(account: account) }
        .sheet(isPresented: $showScanInvite) { ScanInviteView(active: account) }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("Your identity key and all vouches will be permanently removed.")
        }
    }

    private func deleteAccount() {
        orgStore.removeMemberships(for: account.userId)
        vouchStore.removeVouches(involving: account.userId)
        accountStore.deleteAccount(account.userId)
    }

    private func formattedDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
