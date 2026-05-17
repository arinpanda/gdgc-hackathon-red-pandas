import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShowInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OrgStore.self) private var orgStore
    let account: Account

    @State private var selectedMembership: Membership?
    @State private var depth = 1
    @State private var invite: OrgInvite?
    @State private var busy  = false
    @State private var error: String?

    private var memberships: [Membership] {
        orgStore.memberships(for: account.userId).filter { $0.canInvite }
    }

    var body: some View {
        NavigationStack {
            Form {
                if memberships.isEmpty {
                    Section {
                        Text("You are not a member of any organisation, or you are a leaf member who cannot invite others.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Organisation") {
                        Picker("Select", selection: $selectedMembership) {
                            Text("Choose…").tag(Optional<Membership>.none)
                            ForEach(memberships, id: \.orgId) { m in
                                Text(orgStore.orgsById[m.orgId]?.name ?? m.orgId.prefix(8).description)
                                    .tag(Optional(m))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedMembership) { _, _ in
                            invite = nil
                            depth = 1
                        }
                    }

                    if let m = selectedMembership {
                        let maxDepth = min(10, m.maxIssuableDepth)
                        Section("Invite depth (1–\(maxDepth))") {
                            Stepper("Depth: \(depth)", value: $depth, in: 1...maxDepth)
                                .onChange(of: depth) { _, _ in invite = nil }
                            Text("Recipients at depth \(depth) can\(depth > 1 ? "" : "not") invite others.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }

                        Section {
                            Button(action: generate) {
                                if busy {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Text("Generate invite").frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(busy)
                        }
                    }

                    if let invite {
                        Section("QR Code") {
                            if let qr = qrImage(for: invite) {
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable().scaledToFit()
                                    .frame(maxWidth: 260)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        Section("JSON (paste into another device)") {
                            if let json = inviteJSON(invite) {
                                Text(json)
                                    .font(.system(.caption2, design: .monospaced))
                                    .lineLimit(6)
                                    .onTapGesture { UIPasteboard.general.string = json }
                                Button("Copy JSON") { UIPasteboard.general.string = json }
                            }
                        }
                    }

                    if let error {
                        Section {
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Show Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generate() {
        guard let m = selectedMembership else { return }
        busy = true; error = nil; invite = nil
        Task {
            defer { busy = false }
            do {
                invite = try await orgStore.createInvite(
                    for: m,
                    issuerUserId: account.userId,
                    issuerPublicKey: account.publicKey,
                    depth: depth
                )
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func inviteJSON(_ invite: OrgInvite) -> String? {
        guard let data = try? JSONEncoder().encode(invite) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func qrImage(for invite: OrgInvite) -> UIImage? {
        guard let json = inviteJSON(invite) else { return nil }
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message         = Data(json.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
