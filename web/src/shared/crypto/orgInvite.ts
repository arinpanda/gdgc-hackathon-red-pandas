import type { Organization } from "../types/organization";
import type {
  OrgInvite,
  UnsignedOrgInvite,
  Membership,
} from "../types/orgInvite";
import {
  ORG_INVITE_TTL_SECONDS,
  canonicalOrgInviteBytes,
  FOUNDER_DEPTH,
} from "../types/orgInvite";
import { signWithIdentity, verifySignature } from "./identityKey";
import { verifyOrganization } from "./organization";

const CLOCK_SKEW_SECONDS = 30;

export type InviteVerifyError =
  | "bad-shape"
  | "missing-org"
  | "org-id-mismatch"
  | "org-signature-invalid"
  | "expired"
  | "future-dated"
  | "bad-signature"
  | "depth-rule-violated"
  | "root-not-founder"
  | "depth-zero-or-negative";

export interface InviteVerifyResult {
  ok: boolean;
  error?: InviteVerifyError;
  /** On success, the depth the recipient will join at (== top invite's depth). */
  joinedAtDepth?: number;
  /** Echoed for convenience. */
  org?: Organization;
}

/**
 * Build a fresh signed OrgInvite from an existing membership. The parent is
 * the membership's `inviteChain` (the invite the issuer originally accepted),
 * or null if the issuer is the org founder.
 */
export async function createOrgInvite(args: {
  issuerUserId: string;
  issuerPublicKey: string;
  membership: Membership;
  depth: number;
  org: Organization;
}): Promise<OrgInvite> {
  const { issuerUserId, issuerPublicKey, membership, depth, org } = args;

  if (!Number.isInteger(depth) || depth < 1) {
    throw new Error("Invite depth must be an integer >= 1");
  }
  if (depth >= membership.joinedAtDepth) {
    throw new Error(
      `Cannot issue depth=${depth}: must be strictly less than your joinedAtDepth (${membership.joinedAtDepth})`,
    );
  }
  if (membership.orgId !== org.id) {
    throw new Error("Membership orgId does not match org");
  }

  const parent = membership.inviteChain; // null iff founder
  const unsigned: UnsignedOrgInvite = {
    id: crypto.randomUUID(),
    orgId: org.id,
    inviterPublicKey: issuerPublicKey,
    depth,
    nonce: randomNonceBase64(),
    issuedAt: new Date().toISOString(),
    parentInviteId: parent?.id ?? null,
  };
  const payload = canonicalOrgInviteBytes(unsigned);
  const signature = await signWithIdentity(issuerUserId, payload);
  if (!(await verifySignature(issuerPublicKey, payload, signature))) {
    throw new Error("Invite signature failed self-verification");
  }

  return {
    id: unsigned.id,
    orgId: unsigned.orgId,
    inviterPublicKey: unsigned.inviterPublicKey,
    depth: unsigned.depth,
    nonce: unsigned.nonce,
    issuedAt: unsigned.issuedAt,
    parent,
    signature,
    org, // outer carries the full org record
  };
}

/**
 * Verify a scanned invite end-to-end:
 *   1. Top-level invite must carry the org; org signature must verify.
 *   2. Every invite in the chain has a verifying signature against its inviterPublicKey.
 *   3. Every invite in the chain shares the same orgId.
 *   4. Depth strictly decreases down the chain (child.depth < parent.depth).
 *   5. Root invite (parent=null) must be signed by org.founderPublicKey.
 *   6. Top-level invite must be within ORG_INVITE_TTL_SECONDS (chain elements are historical, not freshness-checked).
 *   7. depth >= 1 throughout.
 */
export async function verifyOrgInviteChain(invite: OrgInvite): Promise<InviteVerifyResult> {
  if (!isWellFormed(invite)) return { ok: false, error: "bad-shape" };

  const org = invite.org;
  if (!org) return { ok: false, error: "missing-org" };

  // Top-level freshness
  const issued = Date.parse(invite.issuedAt);
  if (Number.isNaN(issued)) return { ok: false, error: "bad-shape" };
  const ageSeconds = (Date.now() - issued) / 1000;
  if (ageSeconds > ORG_INVITE_TTL_SECONDS) return { ok: false, error: "expired" };
  if (ageSeconds < -CLOCK_SKEW_SECONDS) return { ok: false, error: "future-dated" };

  // Org signature
  if (!(await verifyOrganization(org))) return { ok: false, error: "org-signature-invalid" };

  // Walk the chain.
  let current: OrgInvite | null = invite;
  let parentForCurrent: OrgInvite | null = invite.parent;
  while (current) {
    if (current.depth < 1) return { ok: false, error: "depth-zero-or-negative" };
    if (current.orgId !== org.id) return { ok: false, error: "org-id-mismatch" };

    // Signature for current invite.
    const unsigned: UnsignedOrgInvite = {
      id: current.id,
      orgId: current.orgId,
      inviterPublicKey: current.inviterPublicKey,
      depth: current.depth,
      nonce: current.nonce,
      issuedAt: current.issuedAt,
      parentInviteId: parentForCurrent?.id ?? null,
    };
    const sigOk = await verifySignature(
      current.inviterPublicKey,
      canonicalOrgInviteBytes(unsigned),
      current.signature,
    );
    if (!sigOk) return { ok: false, error: "bad-signature" };

    if (parentForCurrent) {
      // Depth rule
      if (current.depth >= parentForCurrent.depth) return { ok: false, error: "depth-rule-violated" };
    } else {
      // Root invite: must be signed by org founder.
      if (current.inviterPublicKey !== org.founderPublicKey) {
        return { ok: false, error: "root-not-founder" };
      }
    }

    current = parentForCurrent;
    parentForCurrent = parentForCurrent?.parent ?? null;
  }

  return { ok: true, joinedAtDepth: invite.depth, org };
}

/** Construct the local Membership record from an accepted invite. */
export function membershipFromInvite(memberId: string, invite: OrgInvite): Membership {
  if (!invite.org) throw new Error("Cannot derive membership from chain invite (no org)");
  return {
    orgId: invite.org.id,
    memberId,
    joinedAtDepth: invite.depth,
    acceptedAt: new Date().toISOString(),
    inviteChain: invite,
  };
}

/** Founder membership (no invite required). */
export function founderMembership(memberId: string, org: Organization): Membership {
  if (memberId !== org.founderId) throw new Error("Only the founder gets founder membership");
  return {
    orgId: org.id,
    memberId,
    joinedAtDepth: FOUNDER_DEPTH,
    acceptedAt: org.createdAt,
    inviteChain: null,
  };
}

function isWellFormed(c: unknown): c is OrgInvite {
  if (!c || typeof c !== "object") return false;
  const o = c as Record<string, unknown>;
  return (
    typeof o.id === "string" &&
    typeof o.orgId === "string" &&
    typeof o.inviterPublicKey === "string" &&
    typeof o.depth === "number" &&
    typeof o.nonce === "string" &&
    typeof o.issuedAt === "string" &&
    typeof o.signature === "string" &&
    (o.parent === null || (typeof o.parent === "object" && o.parent !== null))
  );
}

function randomNonceBase64(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}
