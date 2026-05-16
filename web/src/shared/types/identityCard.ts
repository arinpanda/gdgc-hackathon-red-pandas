/**
 * An open vouch token: a short-lived signed payload issued by the card holder
 * that grants trust to whoever scans it. vouchedForId is intentionally absent
 * from the signed payload — the recipient (scanner) is self-claimed, and the
 * TTL + physical-proximity requirement bound the exposure window.
 *
 * On mobile this is encoded into a QR code shown by the holder and scanned by
 * the other party's camera. On the web reference implementation it is exchanged
 * as JSON text.
 */
export interface VouchToken {
  /** Holder's userId. Identifies the voucher for duplicate-check purposes. */
  voucherId: string;
  /** Holder's display name. Included so the scanner can show it without a lookup. */
  name: string;
  /** Holder's base64 raw P-256 public key (uncompressed SEC1). */
  voucherPublicKey: string;
  /**
   * Snapshot of the holder's trustLevel at issuance time. Signed, so the
   * recipient can compute the exact trust delta without knowing the holder's
   * current (possibly changed) trust.
   */
  voucherTrustAtTime: number;
  /** Random base64 nonce, freshly generated on each issuance. */
  nonce: string;
  /** ISO 8601 UTC timestamp at which the token was issued. */
  issuedAt: string;
  /**
   * Base64 IEEE-P1363 ECDSA signature over canonicalize(all fields above).
   * Does NOT cover vouchedForId — that field is filled in by the scanner.
   */
  signature: string;
}

export interface UnsignedVouchToken {
  voucherId: string;
  name: string;
  voucherPublicKey: string;
  voucherTrustAtTime: number;
  nonce: string;
  issuedAt: string;
}

/** Tokens older than this many seconds are rejected by the verifier. */
export const CARD_TTL_SECONDS = 120;

/**
 * Canonical signing payload: lexicographically-sorted keys, no whitespace,
 * UTF-8. Mobile MUST produce byte-identical output for any token with the same
 * field values, or signatures will not verify cross-platform.
 */
export function canonicalVouchTokenBytes(unsigned: UnsignedVouchToken): Uint8Array<ArrayBuffer> {
  const ordered: Record<string, string | number> = {};
  for (const key of Object.keys(unsigned).sort()) {
    ordered[key] = unsigned[key as keyof UnsignedVouchToken];
  }
  const json = JSON.stringify(ordered);
  const encoded = new TextEncoder().encode(json);
  const buf = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(buf).set(encoded);
  return new Uint8Array(buf);
}
