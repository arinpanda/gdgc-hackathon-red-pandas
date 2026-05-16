import type { Vouch } from "../shared/types/vouch";
import type { VouchToken } from "../shared/types/identityCard";
import { verifyVouchToken } from "../shared/crypto/identityCard";
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

export function deleteVouch(vouchId: string): void {
  write(read().filter((v) => v.id !== vouchId));
}

/**
 * The QR-handshake entry point. The active account scans a VouchToken shown by
 * another party and receives trust from them.
 *
 * Flow: token holder shows card → active account scans it → active account is
 * the vouchee; token holder is the voucher.
 *
 * The stored Vouch.signature is the token holder's signature over the token
 * fields (excludes vouchedForId — see VouchToken docs for the security rationale).
 */
export async function vouchFromScannedToken(
  active: Account,
  token: VouchToken,
): Promise<Vouch> {
  if (token.voucherId === active.userId) {
    throw new Error("You cannot scan your own token");
  }

  const result = await verifyVouchToken(token);
  if (!result.ok) {
    throw new Error(`Token invalid: ${result.error}`);
  }

  const existing = read();
  if (existing.some((v) => v.voucherId === token.voucherId && v.vouchedForId === active.userId)) {
    throw new Error("You have already received a vouch from this account");
  }

  const vouchee = getAccount(active.userId);
  if (!vouchee) throw new Error("Active account not found");

  const vouch: Vouch = {
    id: crypto.randomUUID(),
    voucherId: token.voucherId,
    vouchedForId: active.userId,
    voucherPublicKey: token.voucherPublicKey,
    voucherTrustAtTime: token.voucherTrustAtTime,
    createdAt: new Date().toISOString(),
    signature: token.signature,
  };

  write([...existing, vouch]);

  saveAccount({
    ...vouchee,
    trustLevel: vouchee.trustLevel + vouchDelta(token.voucherTrustAtTime),
  });

  return vouch;
}
