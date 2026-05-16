import type { Vouch } from "../types/vouch";

export const TRUST_ITERATIONS = 5;
export const TRUST_VOUCHER_WEIGHT = 0.5;

/**
 * Compute trust levels for every userId given the full vouch set.
 *
 * Math (v0 — simple compounding):
 *   trust(u) = sum over distinct vouchers v in vouchesFor(u) of (1 + W * trust(v))
 *   where W = TRUST_VOUCHER_WEIGHT (0.5).
 *
 * Computed by fixed-point iteration starting from 0 for all users, repeated
 * TRUST_ITERATIONS times. Cycles (A↔B vouches) produce stable but inflated
 * values; that's a known v0 limitation. Mobile MUST use the same constants
 * and iteration count to produce identical results from the same vouch graph.
 *
 * Duplicate vouches (same voucher → same vouchee) are de-duplicated; only the
 * first such vouch counts. Self-vouches are rejected at the storage layer and
 * also ignored here defensively.
 */
export function computeTrust(
  userIds: Iterable<string>,
  vouches: Vouch[],
): Map<string, number> {
  const ids = Array.from(userIds);

  // Build vouchee -> set of distinct vouchers.
  const vouchersOf = new Map<string, Set<string>>();
  for (const id of ids) vouchersOf.set(id, new Set());
  for (const v of vouches) {
    if (v.voucherId === v.vouchedForId) continue;
    const set = vouchersOf.get(v.vouchedForId);
    if (set) set.add(v.voucherId);
  }

  // Iterate.
  let trust = new Map<string, number>(ids.map((id) => [id, 0]));
  for (let iter = 0; iter < TRUST_ITERATIONS; iter++) {
    const next = new Map<string, number>();
    for (const id of ids) {
      const vouchers = vouchersOf.get(id) ?? new Set();
      let sum = 0;
      for (const vId of vouchers) {
        sum += 1 + TRUST_VOUCHER_WEIGHT * (trust.get(vId) ?? 0);
      }
      next.set(id, sum);
    }
    trust = next;
  }
  return trust;
}
