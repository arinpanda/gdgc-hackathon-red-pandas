import SwiftUI

struct ProfileView: View {
    @Environment(AccountStore.self) private var accountStore
    @Environment(VouchStore.self)   private var vouchStore
    @Environment(OrgStore.self)     private var orgStore
    let account: Account

    @State private var showCard       = false
    @State private var showScan       = false
    @State private var showDelete     = false
    @State private var showCreateOrg  = false
    @State private var showInvite     = false
    @State private var showScanInvite = false

    var body: some View {
        List {
            Section {
                LabeledContent("Trust", value: String(format: "%.2f", account.trustLevel))
                    .fontWeight(.semibold)
                LabeledContent("Age", value: "\(account.age)")
                LabeledContent("Profession") {
                    Text(account.profession.isEmpty ? "BASIC user" : account.profession)
                        .foregroundStyle(account.profession.isEmpty ? .secondary : .primary)
                }
                LabeledContent("Location", value: account.locale)
                LabeledContent("Key") {
                    Text(account.fingerprint()).font(.system(.footnote, design: .monospaced))
                }
                LabeledContent("User ID") {
                    Text(account.shortUserId()).font(.system(.footnote, design: .monospaced))
                }
                LabeledContent("Created", value: formattedDate(account.createdAt))
            }

            Section("Actions") {
                Button { showCard = true } label: {
                    Label("Show my card", systemImage: "qrcode")
                }
                Button { showScan = true } label: {
                    Label("Scan card", systemImage: "camera.viewfinder")
                }
                if account.isSuperuser {
                    Button { showCreateOrg = true } label: {
                        Label("Create organisation", systemImage: "building.2")
                    }
                }
                let myMemberships = orgStore.memberships(for: account.userId)
                if myMemberships.contains(where: { $0.canInvite }) {
                    Button { showInvite = true } label: {
                        Label("Show invite", systemImage: "person.badge.plus")
                    }
                }
                Button { showScanInvite = true } label: {
                    Label("Scan invite", systemImage: "qrcode.viewfinder")
                }
            }

            let myMemberships = orgStore.memberships(for: account.userId)
            if !myMemberships.isEmpty {
                Section("Organisations (\(myMemberships.count))") {
                    ForEach(myMemberships, id: \.orgId) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(orgStore.orgsById[m.orgId]?.name ?? String(m.orgId.prefix(8)))
                                .fontWeight(.medium)
                            Text(m.isFounder ? "founder" : "depth \(m.joinedAtDepth) · \(m.canInvite ? "can invite" : "leaf")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            let received = vouchStore.vouchesReceived(by: account.userId)
            let given    = vouchStore.vouchesGiven(by: account.userId)

            if !received.isEmpty {
                Section("Vouches received (\(received.count))") {
                    ForEach(received) { vouch in
                        VouchRow(vouch: vouch, accountsById: accountStore.accountsById, side: .received)
                    }
                }
            }

            if !given.isEmpty {
                Section("Vouches given (\(given.count))") {
                    ForEach(given) { vouch in
                        VouchRow(vouch: vouch, accountsById: accountStore.accountsById, side: .given)
                    }
                }
            }

            Section {
                Button("Delete account", role: .destructive) { showDelete = true }
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if account.isSuperuser {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("superuser")
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.8)).cornerRadius(5)
                }
            }
        }
        .sheet(isPresented: $showCard) { ShowCardView(account: account) }
        .sheet(isPresented: $showScan) { ScanCardView(active: account) }
        .sheet(isPresented: $showCreateOrg) { CreateOrgView(founder: account) }
        .sheet(isPresented: $showInvite) { ShowInviteView(account: account) }
        .sheet(isPresented: $showScanInvite) { ScanInviteView(active: account) }
        .confirmationDialog("Delete your account?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("Your identity key and all vouches will be permanently removed.")
        }
    }

    private func deleteAccount() {
        orgStore.removeMemberships(for: account.userId)
        vouchStore.removeVouches(involving: account.userId)
        accountStore.deleteAccount(account.userId)
        // AccountStore.accounts becomes empty → ContentView shows OnboardingView automatically.
    }

    private func formattedDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct VouchRow: View {
    let vouch: Vouch
    let accountsById: [String: Account]
    enum Side { case received, given }
    let side: Side

    private var otherId: String {
        side == .received ? vouch.voucherId : vouch.vouchedForId
    }

    private var otherLabel: String {
        accountsById[otherId]?.name ?? String(otherId.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(otherLabel).fontWeight(.medium)
            Text(String(format: "trust at time: %.2f  ·  +%.2f",
                        vouch.voucherTrustAtTime,
                        vouchDelta(vouch.voucherTrustAtTime)))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
