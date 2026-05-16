import { getIdentityKey, putIdentityKey, deleteIdentityKey } from "./keyStore";

const ALGO = { name: "ECDSA", namedCurve: "P-256" } as const;
const SIGN_ALGO = { name: "ECDSA", hash: "SHA-256" } as const;

export interface CreatedIdentity {
  /** base64 of raw uncompressed-SEC1 public key bytes (65 bytes). */
  publicKeyBase64: string;
}

/**
 * Generate a fresh P-256 ECDSA keypair for `userId`, persist it as
 * non-extractable in IndexedDB, and return the base64 public key.
 */
export async function createIdentity(userId: string): Promise<CreatedIdentity> {
  const generated = await crypto.subtle.generateKey(ALGO, true, ["sign", "verify"]);
  const rawPub = await crypto.subtle.exportKey("raw", generated.publicKey);
  const privJwk = await crypto.subtle.exportKey("jwk", generated.privateKey);
  const nonExtractablePriv = await crypto.subtle.importKey(
    "jwk", privJwk, ALGO, /* extractable */ false, ["sign"],
  );

  await putIdentityKey(userId, {
    privateKey: nonExtractablePriv,
    publicKey: generated.publicKey,
  });

  return { publicKeyBase64: bytesToBase64(new Uint8Array(rawPub)) };
}

export async function hasIdentity(userId: string): Promise<boolean> {
  return (await getIdentityKey(userId)) !== null;
}

/**
 * Sign a payload with `userId`'s stored private key. Returns base64 of a raw
 * IEEE-P1363 signature (64 bytes for P-256: r || s).
 */
export async function signWithIdentity(userId: string, payload: BufferSource): Promise<string> {
  const stored = await getIdentityKey(userId);
  if (!stored) throw new Error(`No identity key for user ${userId}`);
  const sig = await crypto.subtle.sign(SIGN_ALGO, stored.privateKey, payload);
  return bytesToBase64(new Uint8Array(sig));
}

/**
 * Verify an IEEE-P1363 signature against a raw uncompressed-SEC1 P-256 public
 * key (both base64-encoded). Returns true if the signature is valid.
 */
export async function verifySignature(
  publicKeyBase64: string,
  payload: BufferSource,
  signatureBase64: string,
): Promise<boolean> {
  const rawPub = base64ToBytes(publicKeyBase64);
  const sig = base64ToBytes(signatureBase64);
  const pubKey = await crypto.subtle.importKey(
    "raw", rawPub, ALGO, /* extractable */ true, ["verify"],
  );
  return crypto.subtle.verify(SIGN_ALGO, pubKey, sig, payload);
}

export async function destroyIdentity(userId: string): Promise<void> {
  await deleteIdentityKey(userId);
}

function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function base64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const buf = new ArrayBuffer(bin.length);
  const out = new Uint8Array(buf);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
