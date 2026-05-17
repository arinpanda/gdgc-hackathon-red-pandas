import CryptoKit
import Security
import Foundation

enum IdentityKeyError: LocalizedError {
    case keyNotFound
    case invalidPublicKey
    case invalidSignature
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keyNotFound:      return "Identity key not found in Keychain"
        case .invalidPublicKey: return "Invalid public key encoding"
        case .invalidSignature: return "Invalid signature encoding"
        case .keychain(let s):  return "Keychain error \(s)"
        }
    }
}

/// P-256 ECDSA identity key operations.
///
/// Public keys are stored / transmitted as base64(x963Representation) — 65 bytes
/// (0x04 || X || Y), matching WebCrypto's 'raw' export and the web reference.
///
/// Signatures are base64(rawRepresentation) — 64 bytes (r || s), IEEE P1363,
/// matching WebCrypto's ECDSA sign output.
///
/// Private keys are kept in the Keychain. On real devices, Secure Enclave is
/// used when available; the simulator falls back to software keys.
enum IdentityKey {

    // MARK: - Public API

    /// Generate a new identity key for `userId` and return the base64 public key.
    static func create(userId: String) throws -> String {
        let (pubKeyBase64, keyData, isSE) = try generateKey()
        try saveToKeychain(userId: userId, data: keyData, isSecureEnclave: isSE)
        return pubKeyBase64
    }

    /// Sign `data` with `userId`'s stored key. Returns base64 signature (r||s).
    static func sign(userId: String, data: Data) throws -> String {
        let (keyData, isSE) = try loadFromKeychain(userId: userId)
        let sig: Data
        if isSE {
            let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
            sig = try key.signature(for: data).rawRepresentation
        } else {
            let key = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            sig = try key.signature(for: data).rawRepresentation
        }
        return sig.base64EncodedString()
    }

    /// Verify a base64 signature against a base64 public key and raw data.
    static func verify(publicKeyBase64: String, data: Data, signatureBase64: String) throws -> Bool {
        guard let pubKeyData = Data(base64Encoded: publicKeyBase64) else {
            throw IdentityKeyError.invalidPublicKey
        }
        guard let sigData = Data(base64Encoded: signatureBase64) else {
            throw IdentityKeyError.invalidSignature
        }
        let publicKey = try P256.Signing.PublicKey(x963Representation: pubKeyData)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: sigData)
        return publicKey.isValidSignature(signature, for: data)
    }

    /// Remove the stored key for `userId` from the Keychain.
    static func destroy(userId: String) {
        deleteFromKeychain(userId: userId)
    }

    static func exists(userId: String) -> Bool {
        (try? loadFromKeychain(userId: userId)) != nil
    }

    // MARK: - Key generation

    private static func generateKey() throws -> (pubKeyBase64: String, keyData: Data, isSE: Bool) {
        if SecureEnclave.isAvailable {
            let key = try SecureEnclave.P256.Signing.PrivateKey()
            let pub = key.publicKey.x963Representation.base64EncodedString()
            return (pub, key.dataRepresentation, true)
        } else {
            let key = P256.Signing.PrivateKey()
            let pub = key.publicKey.x963Representation.base64EncodedString()
            return (pub, key.rawRepresentation, false)
        }
    }

    // MARK: - Keychain helpers

    // Two items per userId: the key data and a 1-byte flag marking SE vs software.
    private static func keychainTag(_ userId: String) -> String { "blackout.key.\(userId)" }
    private static func keychainFlagTag(_ userId: String) -> String { "blackout.key.se.\(userId)" }

    private static func saveToKeychain(userId: String, data: Data, isSecureEnclave: Bool) throws {
        let tag = keychainTag(userId)
        let flagTag = keychainFlagTag(userId)
        try keychainSet(tag: tag, data: data)
        try keychainSet(tag: flagTag, data: Data([isSecureEnclave ? 1 : 0]))
    }

    private static func loadFromKeychain(userId: String) throws -> (Data, Bool) {
        let data = try keychainGet(tag: keychainTag(userId))
        let flag = (try? keychainGet(tag: keychainFlagTag(userId))).flatMap { $0.first } ?? 0
        return (data, flag == 1)
    }

    private static func deleteFromKeychain(userId: String) {
        keychainDelete(tag: keychainTag(userId))
        keychainDelete(tag: keychainFlagTag(userId))
    }

    private static func keychainSet(tag: String, data: Data) throws {
        let q: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     tag,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemDelete(q as CFDictionary)
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityKeyError.keychain(status) }
    }

    private static func keychainGet(tag: String) throws -> Data {
        let q: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: tag,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw IdentityKeyError.keyNotFound
        }
        return data
    }

    private static func keychainDelete(tag: String) {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: tag]
        SecItemDelete(q as CFDictionary)
    }
}
