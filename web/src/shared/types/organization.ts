export interface Organization {
  /** UUID v4. */
  id: string;
  /** Display name. Trimmed, non-empty. */
  name: string;
  /** userId of the founding superuser. */
  founderId: string;
  /** base64 raw P-256 public key of the founder (denormalized for verification). */
  founderPublicKey: string;
  /** ISO 8601 UTC timestamp. */
  createdAt: string;
  /** base64 IEEE-P1363 ECDSA signature by founderPublicKey over canonicalize(unsignedFields). */
  signature: string;
}

export interface UnsignedOrganization {
  id: string;
  name: string;
  founderId: string;
  founderPublicKey: string;
  createdAt: string;
}

export function canonicalOrganizationBytes(unsigned: UnsignedOrganization): Uint8Array<ArrayBuffer> {
  const ordered: Record<string, string> = {};
  for (const key of Object.keys(unsigned).sort()) {
    ordered[key] = unsigned[key as keyof UnsignedOrganization];
  }
  const json = JSON.stringify(ordered);
  const encoded = new TextEncoder().encode(json);
  const buf = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(buf).set(encoded);
  return new Uint8Array(buf);
}
