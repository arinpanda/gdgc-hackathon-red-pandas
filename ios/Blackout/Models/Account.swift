import Foundation
import UIKit

struct Account: Codable, Identifiable, Equatable {
    var id: String { userId }

    let userId: String
    let name: String
    let age: Int
    var trustLevel: Double
    let profession: String
    let locale: String
    /// Base64 of the uncompressed SEC1 P-256 public key (65 bytes: 0x04 || X || Y).
    let publicKey: String
    let createdAt: String           // ISO 8601 UTC
    let isSuperuser: Bool
    /// Base64-encoded JPEG of the user's profile photo, resized to ≤400 px.
    let profilePhotoBase64: String?

    static let initialTrustLevel: Double = 0
    static let maxTrustLevel: Double    = 1000

    func fingerprint() -> String {
        guard let data = Data(base64Encoded: publicKey) else { return "???" }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        return "\(hex.prefix(4))…\(hex.suffix(4))"
    }

    func shortUserId() -> String {
        String(userId.prefix(8))
    }

    func profileUIImage() -> UIImage? {
        guard let b64 = profilePhotoBase64,
              let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }
}
