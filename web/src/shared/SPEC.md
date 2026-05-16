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
  trustLevel: number;   // 0 (INITIAL_TRUST_LEVEL) for normals, MAX_TRUST_LEVEL (1000) for superusers.
  profession: string;   // Free-text. Empty string = BASIC user (no profession claimed).
  locale: string;       // Free-text location (e.g. "London, UK"). Non-empty.
  publicKey: string;    // base64 of raw P-256 public-key bytes (65 bytes, uncompressed SEC1).
  createdAt: string;    // ISO 8601 UTC timestamp.
  isSuperuser: boolean; // Set once at creation; immutable. Superusers can found organizations.
}
```

### Superusers

A `Superuser` is a regular `Account` with `isSuperuser: true` and starting trust set to `MAX_TRUST_LEVEL`. In the simulator anyone can self-declare superuser at onboarding; in production this would obviously need stronger gating. Beyond the starting trust level, the only operational capability superusers have is the right to **found organizations** (§N below). Mobile MUST honor the `isSuperuser` flag identically: enforce founder-only `createOrganization`, start trust at `MAX_TRUST_LEVEL`.

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

### `IdentityCard` (the QR handshake payload)

Source: `shared/types/identityCard.ts`, `shared/crypto/identityCard.ts`

A short-lived signed payload the holder hands to another party in person. **On mobile this is encoded into a QR code** that the holder shows on screen and the other party scans with their camera. The web reference exchanges it as JSON text (camera UX is mobile-only).

```ts
interface IdentityCard {
  userId: string;     // Holder's userId.
  name: string;       // Holder's display name (so the scanner can show it without lookup).
  publicKey: string;  // Holder's base64 raw P-256 public key.
  nonce: string;      // Fresh base64 random (16 bytes) generated per issuance.
  issuedAt: string;   // ISO 8601 UTC timestamp of issuance.
  signature: string;  // base64 IEEE-P1363 ECDSA over canonicalize(everything-except-signature).
}
```

**Freshness:** the verifier rejects cards older than `CARD_TTL_SECONDS = 120`. A `CLOCK_SKEW_SECONDS = 30` allowance lets slightly future-dated cards through (issuer's clock might be a few seconds ahead). A screenshot of an old card is therefore useless after two minutes.

**Why nonce + issuedAt?** This is a one-way handshake (no challenge from the scanner). The nonce makes every issuance unique; the timestamp bounds replay; together they prove the holder was actively producing cards in the recent past.

**Canonical signing payload:** `canonicalIdentityCardBytes(unsigned)` — sorted keys, no whitespace, UTF-8. Sort order: `issuedAt`, `name`, `nonce`, `publicKey`, `userId`.

**The handshake → vouch flow:** when account A scans account B's card while acting as A, the storage layer's `vouchFromScannedCard(active=A, card)` verifies the card and then calls `createVouch` with the right ids. So scanning a card *is* vouching — the QR handshake replaces the need for a separate "select target → click vouch" step.

### `Organization`

Source: `shared/types/organization.ts`, `shared/crypto/organization.ts`

A named entity founded by a superuser. Membership is gated by signed invites (next section).

```ts
interface Organization {
  id: string;               // UUID v4.
  name: string;             // Trimmed, non-empty.
  founderId: string;        // userId of the founding superuser.
  founderPublicKey: string; // Denormalized so receivers can verify the signature offline.
  createdAt: string;        // ISO 8601 UTC.
  signature: string;        // ECDSA over canonicalize(everything-except-signature) by founder.
}
```

`createOrganization(founder, name)` refuses if `founder.isSuperuser !== true`. Mobile MUST enforce the same.

Storage: `blackout.organizations` (`Organization[]`). Mobile maps to its platform store.

### `OrgInvite` (signed handshake payload with chain)

Source: `shared/types/orgInvite.ts`, `shared/crypto/orgInvite.ts`

A signed authorization to join an organization, carrying the full chain of prior invites back to the founder. On mobile, encoded as a QR; on web, exchanged as JSON.

```ts
interface OrgInvite {
  id: string;
  orgId: string;            // Must match the outermost org.id throughout the chain.
  inviterPublicKey: string;
  depth: number;            // >= 1. See depth rule below.
  nonce: string;            // Fresh per issuance.
  issuedAt: string;
  parent: OrgInvite | null; // Recursive chain. null only at the root (founder).
  signature: string;        // ECDSA by inviterPublicKey over canonicalize(unsignedFields).
  org?: Organization;       // PRESENT ONLY on the outermost (top-level) invite; absent in chain elements.
}

