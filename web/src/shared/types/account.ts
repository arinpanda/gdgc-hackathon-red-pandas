/**
 * An ID type the user must present to create an account. The chosen type and
 * the ID number are validated at onboarding but NEVER stored in the Account
 * JSON or transmitted anywhere — they exist only in the form state.
 */
export type IdType = "passport" | "drivers_license";

export const ID_TYPE_LABELS: Record<IdType, string> = {
  passport: "Passport",
  drivers_license: "Driver's licence",
};

export interface Account {
  /** Internal UUID v4. Not user-facing as a handle. */
  userId: string;
  /** Display name as entered. Trimmed, non-empty. */
  name: string;
  /** Integer years, 13–120. */
  age: number;
  /**
   * Single trust score. Starts at 0 on account creation. Recomputed locally
   * as vouches arrive (computation lives outside this module). Stored on the
   * Account record so callers don't need the vouch graph just to render it.
   */
  trustLevel: number;
  /** Free-text. Empty string means "no profession claimed" (BASIC user). */
  profession: string;
  /** Free-text locale (e.g. "London, UK"). Non-empty. */
  locale: string;
  /** base64 of raw P-256 public-key bytes (65 bytes, uncompressed SEC1). */
  publicKey: string;
  /** ISO 8601 UTC timestamp. */
  createdAt: string;
}

export const INITIAL_TRUST_LEVEL = 0;

export function fingerprint(account: Account): string {
  const hex = base64ToHex(account.publicKey);
  return `${hex.slice(0, 4)}…${hex.slice(-4)}`;
}

/** First 8 chars of a UUID for compact display. */
export function shortUserId(userId: string): string {
  return userId.split("-")[0] ?? userId.slice(0, 8);
}

function base64ToHex(b64: string): string {
  const bin = atob(b64);
  let out = "";
  for (let i = 0; i < bin.length; i++) {
    out += bin.charCodeAt(i).toString(16).padStart(2, "0");
  }
  return out;
}
