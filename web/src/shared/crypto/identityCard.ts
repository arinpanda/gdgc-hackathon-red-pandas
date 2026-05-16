import type { Account } from "../types/account";
import type { IdentityCard, UnsignedIdentityCard } from "../types/identityCard";
import { CARD_TTL_SECONDS, canonicalIdentityCardBytes } from "../types/identityCard";
import { signWithIdentity, verifySignature } from "./identityKey";

/**
 * Issue a fresh signed identity card for `account`. The nonce + issuedAt
 * timestamp make every issuance unique, so a screenshot of an old card is
 * rejected by the verifier (see CARD_TTL_SECONDS).
 *
 * The private key signing happens via signWithIdentity, which reads the
 * account's stored CryptoKey from IndexedDB on web (Secure Enclave / Keystore
 * on mobile).
 */
export async function createIdentityCard(account: Account): Promise<IdentityCard> {
  const unsigned: UnsignedIdentityCard = {
    userId: account.userId,
    name: account.name,
    publicKey: account.publicKey,
    nonce: randomNonceBase64(),
    issuedAt: new Date().toISOString(),
  };
  const payload = canonicalIdentityCardBytes(unsigned);
  const signature = await signWithIdentity(account.userId, payload);
  return { ...unsigned, signature };
}

export type CardVerifyError =
  | "bad-shape"
  | "bad-signature"
  | "expired"
  | "future-dated";

export interface CardVerifyResult {
  ok: boolean;
  error?: CardVerifyError;
  card?: IdentityCard;
}

/** Allowance for clock skew on the issuer side, in seconds. */
const CLOCK_SKEW_SECONDS = 30;

/**
 * Verify a card: structural sanity, signature against its embedded publicKey,
 * and freshness. Does NOT check anything about whether we know the holder
 * already — that's the caller's concern.
 */
export async function verifyIdentityCard(card: IdentityCard): Promise<CardVerifyResult> {
  if (!isWellFormed(card)) return { ok: false, error: "bad-shape" };

  const issued = Date.parse(card.issuedAt);
  if (Number.isNaN(issued)) return { ok: false, error: "bad-shape" };

  const now = Date.now();
  const ageSeconds = (now - issued) / 1000;
  if (ageSeconds > CARD_TTL_SECONDS) return { ok: false, error: "expired", card };
  if (ageSeconds < -CLOCK_SKEW_SECONDS) return { ok: false, error: "future-dated", card };

  const unsigned: UnsignedIdentityCard = {
    userId: card.userId,
    name: card.name,
    publicKey: card.publicKey,
    nonce: card.nonce,
    issuedAt: card.issuedAt,
  };
  const payload = canonicalIdentityCardBytes(unsigned);
  const sigOk = await verifySignature(card.publicKey, payload, card.signature);
  if (!sigOk) return { ok: false, error: "bad-signature", card };
  return { ok: true, card };
}

function isWellFormed(c: unknown): c is IdentityCard {
  if (!c || typeof c !== "object") return false;
  const o = c as Record<string, unknown>;
  return (
    typeof o.userId === "string" &&
    typeof o.name === "string" &&
    typeof o.publicKey === "string" &&
    typeof o.nonce === "string" &&
    typeof o.issuedAt === "string" &&
    typeof o.signature === "string"
  );
}

function randomNonceBase64(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}
