import SwiftUI
import VisionKit
import AVFoundation

struct ScanCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountStore.self) private var accountStore
    @Environment(VouchStore.self)   private var vouchStore
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
            .navigationTitle("Scan Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Trust received!", isPresented: $success) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(active.name)'s trust level has been updated.")
            }
        }
    }

    // MARK: - Camera layout (real device)

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

    // MARK: - Paste layout (simulator / fallback)

    private var pasteLayout: some View {
        Form {
            Section {
                Text("Camera not available. Paste the JSON from another account's card below.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Paste token JSON") {
                TextEditor(text: $pastedJSON)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 180)
            }
            Section {
                Button(action: { Task { await handleJSON(pastedJSON) } }) {
                    if busy {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Verify & receive trust").frame(maxWidth: .infinity)
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

    // MARK: - Token handling

    private func handleJSON(_ json: String) async {
        busy  = true
        error = nil
        defer { busy = false }

        guard let data = json.data(using: .utf8),
              let token = try? JSONDecoder().decode(VouchToken.self, from: data) else {
            error = "Could not parse token — make sure you pasted valid JSON."
            return
        }

        do {
            try await vouchStore.receiveToken(token, as: active, accountStore: accountStore)
            success = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - DataScanner wrapper

struct DataScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel:        .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var lastScanned: String?

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard case .barcode(let b) = addedItems.first,
                  let val = b.payloadStringValue,
                  val != lastScanned else { return }
            lastScanned = val
            onScan(val)
        }
    }
}
