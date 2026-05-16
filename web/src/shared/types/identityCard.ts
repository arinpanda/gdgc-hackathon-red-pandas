/**
 * The signed payload an account hands to another account during an in-person
 * trust handshake. On mobile this is encoded into a QR code shown by the
 * holder and scanned by the other party's camera. On the web reference
 * implementation it is exchanged as JSON text (the camera UX is mobile-only).
 */
export interface IdentityCard {
  /** Holder's userId. */
  userId: string;
  /** Holder's display name. Included so the scanner can show it without a lookup. */
  name: string;
  /** Holder's base64 raw P-256 public key (uncompressed SEC1). */
  publicKey: string;
  /** Random base64 nonce, freshly generated on each card issuance. */
  nonce: string;
  /** ISO 8601 UTC timestamp at which the card was issued. */
  issuedAt: string;
  /** Base64 IEEE-P1363 ECDSA signature over canonicalize(everything-except-signature). */
  signature: string;
}

export interface UnsignedIdentityCard {
  userId: string;
  name: string;
  publicKey: string;
  nonce: string;
  issuedAt: string;
}

/** Cards older than this many seconds are rejected by the verifier. */
export const CARD_TTL_SECONDS = 120;

/**
 * Canonical signing payload: lexicographically-sorted keys, no whitespace,
 * UTF-8. Mobile MUST produce byte-identical output for any card with the same
 * field values, or signatures will not verify cross-platform.
 */
export function canonicalIdentityCardBytes(unsigned: UnsignedIdentityCard): Uint8Array<ArrayBuffer> {
  const ordered: Record<string, string> = {};
  for (const key of Object.keys(unsigned).sort()) {
    ordered[key] = unsigned[key as keyof UnsignedIdentityCard];
  }
  const json = JSON.stringify(ordered);
  const encoded = new TextEncoder().encode(json);
  const buf = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(buf).set(encoded);
  return new Uint8Array(buf);
}
