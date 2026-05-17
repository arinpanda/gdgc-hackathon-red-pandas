import Foundation
import Observation

@Observable
final class OrgStore {
    private(set) var orgs: [Organization] = []
    private(set) var memberships: [Membership] = []

    private let orgsKey        = "blackout.organizations"
    private let membershipsKey = "blackout.memberships"

    var orgsById: [String: Organization] {
        Dictionary(uniqueKeysWithValues: orgs.map { ($0.id, $0) })
    }

    init() { load() }

    // MARK: - Org creation

    func foundOrganization(founder: Account, name: String) async throws {
        guard founder.isSuperuser else { throw OrgError.notSuperuser }

        let orgId     = UUID().uuidString
        let createdAt = ISO8601DateFormatter().string(from: Date())

        let payload = CanonicalJSON.encode([
            "createdAt"       : .string(createdAt),
            "founderPublicKey": .string(founder.publicKey),
            "id"              : .string(orgId),
            "name"            : .string(name),
        ])
        let signature = try IdentityKey.sign(userId: founder.userId, data: payload)

        let org = Organization(
            id: orgId, name: name,
            founderPublicKey: founder.publicKey,
            createdAt: createdAt,
            signature: signature
        )
        let membership = Membership(
            orgId: orgId,
            memberId: founder.userId,
            joinedAtDepth: FOUNDER_DEPTH,
            acceptedAt: createdAt,
            inviteChain: nil
        )

        orgs.append(org)
        memberships.append(membership)
        persistOrgs()
        persistMemberships()
    }

    // MARK: - Invite issuance

    func createInvite(
        for membership: Membership,
        issuerUserId: String,
        issuerPublicKey: String,
        depth: Int
    ) async throws -> OrgInvite {
        guard depth >= 1 else { throw OrgError.invalidDepth }
        guard depth < membership.joinedAtDepth else { throw OrgError.depthExceeded }
        guard let org = orgsById[membership.orgId] else { throw OrgError.orgNotFound }

        let inviteId = UUID().uuidString
        let nonce    = randomNonce()
        let issuedAt = ISO8601DateFormatter().string(from: Date())

        let payload = CanonicalJSON.encode([
            "depth"           : .number(Double(depth)),
            "id"              : .string(inviteId),
            "inviterPublicKey": .string(issuerPublicKey),
            "issuedAt"        : .string(issuedAt),
            "nonce"           : .string(nonce),
            "orgId"           : .string(org.id),
            "parentInviteId"  : membership.inviteChain != nil
                                    ? .string(membership.inviteChain!.id)
                                    : .null,
        ])
        let signature = try IdentityKey.sign(userId: issuerUserId, data: payload)

        return OrgInvite(
            id: inviteId, orgId: org.id,
            inviterPublicKey: issuerPublicKey,
            depth: depth, nonce: nonce, issuedAt: issuedAt,
            parent: membership.inviteChain,
            signature: signature,
            org: org
        )
    }

    // MARK: - Invite acceptance

    func acceptInvite(_ invite: OrgInvite, as memberId: String) async throws {
        let result = try await verifyChain(invite)
        guard result.ok, let org = result.org else {
            throw OrgError.chainInvalid(result.error ?? "unknown")
        }
        if invite.inviterPublicKey == memberId {
            throw OrgError.selfInvite
        }
        if memberships.contains(where: { $0.memberId == memberId && $0.orgId == org.id }) {
            throw OrgError.alreadyMember
        }

        let membership = Membership(
            orgId: org.id,
            memberId: memberId,
            joinedAtDepth: invite.depth,
            acceptedAt: ISO8601DateFormatter().string(from: Date()),
            inviteChain: invite
        )
        memberships.append(membership)

        if !orgs.contains(where: { $0.id == org.id }) {
            orgs.append(org)
            persistOrgs()
        }
        persistMemberships()
    }

    // MARK: - Queries

    func memberships(for userId: String) -> [Membership] {
        memberships.filter { $0.memberId == userId }
    }

    func removeMemberships(for userId: String) {
        memberships.removeAll { $0.memberId == userId }
        persistMemberships()
    }

    func wipeAll() {
        orgs = []; memberships = []
        UserDefaults.standard.removeObject(forKey: orgsKey)
        UserDefaults.standard.removeObject(forKey: membershipsKey)
    }