// What gets signed (parent is bound by id only — its full body has its own signature):
interface UnsignedOrgInvite {
  id; orgId; inviterPublicKey; depth; nonce; issuedAt;
  parentInviteId: string | null;
}
```

**Depth rule.** A recipient of a depth-N invite may re-issue invites at depths `1 .. N-1`. depth=1 is a leaf: recipient joins but cannot invite further.

**Founder issuance.** When the founder issues their first invite, `parent` is `null` and the depth is unbounded (founder has effective `joinedAtDepth = Number.MAX_SAFE_INTEGER`, exposed as the `FOUNDER_DEPTH` sentinel in the `Membership` record).

**Chain verification (`verifyOrgInviteChain`).** All of:
1. Outer invite carries `org`; org signature verifies against `founderPublicKey`.
2. Top-level invite is within `ORG_INVITE_TTL_SECONDS` (= 120s). Chain elements are historical — no freshness check on them.
3. Every invite in the chain has `depth >= 1` and `orgId === org.id`.
4. Every invite's signature verifies against its own `inviterPublicKey`.
5. For each non-root invite: `depth < parent.depth`.
6. Root invite (where `parent === null`) has `inviterPublicKey === org.founderPublicKey`.

Failure surfaces a specific error: `bad-shape | missing-org | org-id-mismatch | org-signature-invalid | expired | future-dated | bad-signature | depth-rule-violated | root-not-founder | depth-zero-or-negative`.

**Known limitation (v0).** The chain proves the inviter's *cryptographic* authority, but not exclusive possession of the parent invite. Anyone who obtains a parent invite QR within its freshness window can issue children from it. In the in-person QR flow this is mitigated by the holder showing the QR briefly to one specific scanner; for stronger replay-resistance a future revision could bind each invite to the invitee's publicKey via a two-message handshake.

### `Membership` (local-only)

Source: `shared/types/orgInvite.ts`

```ts
interface Membership {
  orgId: string;
  memberId: string;
  joinedAtDepth: number;          // Invite depth at accept time; FOUNDER_DEPTH for founders.
  acceptedAt: string;
  inviteChain: OrgInvite | null;  // The invite that granted membership (chain preserved). null for founders.
}
```

Storage: `blackout.memberships` (`Membership[]`). This record is **never transmitted** — it is the device's local record of org affiliation. When the member re-issues invites, the stored `inviteChain` becomes the new invite's `parent`, growing the chain by one.

Mobile MUST persist the full `inviteChain` on accept, not just the surface invite — otherwise the member can't prove the chain when re-inviting.

### Storage layout (extended)

| Key                       | Shape           |
|---------------------------|-----------------|
| `blackout.accounts`       | `Account[]`     |
| `blackout.activeUserId`   | `string` or absent |
| `blackout.vouches`        | `Vouch[]`       |
| `blackout.organizations`  | `Organization[]` |
| `blackout.memberships`    | `Membership[]`  |

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

### Vouching flow (QR handshake)

There is no "pick a target then click vouch" UI. Vouching happens through the QR handshake; scanning a card *is* vouching.

1. **Pick an account to act as** in the sidebar ("act as" link sets `activeUserId`).
2. **Holder side:** that account opens "Show my card". The app generates a fresh `IdentityCard` (random nonce, current timestamp, signed with the holder's private key). On mobile this is rendered as a QR code; on web it's the JSON. Cards expire after `CARD_TTL_SECONDS`.
3. **Scanner side:** another account, also acting as itself, opens "Scan card". On mobile the camera decodes a QR; on web the JSON is pasted.
4. **Verification:** `verifyIdentityCard(card)` checks shape, signature against the embedded `publicKey`, and freshness.
5. **Vouch:** if the card verifies, `vouchFromScannedCard(active, card)` builds an `UnsignedVouch` with the active account's current `trustLevel` as `voucherTrustAtTime`, signs it, self-verifies, persists, and increments **only the vouchee's** stored `trustLevel` by `vouchDelta(voucherTrustAtTime)`.
6. The vouchee's displayed `trustLevel` updates. No other account's value changes.

#### Web vs mobile: where camera/QR live

- The web reference implements the **payload format** (`IdentityCard`), the **issuer logic** (`createIdentityCard`), and the **verifier logic** (`verifyIdentityCard`, `vouchFromScannedCard`). These are platform-portable contracts mobile must reimplement identically.
- The web does **not** render QR pixels and does **not** scan with a camera. It exchanges the signed JSON via copy/paste so the protocol is testable end-to-end without a camera.
- Mobile (iOS/Android) wraps the same payload in a QR (e.g. via `CIFilter.qrCodeGenerator()` on iOS, `BarcodeEncoder` on Android) and uses the platform camera + barcode detection on the scanner side. The QR is purely transport — the JSON inside is what's signed and verified.

#### Note: simulator vs real peer-to-peer

The web simulator has all accounts on one device, so when A scans B's card the storage layer can immediately bump B's `trustLevel`. On real mobile, A's vouch travels to B's device via peer sync (BLE etc.), and B's device applies the delta when the vouch arrives. Either way, the **delta is computed from the signed `voucherTrustAtTime` snapshot**, so the math is identical regardless of who applies it where.

### Account deletion

Deleting an account MUST cascade: remove the account from `blackout.accounts`, delete its keypair via `destroyIdentity(userId)`, and remove every vouch where `voucherId === userId` OR `vouchedForId === userId`. Failing to cascade leaves orphan vouches that point at missing keys.

### Organization flows (QR handshake, chain-verified)

1. **Found.** A superuser opens "Create org", names it, and submits. `foundOrganization` builds a signed `Organization` and a founder `Membership` (joinedAtDepth = `FOUNDER_DEPTH`).
2. **Show invite.** A member opens "Show invite", picks an org they belong to and a depth in `1 .. min(10, joinedAtDepth - 1)` (10 is a UI cap, not a protocol cap). The app generates an `OrgInvite` with the member's stored `inviteChain` as its `parent` (null for founders), signed with the member's identity key. Each "Show" regenerates a fresh nonce + timestamp.
3. **Scan invite.** Another account opens "Scan invite" while acting as themselves, pastes the invite JSON. `verifyOrgInviteChain` walks every level. On success, a `Membership` is created locally with `joinedAtDepth = invite.depth` and the full invite chain stored as `inviteChain`.
4. **Cascade re-invite.** The new member can now open "Show invite" and issue invites at any depth `1 .. joinedAtDepth - 1`. Their issued invites carry their own `inviteChain` as parent, growing the chain by one each hop.

### Future flows (not yet implemented; placeholders)

- ID verification (camera + OCR for driver's licence; passport NFC chip read)
- Counter-vouches (negative signals; additive only — no deletion)
- Per-domain trust (medical / legal / etc.)
- Diversity-weighted trust (vouches from disconnected clusters count more)
- Trust path display ("trusted by Maria → who is trusted by Dr Chen → who vouches for this surgeon")
- Peer trust handshake (signed challenge-response between two identity keys)
- Peer sync over local transport (BLE / Wi-Fi Direct / MultipeerConnectivity)
- Invite-to-payee binding (two-message handshake) to close the v0 invite replay window

---

## Versioning

This is v0 (pre-stable). Schemas, crypto formats, and trust math may change without notice until v1. When we hit v1, every shared type gets a `version` field and changes follow additive-compatible rules.
