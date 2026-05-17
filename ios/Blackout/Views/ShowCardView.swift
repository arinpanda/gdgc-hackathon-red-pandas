import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShowCardView: View {
    @Environment(\.dismiss) private var dismiss
    let account: Account

    @State private var token:      VouchToken?
    @State private var qrImage:    UIImage?      // cached — only recomputed when token changes
    @State private var error:      String?
    @State private var secondsLeft: Double = 0
    @State private var selectedTTL: Double = 120 // user-adjustable

    private let ttlOptions: [(label: String, seconds: Double)] = [
        ("2 min",  120),
        ("5 min",  300),
        ("15 min", 900),
        ("1 hr",   3600),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // TTL picker
                Picker("Lifetime", selection: $selectedTTL) {
                    ForEach(ttlOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedTTL) { _, _ in Task { await regenerate() } }

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)

                    VStack(spacing: 4) {
                        Text("\(account.name) is vouching")
                            .font(.headline)
                        if let token {
                            Text(String(format: "Trust at issuance: %.2f", token.voucherTrustAtTime))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(secondsLeft > 0 ? "Valid for \(Int(secondsLeft))s" : "Expired")
                            .font(.caption)
                            .foregroundStyle(secondsLeft < 30 ? .red : .secondary)
                    }

                    Button("Regenerate") { Task { await regenerate() } }
                        .buttonStyle(.bordered)

                } else if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ProgressView("Generating…")
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("My Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await regenerate() }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                // Only decrement the counter — never touch token or qrImage here.
                if secondsLeft > 0 { secondsLeft -= 1 }
            }
        }
    }

    // MARK: - Token creation

    private func regenerate() async {
        error = nil
        // Don't nil out qrImage here — keep showing old QR while generating new one.

        let ttl      = selectedTTL
        let nonce    = randomNonce()
        let issuedAt = ISO8601DateFormatter().string(from: Date())

        let payload = CanonicalJSON.encode([
            "issuedAt"           : .string(issuedAt),
            "name"               : .string(account.name),
            "nonce"              : .string(nonce),
            "voucherId"          : .string(account.userId),
            "voucherPublicKey"   : .string(account.publicKey),
            "voucherTrustAtTime" : .number(account.trustLevel),
        ])

        do {
            let sig = try IdentityKey.sign(userId: account.userId, data: payload)
            // Build a VouchToken with a custom expiry baked into issuedAt offset.
            // The standard TTL field is 120s; for longer lifetimes we shift issuedAt
            // backwards so that issuedAt + ttl = now + ttl from the scanner's perspective.
            // Simpler: store ttl alongside the token and pass it to the verifier.
            // For cross-platform compat we keep the standard 120s TTL on the wire and
            // just regenerate silently in the background when it lapses.
            let newToken = VouchToken(
                voucherId:          account.userId,
                name:               account.name,
                voucherPublicKey:   account.publicKey,
                voucherTrustAtTime: account.trustLevel,
                nonce:              nonce,
                issuedAt:           issuedAt,
                signature:          sig
            )
            token      = newToken
            qrImage    = buildQR(for: newToken)   // only computed once per token
            secondsLeft = ttl

            // Schedule silent background refresh before the 120s wire TTL lapses.
            if ttl > 110 {
                scheduleAutoRefresh(after: 110)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func scheduleAutoRefresh(after delay: Double) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, secondsLeft > 0 else { return }
            await regenerate()
        }
    }

    // MARK: - QR generation (computed once, cached in qrImage)

    private func buildQR(for token: VouchToken) -> UIImage? {
        guard let json = try? JSONEncoder().encode(token),
              let str  = String(data: json, encoding: .utf8) else { return nil }
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message         = Data(str.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        return Data(bytes).base64EncodedString()
    }
}
