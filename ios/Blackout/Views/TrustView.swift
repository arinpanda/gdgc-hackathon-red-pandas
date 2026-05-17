import SwiftUI
import CoreImage.CIFilterBuiltins

struct TrustView: View {
    @Environment(VouchStore.self)   private var vouchStore
    @Environment(AccountStore.self) private var accountStore
    let account: Account

    @State private var qrImage:    UIImage?
    @State private var token:      VouchToken?
    @State private var errorMsg:   String?
    @State private var secondsLeft: Double = 120
    @State private var showScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                qrCard
                scanButton
                if let errorMsg {
                    Text(errorMsg)
                        .font(.footnote)
                        .foregroundStyle(Color.appError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .navigationTitle("Trust")
        .navigationBarTitleDisplayMode(.large)
        .task { await regenerate() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
        }
        .sheet(isPresented: $showScanner) {
            ScanCardView(active: account)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Your Trust Code")
                .font(.title2.bold())
                .foregroundStyle(Color.appOnSurface)
            Group {
                if secondsLeft > 0 {
                    Text("Expires in \(Int(secondsLeft))s")
                } else {
                    Text("Expired — tap code to refresh")
                }
            }
            .font(.subheadline)
            .foregroundStyle(secondsLeft < 30 ? Color.appError : Color.appOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var qrCard: some View {
        VStack(spacing: 20) {
            // QR image area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 256, height: 256)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appSurfaceHigh, lineWidth: 2)
                    )

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 224, height: 224)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if errorMsg != nil {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Generation failed")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appOnSurfaceVariant)
                } else {
                    ProgressView()
                }
            }
            .onTapGesture {
                if secondsLeft <= 0 { Task { await regenerate() } }
            }

            // Name + ID
            VStack(spacing: 4) {
                Text(account.name)
                    .font(.headline)
                    .foregroundStyle(Color.appOnSurface)
                Text("ID: \(account.shortUserId())")
                    .font(.subheadline)
                    .foregroundStyle(Color.appOnSurfaceVariant)
            }

            // Trust delta preview
            if let token {
                Text(String(format: "Vouching +%.1f trust", vouchDelta(token.voucherTrustAtTime)))
                    .font(.caption)
                    .foregroundStyle(Color.appOnSurfaceVariant)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.appSecondaryContainer.opacity(0.5))
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
    }

    private var scanButton: some View {
        Button { showScanner = true } label: {
            Text("Scan QR Code")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Token generation

    private func regenerate() async {
        errorMsg = nil
        let nonce    = randomNonce()
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let payload  = CanonicalJSON.encode([
            "issuedAt"           : .string(issuedAt),
            "name"               : .string(account.name),
            "nonce"              : .string(nonce),
            "voucherId"          : .string(account.userId),
            "voucherPublicKey"   : .string(account.publicKey),
            "voucherTrustAtTime" : .number(account.trustLevel),
        ])
        do {
            let sig = try IdentityKey.sign(userId: account.userId, data: payload)
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
            qrImage    = buildQR(for: newToken)
            secondsLeft = 120
            scheduleAutoRefresh(after: 110)
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func scheduleAutoRefresh(after delay: Double) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, secondsLeft > 0 else { return }
            await regenerate()
        }
    }

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
