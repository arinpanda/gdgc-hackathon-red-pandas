import type { Account } from "../shared/types/account";
import { destroyIdentity } from "../shared/crypto/identityKey";

const ACCOUNTS_KEY = "blackout.accounts";
const ACTIVE_KEY = "blackout.activeUserId";

function readAccounts(): Account[] {
  try {
    const raw = localStorage.getItem(ACCOUNTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed as Account[];
  } catch {
    return [];
  }
}

function writeAccounts(accounts: Account[]): void {
  localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(accounts));
}

export function listAccounts(): Account[] {
  return readAccounts();
}

export function getAccount(userId: string): Account | null {
  return readAccounts().find((a) => a.userId === userId) ?? null;
}

export function getActiveUserId(): string | null {
  return localStorage.getItem(ACTIVE_KEY);
}

export function setActiveUserId(userId: string | null): void {
  if (userId === null) {
    localStorage.removeItem(ACTIVE_KEY);
  } else {
    localStorage.setItem(ACTIVE_KEY, userId);
  }
}

export function getActiveAccount(): Account | null {
  const id = getActiveUserId();
  return id ? getAccount(id) : null;
}

export function saveAccount(account: Account): void {
  const accounts = readAccounts();
  const idx = accounts.findIndex((a) => a.userId === account.userId);
  if (idx >= 0) {
    accounts[idx] = account;
  } else {
    accounts.push(account);
  }
  writeAccounts(accounts);
}

export async function deleteAccount(userId: string): Promise<void> {
  const remaining = readAccounts().filter((a) => a.userId !== userId);
  writeAccounts(remaining);
  await destroyIdentity(userId);
  if (getActiveUserId() === userId) {
    setActiveUserId(remaining[0]?.userId ?? null);
  }
}

export async function clearAllAccounts(): Promise<void> {
  const all = readAccounts();
  await Promise.all(all.map((a) => destroyIdentity(a.userId)));
  localStorage.removeItem(ACCOUNTS_KEY);
  localStorage.removeItem(ACTIVE_KEY);
}
