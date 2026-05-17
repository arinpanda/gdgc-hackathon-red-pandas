import Foundation

struct Vouch: Codable, Identifiable {
    let id: String
    let voucherId: String
    let vouchedForId: String
    let voucherPublicKey: String
    let voucherTrustAtTime: Double
    let createdAt: String       // ISO 8601 UTC
    /// The VouchToken's signature — covers all token fields except vouchedForId.
    let signature: String
}
