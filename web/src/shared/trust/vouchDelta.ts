/**
 * Decentralized trust math.
 *
 * When account A vouches for account B, only B's stored trustLevel changes.
 * No global graph computation. The delta depends only on A's trust at the
 * moment of vouching (which is snapshotted into the Vouch record and signed,
 * so the math is reproducible from the vouch alone).
 *
 *   delta = 1 + W * voucherTrustAtTime
 *   B.trustLevel := B.trustLevel + delta
 *
 * Properties:
 *   - Locality: a vouch event only mutates the vouchee's stored trust. The
 *     voucher's trust is unchanged. Nobody else's trust is touched. This is
 *     what lets the system be truly decentralized — a peer-to-peer vouch
 *     between two devices doesn't require any third party to recompute state.
 *   - Additive: trust only grows from vouches. Counter-vouches (negative
 *     deltas) are a future feature.
 *   - Reproducible: from the signed vouch, anyone can verify the delta that
 *     was applied. Mobile peers receiving a vouch via sync apply the same
 *     formula.
 */
export const TRUST_VOUCHER_WEIGHT = 0.5;

export function vouchDelta(voucherTrustAtTime: number): number {
  return 1 + TRUST_VOUCHER_WEIGHT * voucherTrustAtTime;
}
