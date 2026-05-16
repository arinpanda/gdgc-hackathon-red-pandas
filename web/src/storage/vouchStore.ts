import type { Vouch, UnsignedVouch } from "../shared/types/vouch";
import { canonicalVouchBytes } from "../shared/types/vouch";
import { signWithIdentity, verifySignature } from "../shared/crypto/identityKey";

const KEY = "blackout.vouches";

function read(): Vouch[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as Vouch[]) : [];
  } catch {
    return [];
  }
}

function write(vouches: Vouch[]): void {
  localStorage.setItem(KEY, JSON.stringify(vouches));
}

export function listVouches(): Vouch[] {
  return read();
}

export function vouchesFor(userId: string): Vouch[] {
  return read().filter((v) => v.vouchedForId === userId);
}

export function vouchesBy(userId: string): Vouch[] {
  return read().filter((v) => v.voucherId === userId);
}

/**
 * Create, sign, verify, and persist a new vouch from `voucher` to
 * `vouchedForId`. Throws if the voucher has no identity key, if a vouch
 * already exists between this pair, or if signature verification fails.
 */
export async function createVouch(args: {
  voucherId: string;
  voucherPublicKey: string;
  vouchedForId: string;
}): Promise<Vouch> {
  const { voucherId, voucherPublicKey, vouchedForId } = args;
  if (voucherId === vouchedForId) {
    throw new Error("An account cannot vouch for itself");
  }
  const existing = read();
  if (existing.some((v) => v.voucherId === voucherId && v.vouchedForId === vouchedForId)) {
    throw new Error("This voucher has already vouched for this account");
  }

  const unsigned: UnsignedVouch = {
    id: crypto.randomUUID(),
    voucherId,
    vouchedForId,
    voucherPublicKey,
    createdAt: new Date().toISOString(),
  };

  const payload = canonicalVouchBytes(unsigned);
  const signature = await signWithIdentity(voucherId, payload);

  // Verify before persisting — sanity check that the signing path produces a
  // signature the verification path accepts. Catches encoding bugs early.
  const ok = await verifySignature(voucherPublicKey, payload, signature);
  if (!ok) throw new Error("Signature failed self-verification");

  const vouch: Vouch = { ...unsigned, signature };
  write([...existing, vouch]);
  return vouch;
}

export function deleteVouch(vouchId: string): void {
  write(read().filter((v) => v.id !== vouchId));
}
