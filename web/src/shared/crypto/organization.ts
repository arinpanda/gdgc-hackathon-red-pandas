import type { Account } from "../types/account";
import type { Organization, UnsignedOrganization } from "../types/organization";
import { canonicalOrganizationBytes } from "../types/organization";
import { signWithIdentity, verifySignature } from "./identityKey";

export async function createOrganization(founder: Account, name: string): Promise<Organization> {
  if (!founder.isSuperuser) {
    throw new Error("Only superusers can found organizations");
  }
  const trimmed = name.trim();
  if (trimmed === "") throw new Error("Organization name is required");

  const unsigned: UnsignedOrganization = {
    id: crypto.randomUUID(),
    name: trimmed,
    founderId: founder.userId,
    founderPublicKey: founder.publicKey,
    createdAt: new Date().toISOString(),
  };
  const payload = canonicalOrganizationBytes(unsigned);
  const signature = await signWithIdentity(founder.userId, payload);
  // Self-verify to catch encoding bugs early.
  if (!(await verifySignature(founder.publicKey, payload, signature))) {
    throw new Error("Organization signature failed self-verification");
  }
  return { ...unsigned, signature };
}

export async function verifyOrganization(org: Organization): Promise<boolean> {
  const unsigned: UnsignedOrganization = {
    id: org.id,
    name: org.name,
    founderId: org.founderId,
    founderPublicKey: org.founderPublicKey,
    createdAt: org.createdAt,
  };
  return verifySignature(org.founderPublicKey, canonicalOrganizationBytes(unsigned), org.signature);
}
