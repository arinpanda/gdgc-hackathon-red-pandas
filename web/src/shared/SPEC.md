# Blackout — Shared Spec (Exposure Points)

This folder is the **contract boundary** between the web reference implementation and the future Android & iOS native apps. Anything in `shared/` must be reimplemented identically on every platform so that artifacts produced by one platform are byte-compatible with — and verifiable by — the others.

Anything *outside* `shared/` (e.g. `storage/`, `views/`) is web-specific. Mobile is free to use platform-idiomatic equivalents (Keychain / Secure Enclave / Keystore for keys, native UI for views) as long as it conforms to the contracts defined here.

There is **no server**. Web is 100% client-side. Mobile apps reimplement everything locally; they do not call into the web portal.

---

## 1. Data schemas

All shared types live under `shared/types/`. They are plain JSON when serialized.

### `Account`

Source: `shared/types/account.ts`

```ts
interface Account {
  userId: string;       // RFC 4122 v4 UUID, lowercase, hyphenated. Internal — not user-facing as a handle.
  name: string;         // Display name. Trimmed, non-empty.
  age: number;          // Integer, 13–120.
  trustLevel: number;   // Single score. Starts at 0 (INITIAL_TRUST_LEVEL); see §3 for recomputation.
  profession: string;   // Free-text. Empty string = BASIC user (no profession claimed).
  locale: string;       // Free-text location (e.g. "London, UK"). Non-empty.
  publicKey: string;    // base64 of raw P-256 public-key bytes (65 bytes, uncompressed SEC1).
  createdAt: string;    // ISO 8601 UTC timestamp.
}
```

### `Vouch`

Source: `shared/types/vouch.ts`

A signed attestation from one account (the **voucher**) to another (the **vouchee**) saying "I trust this person."

```ts
interface Vouch {
  id: string;               // RFC 4122 v4 UUID, lowercase, hyphenated.
  voucherId: string;        // userId of the voucher.
  vouchedForId: string;     // userId of the vouchee. MUST NOT equal voucherId.
  voucherPublicKey: string; // base64 raw P-256 pub key of the voucher (denormalized for offline verification).
  createdAt: string;        // ISO 8601 UTC timestamp.
  signature: string;        // base64 IEEE-P1363 ECDSA signature, see §2.
}
```

**Uniqueness:** at most one vouch per (voucherId, vouchedForId) pair. The storage layer rejects duplicates. (Counter-vouches and revocations are a future feature.)

**Canonical signing payload:** `canonicalVouchBytes(unsigned)` returns the UTF-8 bytes of `JSON.stringify(orderedFields)` where `orderedFields` contains every field of `Vouch` *except* `signature`, with keys sorted lexicographically and no whitespace.

Mobile MUST produce byte-identical canonical output for any vouch with the same field values. The order — `createdAt`, `id`, `voucherId`, `voucherPublicKey`, `vouchedForId` — is what `Object.keys(...).sort()` produces in JS; mobile must sort the same way.

### Government ID is a gate, NOT stored

To create an account the user MUST present a government ID (`passport` or `drivers_license`). The web reference collects an ID type and ID number at onboarding, validates they're non-empty, then **discards them** — they never enter the `Account` JSON, never touch IndexedDB.

Mobile MUST follow the same pattern: gate at creation, do not persist.

```ts
type IdType = "passport" | "drivers_license";
```

### Storage layout (reference)

The web reference uses these `localStorage` keys (mobile maps to platform-idiomatic locations; the *shape* is normative, the *location* is not):

| Key                      | Shape                              | Notes                                              |
|--------------------------|------------------------------------|----------------------------------------------------|
| `blackout.accounts`      | `Account[]`                        | All accounts on this device.                       |
| `blackout.activeUserId`  | `string` (userId) or absent        | Which account is currently "you" for actions.      |
| `blackout.vouches`       | `Vouch[]`                          | All vouches known to this device.                  |

Identity keys live in IndexedDB; see §2.

---

## 2. Crypto / signing formats

All shared crypto lives under `shared/crypto/`.

### Identity key (per account)

Each `Account` has its own P-256 ECDSA keypair, used to:

- **Verify users across devices** — the public key (`Account.publicKey`) identifies you cryptographically.
- **Sign vouches** — proves the voucher really did vouch.
- **Respond to trust handshakes** — challenge-response between two identity keys (future).
- **Protect privacy and safety** — only signed artifacts are trusted; the private key never leaves the secure boundary.

#### Parameters

- **Curve:** NIST P-256 (`secp256r1` / `prime256v1`).
- **Algorithm:** ECDSA with SHA-256.
- **Signature encoding:** Raw IEEE P1363 (64 bytes for P-256: `r || s`), then base64.
- **Public key encoding:** Raw uncompressed SEC1 (65 bytes: `0x04 || X (32B) || Y (32B)`), then base64.
- **Private key storage:** Non-extractable from the platform's secure key boundary after creation. Never exported, transmitted, or backed up.
  - **Web:** generated extractable, immediately re-imported as non-extractable, stored as a `CryptoKey` in IndexedDB. DB `blackout`, object store `keys`, **record key = the account's `userId`**.
  - **iOS:** `SecureEnclave.P256.Signing.PrivateKey()` (CryptoKit). Key lives only inside the Secure Enclave.
  - **Android:** `KeyPairGenerator.getInstance("EC", "AndroidKeyStore")` with `ECGenParameterSpec("secp256r1")`. Key lives only inside the AndroidKeyStore.

