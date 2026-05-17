import Foundation
import Observation

@Observable
final class VouchStore {
    private(set) var vouches: [Vouch] = []
    private let key = "blackout.vouches"

    init() { load() }

    func vouchesReceived(by userId: String) -> [Vouch] {
        vouches.filter { $0.vouchedForId == userId }
    }

    func vouchesGiven(by userId: String) -> [Vouch] {
        vouches.filter { $0.voucherId == userId }
    }

    // MARK: - Token acceptance

    /// Verify a VouchToken and, if valid, record the vouch and apply the trust
    /// delta to `active`'s account via `accountStore`.
    func receiveToken(_ token: VouchToken, as active: Account, accountStore: AccountStore) async throws {
        guard token.voucherId != active.userId else {
            throw VouchError.selfVouch
        }

        // Freshness
        guard let issued = ISO8601DateFormatter().date(from: token.issuedAt) else {
            throw VouchError.badShape
        }
        let age = Date().timeIntervalSince(issued)
        guard age <= VouchToken.ttlSeconds else { throw VouchError.expired }
        guard age >= -VouchToken.clockSkewSeconds else { throw VouchError.futureDated }

        // Signature
        let payload = token.canonicalBytes()
        guard (try? IdentityKey.verify(
            publicKeyBase64: token.voucherPublicKey,
            data: payload,
            signatureBase64: token.signature
        )) == true else {
            throw VouchError.badSignature
        }

        // Duplicate check
        if vouches.contains(where: {
            $0.voucherId == token.voucherId && $0.vouchedForId == active.userId
        }) {
            throw VouchError.duplicate
        }

        let vouch = Vouch(
            id:                  UUID().uuidString,
            voucherId:           token.voucherId,
            vouchedForId:        active.userId,
            voucherPublicKey:    token.voucherPublicKey,
            voucherTrustAtTime:  token.voucherTrustAtTime,
            createdAt:           ISO8601DateFormatter().string(from: Date()),
            signature:           token.signature
        )
        vouches.append(vouch)
        persist()

        accountStore.applyTrustDelta(vouchDelta(token.voucherTrustAtTime), to: active.userId)
    }

    func removeVouches(involving userId: String) {
        vouches.removeAll { $0.voucherId == userId || $0.vouchedForId == userId }
        persist()
    }

    func wipeAll() {
        vouches = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Vouch].self, from: data) {
            vouches = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(vouches) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum VouchError: LocalizedError {
    case selfVouch, badShape, expired, futureDated, badSignature, duplicate

    var errorDescription: String? {
        switch self {
        case .selfVouch:     return "You cannot scan your own card"
        case .badShape:      return "Token is malformed"
        case .expired:       return "Token has expired (120s TTL)"
        case .futureDated:   return "Token timestamp is in the future"
        case .badSignature:  return "Signature verification failed"
        case .duplicate:     return "You already received a vouch from this account"
        }
    }
}
