import type { Account } from "../types/account";
import type { VouchToken, UnsignedVouchToken } from "../types/identityCard";
import { CARD_TTL_SECONDS, canonicalVouchTokenBytes } from "../types/identityCard";
import { signWithIdentity, verifySignature } from "./identityKey";

/**
 * Issue a fresh signed vouch token for `account`. The nonce + issuedAt make
 * every issuance unique, so a replayed token is rejected (see CARD_TTL_SECONDS).
 * voucherTrustAtTime is snapshotted here so the recipient's trust delta is
 * reproducible from the token alone.
 */
export async function createVouchToken(account: Account): Promise<VouchToken> {
  const unsigned: UnsignedVouchToken = {
    voucherId: account.userId,
    name: account.name,
    voucherPublicKey: account.publicKey,
    voucherTrustAtTime: account.trustLevel,
    nonce: randomNonceBase64(),
    issuedAt: new Date().toISOString(),
  };
  const payload = canonicalVouchTokenBytes(unsigned);
  const signature = await signWithIdentity(account.userId, payload);
  return { ...unsigned, signature };
}

export type TokenVerifyError =
  | "bad-shape"
  | "bad-signature"
  | "expired"
  | "future-dated";

export interface TokenVerifyResult {
  ok: boolean;
  error?: TokenVerifyError;
  token?: VouchToken;
}

const CLOCK_SKEW_SECONDS = 30;

/**
 * Verify a vouch token: structural sanity, signature against its embedded
 * voucherPublicKey, and freshness. Does NOT enforce anything about who the
 * scanner is — that's the caller's responsibility.
 */
export async function verifyVouchToken(token: VouchToken): Promise<TokenVerifyResult> {
  if (!isWellFormed(token)) return { ok: false, error: "bad-shape" };

  const issued = Date.parse(token.issuedAt);
  if (Number.isNaN(issued)) return { ok: false, error: "bad-shape" };

  const now = Date.now();
  const ageSeconds = (now - issued) / 1000;
  if (ageSeconds > CARD_TTL_SECONDS) return { ok: false, error: "expired", token };
  if (ageSeconds < -CLOCK_SKEW_SECONDS) return { ok: false, error: "future-dated", token };

  const unsigned: UnsignedVouchToken = {
    voucherId: token.voucherId,
    name: token.name,
    voucherPublicKey: token.voucherPublicKey,
    voucherTrustAtTime: token.voucherTrustAtTime,
    nonce: token.nonce,
    issuedAt: token.issuedAt,
  };
  const payload = canonicalVouchTokenBytes(unsigned);
  const sigOk = await verifySignature(token.voucherPublicKey, payload, token.signature);
  if (!sigOk) return { ok: false, error: "bad-signature", token };
  return { ok: true, token };
}

function isWellFormed(t: unknown): t is VouchToken {
  if (!t || typeof t !== "object") return false;
  const o = t as Record<string, unknown>;
  return (
    typeof o.voucherId === "string" &&
    typeof o.name === "string" &&
    typeof o.voucherPublicKey === "string" &&
    typeof o.voucherTrustAtTime === "number" &&
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