### Required operations

| Operation               | Web reference                                                   |
|-------------------------|-----------------------------------------------------------------|
| Create + persist        | `createIdentity(userId)` → `{ publicKeyBase64 }`                |
| Check presence          | `hasIdentity(userId)` → boolean                                 |
| Sign payload            | `signWithIdentity(userId, bytes)` → base64 P1363 signature      |
| Verify signature        | `verifySignature(pubKeyBase64, bytes, sigBase64)` → boolean     |
| Destroy (delete account)| `destroyIdentity(userId)` → void                                |

`createVouch()` in `storage/vouchStore.ts` is the reference example: it builds an `UnsignedVouch`, signs `canonicalVouchBytes(...)`, then **self-verifies** before persisting (catches encoding bugs early).

### Fingerprint

`fingerprint(account)` is a **display placeholder** (first 4 + last 4 hex chars of the raw public key). NOT cryptographically meaningful. Will be upgraded to `SHA-256(publicKey)[:N]` when used in verification flows.

---

## 3. Trust math

Source: `shared/trust/computeTrust.ts`

`computeTrust(userIds, vouches)` returns a `Map<userId, trustLevel>` derived from the full vouch graph.

```
trust(u) = sum over distinct vouchers v in vouchesFor(u) of (1 + W * trust(v))
where W = TRUST_VOUCHER_WEIGHT = 0.5
```

Computed by fixed-point iteration starting from `0` for everyone, repeated `TRUST_ITERATIONS = 5` times. Mobile MUST use the same constants and iteration count to reproduce identical scores from the same vouch graph.

**Properties:**
- An isolated account with no vouches: `0`.
- One vouch from a fresh (trust 0) account: `1.0`.
- Two vouches from fresh accounts: `2.0` (additive in `1 +` term).
- A vouch from a high-trust voucher counts more (the `0.5 * trust(v)` boost).
- **Cycles (A↔B):** produce stable but inflated values; known v0 limitation. Per-domain trust and explicit cycle damping are future work.
- **Self-vouches:** rejected at storage; defensively ignored in computation.
- **Duplicate vouches** (same voucher → same vouchee): rejected at storage; defensively de-duped via the distinct-vouchers set.

### `trustLevel` on `Account`

`Account.trustLevel` is a **cached** copy of the value `computeTrust` would produce for that user. v0 doesn't write back to `Account.trustLevel` (the UI reads live from `computeTrust` each render); when persistence of trust is needed (e.g. for sync), the single-writer is the trust computation pass. UI MUST NEVER write `trustLevel` directly.

---

## 4. UX flow reference

The web app's views (`web/src/views/`) are the reference UX. Mobile MUST match the user-facing flow even if the visual design differs.

### Simulator mode (hackathon scope)

The current web UX is a **multi-account simulator**: one device holds several accounts, you switch between them, vouch from one to another, and watch trust recompute. Mobile will eventually be single-account-per-device with peer sync, but the simulator's flows (creating accounts, vouching, viewing vouches received/given, viewing trust level) are the reference for the corresponding mobile screens.

### Account creation flow

1. **First-launch detection:** If no accounts exist → onboarding.
2. **Onboarding screen:** Collect (all required unless noted):
   - **Stored on Account:** name, age (13–120), profession (optional), location
   - **Gate only — discarded after validation:** ID type, ID number
3. **On submit:** generate UUID v4 `userId` → generate identity keypair (§2) → construct `Account` (`trustLevel: 0`) → persist → set as active if no active account exists → discard ID fields → transition to browse view.
4. **Browse view:** sidebar lists all accounts (with live trust); main panel shows the selected account's profile.

### Vouching flow

1. Pick an account to **act as** (sidebar "act as" link sets `activeUserId`).
2. Select a different account in the sidebar.
3. On its profile, click **"Vouch as [active]"**.
4. The app builds an `UnsignedVouch`, computes `canonicalVouchBytes(...)`, signs with the active account's private key, self-verifies, and persists.
5. All visible `trustLevel` values recompute immediately.

### Account deletion

Deleting an account MUST cascade: remove the account from `blackout.accounts`, delete its keypair via `destroyIdentity(userId)`, and remove every vouch where `voucherId === userId` OR `vouchedForId === userId`. Failing to cascade leaves orphan vouches that point at missing keys.

### Future flows (not yet implemented; placeholders)

- ID verification (camera + OCR for driver's licence; passport NFC chip read)
- Counter-vouches (negative signals; additive only — no deletion)
- Per-domain trust (medical / legal / etc.)
- Diversity-weighted trust (vouches from disconnected clusters count more)
- Trust path display ("trusted by Maria → who is trusted by Dr Chen → who vouches for this surgeon")
- Peer trust handshake (signed challenge-response between two identity keys)
- Peer sync over local transport (BLE / Wi-Fi Direct / MultipeerConnectivity)

---

## Versioning

This is v0 (pre-stable). Schemas, crypto formats, and trust math may change without notice until v1. When we hit v1, every shared type gets a `version` field and changes follow additive-compatible rules.
