import Foundation

/// Recursive invite chain. Uses a class so Swift can represent the self-referencing
/// parent link; Codable handles the recursion automatically.
final class OrgInvite: Codable, Identifiable {
    let id: String
    let orgId: String
    let inviterPublicKey: String
    let depth: Int
    let nonce: String
    let issuedAt: String        // ISO 8601 UTC
    let parent: OrgInvite?      // nil when inviter is the org founder
    let signature: String       // signs UnsignedOrgInvite (parentInviteId not full parent)
    let org: Organization?      // only present on the outermost (top-level) invite

    init(id: String, orgId: String, inviterPublicKey: String, depth: Int,
         nonce: String, issuedAt: String, parent: OrgInvite?,
         signature: String, org: Organization?) {
        self.id = id; self.orgId = orgId; self.inviterPublicKey = inviterPublicKey
        self.depth = depth; self.nonce = nonce; self.issuedAt = issuedAt
        self.parent = parent; self.signature = signature; self.org = org
    }

    /// Signed payload — binds to parent.id to prevent chain reorganisation.
    func canonicalBytes() -> Data {
        CanonicalJSON.encode([
            "depth"           : .number(Double(depth)),
            "id"              : .string(id),
            "inviterPublicKey": .string(inviterPublicKey),
            "issuedAt"        : .string(issuedAt),
            "nonce"           : .string(nonce),
            "orgId"           : .string(orgId),
            "parentInviteId"  : parent != nil ? .string(parent!.id) : .null,
        ])
    }
}

/// FOUNDER_DEPTH matches JS Number.MAX_SAFE_INTEGER so serialised values are
/// cross-platform identical.
let FOUNDER_DEPTH = 9007199254740991

struct Membership: Codable, Hashable, Equatable {
    static func == (lhs: Membership, rhs: Membership) -> Bool { lhs.orgId == rhs.orgId && lhs.memberId == rhs.memberId }
    func hash(into hasher: inout Hasher) { hasher.combine(orgId); hasher.combine(memberId) }
    let orgId: String
    let memberId: String
    /// FOUNDER_DEPTH for founders; otherwise the depth of the accepted invite.
    let joinedAtDepth: Int
    let acceptedAt: String      // ISO 8601 UTC
    /// Full invite chain. Nil only for founders.
    let inviteChain: OrgInvite?

    var isFounder: Bool { joinedAtDepth == FOUNDER_DEPTH }

    var canInvite: Bool {
        joinedAtDepth == FOUNDER_DEPTH || joinedAtDepth > 1
    }

    var maxIssuableDepth: Int {
        joinedAtDepth == FOUNDER_DEPTH ? 10 : joinedAtDepth - 1
    }
}
