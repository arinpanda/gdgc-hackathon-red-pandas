import type { Organization } from "../shared/types/organization";
import type { Account } from "../shared/types/account";
import { createOrganization } from "../shared/crypto/organization";
import { founderMembership } from "../shared/crypto/orgInvite";
import { addMembership } from "./membershipStore";

const KEY = "blackout.organizations";

function read(): Organization[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as Organization[]) : [];
  } catch {
    return [];
  }
}

function write(orgs: Organization[]): void {
  localStorage.setItem(KEY, JSON.stringify(orgs));
}

export function listOrgs(): Organization[] {
  return read();
}

export function getOrg(orgId: string): Organization | null {
  return read().find((o) => o.id === orgId) ?? null;
}

/**
 * Found a new organization by `founder` (must be a superuser). Persists the
 * signed Organization record and also creates the founder's Membership.
 */
export async function foundOrganization(founder: Account, name: string): Promise<Organization> {
  const org = await createOrganization(founder, name);
  write([...read(), org]);
  addMembership(founderMembership(founder.userId, org));
  return org;
}

export function deleteOrg(orgId: string): void {
  write(read().filter((o) => o.id !== orgId));
}