    // MARK: - Chain verification

    struct ChainResult {
        let ok: Bool
        let org: Organization?
        let error: String?
    }

    func verifyChain(_ invite: OrgInvite) async throws -> ChainResult {
        guard let org = invite.org else {
            return ChainResult(ok: false, org: nil, error: "missing org on top-level invite")
        }

        // Verify org signature
        guard (try? IdentityKey.verify(
            publicKeyBase64: org.founderPublicKey,
            data: org.canonicalBytes(),
            signatureBase64: org.signature
        )) == true else {
            return ChainResult(ok: false, org: nil, error: "org signature invalid")
        }

        // Freshness: only the top-level invite must be fresh
        guard let issued = ISO8601DateFormatter().date(from: invite.issuedAt) else {
            return ChainResult(ok: false, org: nil, error: "bad issuedAt")
        }
        let age = Date().timeIntervalSince(issued)
        guard age <= 120 else { return ChainResult(ok: false, org: nil, error: "invite expired") }
        guard age >= -30  else { return ChainResult(ok: false, org: nil, error: "invite future-dated") }

        // Walk chain tip → root, collecting hops
        var chain: [OrgInvite] = []
        var cur: OrgInvite? = invite
        while let node = cur {
            chain.append(node)
            cur = node.parent
        }
        // chain[0] = outermost (tip), chain.last = root (parent == nil)

        let root = chain.last!

        // Root must be issued by the org founder
        guard root.inviterPublicKey == org.founderPublicKey else {
            return ChainResult(ok: false, org: nil, error: "chain root is not the org founder")
        }

        // Verify each hop from root to tip
        for (i, hop) in chain.reversed().enumerated() {
            // Signature
            guard (try? IdentityKey.verify(
                publicKeyBase64: hop.inviterPublicKey,
                data: hop.canonicalBytes(),
                signatureBase64: hop.signature
            )) == true else {
                return ChainResult(ok: false, org: nil, error: "signature invalid at depth \(i)")
            }

            // orgId consistency
            guard hop.orgId == org.id else {
                return ChainResult(ok: false, org: nil, error: "orgId mismatch at hop \(i)")
            }

            // Depth rule: each child depth < parent depth
            if let parent = hop.parent {
                guard hop.depth < parent.depth else {
                    return ChainResult(ok: false, org: nil, error: "depth not decreasing at hop \(i)")
                }
            }

            // parentInviteId binding
            let expectedParentId = hop.parent?.id
            let signedBytes = hop.canonicalBytes()
            // parentInviteId is encoded in canonicalBytes; verification above already checks this.
            _ = (expectedParentId, signedBytes) // binding verified by the signature check above
        }

        return ChainResult(ok: true, org: org, error: nil)
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: orgsKey),
           let decoded = try? JSONDecoder().decode([Organization].self, from: data) {
            orgs = decoded
        }
        if let data = UserDefaults.standard.data(forKey: membershipsKey),
           let decoded = try? JSONDecoder().decode([Membership].self, from: data) {
            memberships = decoded
        }
    }

    private func persistOrgs() {
        if let data = try? JSONEncoder().encode(orgs) {
            UserDefaults.standard.set(data, forKey: orgsKey)
        }
    }

    private func persistMemberships() {
        if let data = try? JSONEncoder().encode(memberships) {
            UserDefaults.standard.set(data, forKey: membershipsKey)
        }
    }

    private func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        return Data(bytes).base64EncodedString()
    }
}

enum OrgError: LocalizedError {
    case notSuperuser, invalidDepth, depthExceeded, orgNotFound
    case chainInvalid(String), selfInvite, alreadyMember

    var errorDescription: String? {
        switch self {
        case .notSuperuser:         return "Only superusers can found organisations"
        case .invalidDepth:         return "Depth must be at least 1"
        case .depthExceeded:        return "Depth must be less than your own join depth"
        case .orgNotFound:          return "Organisation not found"
        case .chainInvalid(let e):  return "Invite chain invalid: \(e)"
        case .selfInvite:           return "You issued this invite — pass it to someone else"
        case .alreadyMember:        return "Already a member of this organisation"
        }
    }
}
