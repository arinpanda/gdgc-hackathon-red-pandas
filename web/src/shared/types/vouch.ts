export interface Vouch {
  /** UUID v4 for this vouch record. */
  id: string;
  /** userId of the account doing the vouching. */
  voucherId: string;
  /** userId of the account being vouched for. */
  vouchedForId: string;
  /** Base64 raw P-256 public key of the voucher, copied for offline verification. */
  voucherPublicKey: string;
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
  createdAt: string;
}

/**
 * Produce the byte payload that gets signed. Keys are sorted lexicographically,
 * no whitespace, UTF-8. Mobile MUST produce byte-identical output for any
 * vouch with the same field values.
 */
export function canonicalVouchBytes(unsigned: UnsignedVouch): Uint8Array<ArrayBuffer> {
  const ordered: Record<string, string> = {};
  for (const key of Object.keys(unsigned).sort()) {
    ordered[key] = unsigned[key as keyof UnsignedVouch];
  }
  const json = JSON.stringify(ordered);
  const encoded = new TextEncoder().encode(json);
  const buf = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(buf).set(encoded);
  return new Uint8Array(buf);
}
