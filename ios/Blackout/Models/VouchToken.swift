import Foundation

/// Open vouch token — signed by the holder, claimed by whoever scans it.
/// vouchedForId is intentionally absent from the signed payload; the scanner
/// self-claims it. TTL + physical presence are the abuse mitigations.
struct VouchToken: Codable {
    let voucherId: String
    let name: String
    let voucherPublicKey: String
    let voucherTrustAtTime: Double
    let nonce: String
    let issuedAt: String        // ISO 8601 UTC
    let signature: String       // base64 IEEE-P1363 ECDSA

    static let ttlSeconds: Double      = 120
    static let clockSkewSeconds: Double = 30

    /// Canonical byte payload that was signed. Keys sorted lexicographically,
    /// no whitespace — must match the web's canonicalVouchTokenBytes() exactly.
    func canonicalBytes() -> Data {
        CanonicalJSON.encode([
            "issuedAt"           : .string(issuedAt),
            "name"               : .string(name),
            "nonce"              : .string(nonce),
            "voucherId"          : .string(voucherId),
            "voucherPublicKey"   : .string(voucherPublicKey),
            "voucherTrustAtTime" : .number(voucherTrustAtTime),
        ])
    }

    var isExpired: Bool {
        guard let issued = ISO8601DateFormatter().date(from: issuedAt) else { return true }
        return Date().timeIntervalSince(issued) > VouchToken.ttlSeconds
    }

    var secondsRemaining: Double {
        guard let issued = ISO8601DateFormatter().date(from: issuedAt) else { return 0 }
        return max(0, VouchToken.ttlSeconds - Date().timeIntervalSince(issued))
    }
}

/// Trust delta formula — must match web's vouchDelta().
func vouchDelta(_ voucherTrustAtTime: Double) -> Double {
    1.0 + 0.5 * voucherTrustAtTime
}
