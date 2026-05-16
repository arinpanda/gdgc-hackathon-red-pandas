import type { Organization } from "./organization";

/**
 * A signed authorization to join an organization, with a bounded re-invite
 * cascade. The recursive `parent` field carries the chain of prior invites
 * back to the founder (where parent is null), so the recipient can
 * cryptographically verify the inviter's authority all the way to the org's
 * founding signature — no central authority required.
 *
 * `org` is only set on the outermost (top-level) invite shown via QR. Chain
 * elements (parents) carry the same orgId but omit the full Organization
 * record to keep payloads compact.
 *
 * `depth` follows the rule: a recipient of a depth-N invite may re-issue
 * invites at depths 1..N-1. depth=1 invites are LEAF — recipient joins but
 * cannot invite further.
 */
export interface OrgInvite {
  /** UUID v4 for this invite record. */
  id: string;
  /** Must match the outermost org.id. */
  orgId: string;
  /** base64 raw P-256 public key of the inviter. */
  inviterPublicKey: string;
  /** Number of further re-invite levels permitted to the recipient. Must be >= 1. */
  depth: number;
  /** base64 random nonce, fresh per issuance. */
  nonce: string;
  /** ISO 8601 UTC timestamp. */
  issuedAt: string;
  /** The invite the inviter themselves accepted, or null if the inviter is the org founder. */
  parent: OrgInvite | null;
  /** base64 IEEE-P1363 ECDSA signature by inviterPublicKey. */
  signature: string;
  /** Denormalized full Organization record; ONLY present on the outermost invite. */
  org?: Organization;
}

export interface UnsignedOrgInvite {
  id: string;
  orgId: string;
  inviterPublicKey: string;
  depth: number;
  nonce: string;
  issuedAt: string;
  /** Parent invite ID for signing purposes (full parent is in the transport form, not signed twice). */
  parentInviteId: string | null;
}

/**
 * What goes into each invite's signature. The parent invite is NOT recursively
 * signed-over here (it has its own signature); we just bind to its id so the
 * chain can't be reorganized.
 */
export function canonicalOrgInviteBytes(unsigned: UnsignedOrgInvite): Uint8Array<ArrayBuffer> {
  const ordered: Record<string, string | number | null> = {};
  for (const key of Object.keys(unsigned).sort()) {
    ordered[key] = unsigned[key as keyof UnsignedOrgInvite];
  }
  const json = JSON.stringify(ordered);
  const encoded = new TextEncoder().encode(json);
  const buf = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(buf).set(encoded);
  return new Uint8Array(buf);
}

/** Membership ttl & validity bounds (top-level invite only). */
export const ORG_INVITE_TTL_SECONDS = 120;

/**
 * The local record of having accepted an org invite. Stored in localStorage,
 * never transmitted. The inviteChain is kept for future audit and so the
 * member can re-prove how they got in if their membership is ever challenged.
 */
export interface Membership {
  orgId: string;
  memberId: string;
  /**
   * The depth of the invite the member accepted. Number.MAX_SAFE_INTEGER for
   * founders (effectively unbounded). Member may issue invites at any depth
   * strictly less than this value.
   */
  joinedAtDepth: number;
  acceptedAt: string;
  /** The invite that granted membership, with full chain. Null only for founders. */
  inviteChain: OrgInvite | null;
}

export const FOUNDER_DEPTH = Number.MAX_SAFE_INTEGER;
