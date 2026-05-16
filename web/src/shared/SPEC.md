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
  id: string;                  // RFC 4122 v4 UUID, lowercase, hyphenated.
  voucherId: string;           // userId of the voucher.
  vouchedForId: string;        // userId of the vouchee. MUST NOT equal voucherId.
  voucherPublicKey: string;    // base64 raw P-256 pub key of the voucher (denormalized for offline verification).
  voucherTrustAtTime: number;  // Snapshot of voucher.trustLevel at vouch time. Signed.
  createdAt: string;           // ISO 8601 UTC timestamp.
  signature: string;           // base64 IEEE-P1363 ECDSA signature, see §2.
}
```

**Uniqueness:** at most one vouch per (voucherId, vouchedForId) pair. The storage layer rejects duplicates. (Counter-vouches and revocations are a future feature.)

**Why `voucherTrustAtTime` is signed:** the trust delta applied to the vouchee is derived from this snapshot (see §3). Because the voucher signs over it, anyone receiving the vouch later — including a peer that sees it via sync — can independently reproduce the exact trust delta the voucher attested to, without needing to know the voucher's *current* trust.

**Canonical signing payload:** `canonicalVouchBytes(unsigned)` returns the UTF-8 bytes of `JSON.stringify(orderedFields)` where `orderedFields` contains every field of `Vouch` *except* `signature`, with keys sorted lexicographically and no whitespace.

Mobile MUST produce byte-identical canonical output for any vouch with the same field values. The order — `createdAt`, `id`, `voucherId`, `voucherPublicKey`, `voucherTrustAtTime`, `vouchedForId` — is what `Object.keys(...).sort()` produces in JS; mobile must sort the same way.

Numeric fields (`voucherTrustAtTime`) are serialized via JS `JSON.stringify`'s default number formatting. Mobile JSON encoders must produce the same canonical numeric form (e.g. `2` not `2.0`, `2.5` not `2.50`) or signatures will not verify cross-platform.

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

## 3. Trust math (decentralized, incremental)

Source: `shared/trust/vouchDelta.ts`

Trust is **stored on each `Account`** and updated **only at vouch creation**. There is no global graph traversal, no fixed-point iteration, no cross-account dependency at compute time. This is what makes the math compatible with the decentralized vision: when account A vouches for account B in person, only A's and B's devices need to be present, and only B's stored value changes.

### The math

```
delta = 1 + W * voucherTrustAtTime,   where W = TRUST_VOUCHER_WEIGHT = 0.5
B.trustLevel := B.trustLevel + delta
```

That's all. `voucherTrustAtTime` is the voucher's trust at the moment of vouching, snapshotted into the `Vouch` record and signed. No re-derivation from the live graph is ever needed or permitted.

### Properties

- **Locality:** a vouch event mutates *only* the vouchee's stored `trustLevel`. The voucher's trust is unchanged. Nobody else's trust is touched. A peer-to-peer vouch between two devices requires no third-party recomputation.
- **Replay-safe:** the signed `voucherTrustAtTime` lets any device that later receives the vouch (e.g. via mobile peer sync) apply the exact same delta. The same vouch never produces different deltas on different devices.
- **Additive only:** trust can only grow from vouches. Counter-vouches (negative deltas) are a future feature.
- **History matters, not snapshots:** if the voucher's trust grows *after* they vouched, the past vouch's delta does not retroactively grow. This is intentional — past attestations are immutable.
- **Cycles are harmless:** A vouches for B (B += delta_A), later B vouches for A (A += delta_B). Both deltas were computed from snapshots taken at different points in time; nothing infinite-loops.
- **Self-vouches:** rejected at the storage layer.
- **Duplicate vouches** (same voucher → same vouchee): rejected at the storage layer.

### What's explicitly forbidden

- **No global recomputation.** Code MUST NOT iterate over the full vouch set to derive trust levels for everyone. The previous fixed-point `computeTrust` function has been deleted; do not reintroduce it. Mobile implementations MUST follow the same rule.
- **No retroactive deltas.** When a voucher's trust changes, vouches they previously gave do not update.
- **No central writer.** Any code path that writes `Account.trustLevel` must originate from a vouch event (or a future counter-vouch event). UI MUST NEVER write `trustLevel`.

### `trustLevel` on `Account`

`Account.trustLevel` is the **authoritative stored value**. It starts at `0` (`INITIAL_TRUST_LEVEL`). The single writer is `createVouch` in `storage/vouchStore.ts` (and any future counter-vouch creator). All readers — UI, sync, anything — read this stored value directly.

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
4. The app reads the voucher's current `trustLevel`, builds an `UnsignedVouch` with that value as `voucherTrustAtTime`, computes `canonicalVouchBytes(...)`, signs with the active account's private key, self-verifies, persists the vouch, and increments **only the vouchee's** stored `trustLevel` by `vouchDelta(voucherTrustAtTime)`.
5. The vouchee's displayed `trustLevel` updates. No other account's value changes.

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
