import type { Membership } from "../shared/types/orgInvite";

const KEY = "blackout.memberships";

function read(): Membership[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as Membership[]) : [];
  } catch {
    return [];
  }
}

function write(memberships: Membership[]): void {
  localStorage.setItem(KEY, JSON.stringify(memberships));
}

export function listMemberships(): Membership[] {
  return read();
}

export function membershipsFor(userId: string): Membership[] {
  return read().filter((m) => m.memberId === userId);
}

export function getMembership(userId: string, orgId: string): Membership | null {
  return read().find((m) => m.memberId === userId && m.orgId === orgId) ?? null;
}

/** Add a membership. Idempotent on (memberId, orgId): later additions are ignored. */
export function addMembership(m: Membership): void {
  const existing = read();
  if (existing.some((e) => e.memberId === m.memberId && e.orgId === m.orgId)) return;
  write([...existing, m]);
}

export function deleteMembershipsForMember(userId: string): void {
  write(read().filter((m) => m.memberId !== userId));
}

export function deleteMembershipsForOrg(orgId: string): void {
  write(read().filter((m) => m.orgId !== orgId));
}
