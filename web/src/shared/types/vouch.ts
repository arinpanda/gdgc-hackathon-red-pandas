export interface Vouch {
  /** UUID v4 for this vouch record. */
  id: string;
  /** userId of the account doing the vouching. */
  voucherId: string;
  /** userId of the account being vouched for. */
  vouchedForId: string;
  /** Base64 raw P-256 public key of the voucher, copied for offline verification. */
  voucherPublicKey: string;
  /**
   * Snapshot of the voucher's own trustLevel at the moment of vouching.
   * Signed (so the voucher is attesting to it). The vouchee's trust delta is
   * derived from this value at vouch time only — never recomputed.
   */
  voucherTrustAtTime: number;
  /** ISO 8601 UTC timestamp. */
  createdAt: string;
  /** Base64 IEEE-P1363 ECDSA signature over canonicalize(unsignedFields). */
  signature: string;
}

/** Everything that goes into the signature, in deterministic canonical form. */
export interface UnsignedVouch {
  id: string;
  voucherId: string;
  vouchedForId: string;
  voucherPublicKey: string;
  voucherTrustAtTime: number;
  createdAt: string;
}

/**
 * Produce the byte payload that gets signed. Keys are sorted lexicographically,
 * no whitespace, UTF-8. Mobile MUST produce byte-identical output for any
 * vouch with the same field values.
 *
 * Numeric fields (voucherTrustAtTime) are serialized via JSON.stringify's
 * default number formatting. Mobile must use a JSON encoder that produces the
 * same canonical numeric form (e.g. `2` not `2.0`, `2.5` not `2.50`).
 */
export function canonicalVouchBytes(unsigned: UnsignedVouch): Uint8Array<ArrayBuffer> {
  const ordered: Record<string, string | number> = {};
  for (const key of Object.keys(unsigned).sort()) {
    ordered[key] = unsigned[key as keyof UnsignedVouch];
  }
  const json = JSON.stringify(ordered);
  const encoded = new TextEncoder().encode(json);
  const buf = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(buf).set(encoded);
  return new Uint8Array(buf);
}
