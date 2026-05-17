import Foundation

struct Organization: Codable, Identifiable {
    let id: String
    let name: String
    let founderPublicKey: String
    let createdAt: String       // ISO 8601 UTC
    let signature: String       // signs: createdAt, founderPublicKey, id, name

    func canonicalBytes() -> Data {
        CanonicalJSON.encode([
            "createdAt"       : .string(createdAt),
            "founderPublicKey": .string(founderPublicKey),
            "id"              : .string(id),
            "name"            : .string(name),
        ])
    }
}
