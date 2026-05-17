import SwiftUI

struct HistoryView: View {
    @Environment(VouchStore.self)   private var vouchStore
    @Environment(AccountStore.self) private var accountStore
    let account: Account

    private enum Direction { case received, given }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verification History")
                        .font(.title2.bold())
                        .foregroundStyle(Color.black)
                    Text("Log of peer-to-peer trust exchanges.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appOnSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                let entries = combinedEntries()
                if entries.isEmpty {
                    emptyState
                } else {
                    ForEach(entries, id: \.vouch.id) { entry in
                        historyCard(entry.vouch, direction: entry.direction)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Data

    private struct Entry {
        let vouch: Vouch
        let direction: Direction
    }

    private func combinedEntries() -> [Entry] {
        let recv = vouchStore.vouchesReceived(by: account.userId)
            .map { Entry(vouch: $0, direction: .received) }
        let given = vouchStore.vouchesGiven(by: account.userId)
            .map { Entry(vouch: $0, direction: .given) }
        return (recv + given).sorted { $0.vouch.createdAt > $1.vouch.createdAt }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52))
                .foregroundStyle(Color.appOnSurfaceVariant.opacity(0.4))
            Text("No exchanges yet")
                .font(.headline)
                .foregroundStyle(Color.appOnSurfaceVariant)
            Text("Give or receive trust vouches and they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(Color.appOnSurfaceVariant.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Card

    private func historyCard(_ vouch: Vouch, direction: Direction) -> some View {
        let otherId   = direction == .received ? vouch.voucherId : vouch.vouchedForId
        let otherName = accountStore.accountsById[otherId]?.name ?? String(otherId.prefix(8))
        let otherProf = accountStore.accountsById[otherId]?.profession ?? ""
        let delta     = vouchDelta(vouch.voucherTrustAtTime)
        let received  = direction == .received

        return HStack(spacing: 0) {
            // Accent stripe
            Rectangle()
                .fill(Color.black)
                .frame(width: 4)
                .clipShape(
                    .rect(topLeadingRadius: 12, bottomLeadingRadius: 12)
                )

            VStack(spacing: 10) {
                // Top row: avatar + name + badge
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appSurfaceContainer)
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(Color.appOnSurfaceVariant)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(otherName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black)
                        Text(otherProf.isEmpty ? (received ? "Vouched for you" : "You vouched") : otherProf)
                            .font(.footnote)
                            .foregroundStyle(Color.appOnSurfaceVariant)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text(received
                             ? "+\(String(format: "%.1f", delta))"
                             : "Given")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appSurfaceLow)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.appSurfaceDim, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                // Timestamp footer
                Divider()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                    Text(formattedDate(vouch.createdAt))
                        .font(.footnote)
                    Spacer()
                }
                .foregroundStyle(Color.appOnSurfaceVariant)
            }
            .padding(14)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func formattedDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
