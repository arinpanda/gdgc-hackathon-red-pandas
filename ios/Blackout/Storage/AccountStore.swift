import Foundation
import Observation

@Observable
final class AccountStore {
    private(set) var accounts: [Account] = []
    private(set) var activeUserId: String?

    private let accountsKey   = "blackout.accounts"
    private let activeUserKey = "blackout.activeUserId"

    var activeAccount: Account? { accounts.first { $0.userId == activeUserId } }
    var accountsById: [String: Account] { Dictionary(uniqueKeysWithValues: accounts.map { ($0.userId, $0) }) }

    init() { load() }

    // MARK: - Account creation

    func createAccount(
        name: String,
        age: Int,
        profession: String,
        locale: String,
        isSuperuser: Bool,
        profilePhotoBase64: String? = nil
    ) async throws -> Account {
        let userId    = UUID().uuidString
        let publicKey = try IdentityKey.create(userId: userId)
        let account   = Account(
            userId:             userId,
            name:               name,
            age:                age,
            trustLevel:         isSuperuser ? Account.maxTrustLevel : Account.initialTrustLevel,
            profession:         profession,
            locale:             locale,
            publicKey:          publicKey,
            createdAt:          ISO8601DateFormatter().string(from: Date()),
            isSuperuser:        isSuperuser,
            profilePhotoBase64: profilePhotoBase64
        )
        saveAccount(account)
        if activeUserId == nil { setActive(userId) }
        return account
    }

    // MARK: - Mutations

    func saveAccount(_ account: Account) {
        if let idx = accounts.firstIndex(where: { $0.userId == account.userId }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        persist()
    }

    func deleteAccount(_ userId: String) {
        accounts.removeAll { $0.userId == userId }
        IdentityKey.destroy(userId: userId)
        if activeUserId == userId {
            let next = accounts.first?.userId
            activeUserId = next
            UserDefaults.standard.set(next, forKey: activeUserKey)
        }
        persist()
    }

    func setActive(_ userId: String) {
        activeUserId = userId
        UserDefaults.standard.set(userId, forKey: activeUserKey)
    }

    func applyTrustDelta(_ delta: Double, to userId: String) {
        guard let idx = accounts.firstIndex(where: { $0.userId == userId }) else { return }
        let acc = accounts[idx]
        accounts[idx] = Account(
            userId:             acc.userId,
            name:               acc.name,
            age:                acc.age,
            trustLevel:         acc.trustLevel + delta,
            profession:         acc.profession,
            locale:             acc.locale,
            publicKey:          acc.publicKey,
            createdAt:          acc.createdAt,
            isSuperuser:        acc.isSuperuser,
            profilePhotoBase64: acc.profilePhotoBase64
        )
        persist()
    }

    func wipeAll() {
        for acc in accounts { IdentityKey.destroy(userId: acc.userId) }
        accounts = []
        activeUserId = nil
        UserDefaults.standard.removeObject(forKey: accountsKey)
        UserDefaults.standard.removeObject(forKey: activeUserKey)
    }

    // MARK: - Persistence

    private func load() {
        if let data    = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }
        activeUserId = UserDefaults.standard.string(forKey: activeUserKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }
}
