import SwiftUI

struct IdentityView: View {
    @Environment(AccountStore.self) private var accountStore
    @Environment(OrgStore.self)     private var orgStore
    let account: Account

    @State private var personalInfoExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeaderCard
                let memberships = orgStore.memberships(for: account.userId)
                if !memberships.isEmpty { orgRoleCard(memberships) }
                trustLevelCard
                personalInfoCard
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .navigationTitle("Identity")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if account.isSuperuser {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("superuser")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    // MARK: - Profile header

    private var profileHeaderCard: some View {
        HStack(spacing: 16) {
            avatarView(size: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text(account.name)
                    .font(.title3.bold())
                    .foregroundStyle(Color.appOnSurface)

                if !account.profession.isEmpty {
                    Text(account.profession)
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill").font(.caption)
                    Text("Verified Identity").font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.appVerifiedFg)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.appVerifiedBg)
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Organisation + Role

    private func orgRoleCard(_ memberships: [Membership]) -> some View {
        VStack(spacing: 0) {
            ForEach(memberships, id: \.orgId) { m in
                let orgName = orgStore.orgsById[m.orgId]?.name ?? String(m.orgId.prefix(8))
                let role    = m.isFounder ? "Founder" : (m.canInvite ? "Member (can invite)" : "Member")

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appSurfaceContainer)
                            .frame(width: 44, height: 44)
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.black)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(orgName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.appOnSurface)
                        Text(role)
                            .font(.footnote)
                            .foregroundStyle(Color.appOnSurfaceVariant)
                    }

                    Spacer()

                    Text(m.isFounder ? "FOUNDER" : "MEMBER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(m.isFounder
                                    ? Color.black
                                    : Color.appSecondaryContainer)
                        .foregroundStyle(m.isFounder ? Color.white : Color.appOnSecContainer)
                        .clipShape(Capsule())
                }
                .padding(16)

                if m.orgId != memberships.last?.orgId {
                    Divider().padding(.leading, 74)
                }
            }
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Trust Level

    private var trustLevelCard: some View {
        let ratio = account.trustLevel / 1000.0
        let color = trustColor(ratio: ratio)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trust Level")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appOnSurface)
                Spacer()
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(color)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", account.trustLevel))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ 1000")
                    .font(.subheadline.weight(.medium))
                    .tracking(1)
                    .foregroundStyle(Color.appSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.appSurfaceContainer)
                        .frame(height: 8)

                    LinearGradient(
                        colors: [
                            Color(hex: "dc2626"),
                            Color(hex: "f97316"),
                            Color(hex: "eab308"),
                            Color(hex: "22c55e"),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(
                        width: max(8, geo.size.width * CGFloat(ratio)),
                        height: 8
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .frame(height: 8)

            HStack {
                Text("Low").font(.caption).foregroundStyle(Color(hex: "dc2626"))
                Spacer()
                Text("High").font(.caption).foregroundStyle(Color(hex: "22c55e"))
            }
        }
        .padding(20)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Personal Information (collapsible)

    private var personalInfoCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    personalInfoExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.text.rectangle")
                            .font(.subheadline)
                        Text("Personal Information")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(Color.black)

                    Spacer()

                    Image(systemName: personalInfoExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appOnSurfaceVariant)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if personalInfoExpanded {
                Divider()
                infoRow(label: "USER ID",   value: account.shortUserId(), monospace: true)
                Divider().padding(.leading, 16)
                infoRow(label: "LOCATION",  value: account.locale.isEmpty ? "—" : account.locale, monospace: false)
                Divider().padding(.leading, 16)
                infoRow(label: "OCCUPATION", value: account.profession.isEmpty ? "—" : account.profession, monospace: false)
                Divider().padding(.leading, 16)
                infoRow(label: "AGE",        value: "\(account.age)", monospace: false)
                Divider().padding(.leading, 16)
                infoRow(label: "KEY",        value: account.fingerprint(), monospace: true)
                Divider().padding(.leading, 16)
                infoRow(label: "CREATED",    value: formattedDate(account.createdAt), monospace: false)
            }
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        if let img = account.profileUIImage() {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appSurfaceHigh, lineWidth: 2))
        } else {
            InitialsAvatar(name: account.name, size: size)
        }
    }

    private func infoRow(label: String, value: String, monospace: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Color.appOnSurfaceVariant)
                Text(value)
                    .font(monospace
                          ? .system(.subheadline, design: .monospaced)
                          : .subheadline)
                    .foregroundStyle(Color.black)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
    }

    private func formattedDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Smooth red → yellow → green interpolation.
    private func trustColor(ratio: Double) -> Color {
        let r = max(0, min(1, ratio))
        if r < 0.5 {
            let t = r / 0.5
            return Color(
                red:   0.86,
                green: 0.09 + t * 0.65,
                blue:  0.09 - t * 0.05
            )
        } else {
            let t = (r - 0.5) / 0.5
            return Color(
                red:   0.86 - t * 0.73,
                green: 0.74 - t * 0.01,
                blue:  0.04 + t * 0.25
            )
        }
    }
}
