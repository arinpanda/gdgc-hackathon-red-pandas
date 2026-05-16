import type { Vouch, UnsignedVouch } from "../shared/types/vouch";
import { canonicalVouchBytes } from "../shared/types/vouch";
import type { IdentityCard } from "../shared/types/identityCard";
import { signWithIdentity, verifySignature } from "../shared/crypto/identityKey";
import { verifyIdentityCard } from "../shared/crypto/identityCard";
import { vouchDelta } from "../shared/trust/vouchDelta";
import type { Account } from "../shared/types/account";
import { getAccount, saveAccount } from "./accountStore";

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
 * `vouchedForId`, then bump the vouchee's stored trustLevel by the snapshot
 * delta. Only the vouchee's account record is mutated — no graph traversal.
 *
 * Throws if voucher has no identity key, the pair already vouched, or
 * signature verification fails.
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

  const voucher = getAccount(voucherId);
  const vouchee = getAccount(vouchedForId);
  if (!voucher) throw new Error(`Voucher ${voucherId} not found`);
  if (!vouchee) throw new Error(`Vouchee ${vouchedForId} not found`);

  const unsigned: UnsignedVouch = {
    id: crypto.randomUUID(),
    voucherId,
    vouchedForId,
    voucherPublicKey,
    voucherTrustAtTime: voucher.trustLevel,
    createdAt: new Date().toISOString(),
  };

  const payload = canonicalVouchBytes(unsigned);
  const signature = await signWithIdentity(voucherId, payload);

  // Self-verify before persisting; catches encoding bugs early.
  const ok = await verifySignature(voucherPublicKey, payload, signature);
  if (!ok) throw new Error("Signature failed self-verification");

  const vouch: Vouch = { ...unsigned, signature };
  write([...existing, vouch]);

  // Apply the delta. Only the vouchee's record is touched.
  saveAccount({
    ...vouchee,
    trustLevel: vouchee.trustLevel + vouchDelta(unsigned.voucherTrustAtTime),
  });

  return vouch;
}

export function deleteVouch(vouchId: string): void {
  write(read().filter((v) => v.id !== vouchId));
}

/**
 * The QR-handshake entry point: the active account "scans" another party's
 * IdentityCard, the card is verified (signature + freshness), and a vouch is
 * created from active → card.userId.
 *
 * On mobile this is invoked after the camera decodes a QR. On the web
 * reference, the card is pasted as JSON. Either way, the card itself carries
 * everything we need to verify.
 */
export async function vouchFromScannedCard(
  active: Account,
  card: IdentityCard,
): Promise<Vouch> {
  if (active.userId === card.userId) {
    throw new Error("You cannot scan your own card");
  }
  const result = await verifyIdentityCard(card);
  if (!result.ok) {
    throw new Error(`Card invalid: ${result.error}`);
  }
  return createVouch({
    voucherId: active.userId,
    voucherPublicKey: active.publicKey,
    vouchedForId: card.userId,
  });
}
