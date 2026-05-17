import SwiftUI
import VisionKit

struct ScanInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OrgStore.self)   private var orgStore
    let active: Account

    @State private var pastedJSON = ""
    @State private var busy       = false
    @State private var error: String?
    @State private var success    = false

    private var useCamera: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if useCamera {
                    cameraLayout
                } else {
                    pasteLayout
                }
            }
            .navigationTitle("Scan Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Joined!", isPresented: $success) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(active.name) has joined the organisation.")
            }
        }
    }

    private var cameraLayout: some View {
        ZStack(alignment: .bottom) {
            DataScannerView { scanned in
                guard !busy else { return }
                Task { await handleJSON(scanned) }
            }
            .ignoresSafeArea(edges: .bottom)
            if let error {
                Text(error)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
            }
        }
    }

    private var pasteLayout: some View {
        Form {
            Section {
                Text("Paste the invite JSON from another device. The full chain back to the founder will be verified.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Paste invite JSON") {
                TextEditor(text: $pastedJSON)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 180)
            }
            Section {
                Button(action: { Task { await handleJSON(pastedJSON) } }) {
                    if busy {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Verify & join").frame(maxWidth: .infinity)
                    }
                }
                .disabled(pastedJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            }
            if let error {
                Section {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
        }
    }

    private func handleJSON(_ json: String) async {
        busy = true; error = nil
        defer { busy = false }
        guard let data = json.data(using: .utf8),
              let invite = try? JSONDecoder().decode(OrgInvite.self, from: data) else {
            error = "Could not parse invite — make sure you pasted valid JSON."
            return
        }
        do {
            try await orgStore.acceptInvite(invite, as: active.userId)
            success = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
