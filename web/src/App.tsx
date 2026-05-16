import { useEffect, useMemo, useState } from "react";
import type { Account } from "./shared/types/account";
import type { Vouch } from "./shared/types/vouch";
import { computeTrust } from "./shared/trust/computeTrust";
import {
  listAccounts,
  getActiveUserId,
  setActiveUserId,
  deleteAccount,
  clearAllAccounts,
} from "./storage/accountStore";
import { listVouches, createVouch, deleteVouch } from "./storage/vouchStore";
import { Onboarding } from "./views/Onboarding";
import { AccountList } from "./views/AccountList";
import { Profile } from "./views/Profile";

type View = { kind: "creating" } | { kind: "browsing" };

export default function App() {
  const [accounts, setAccounts] = useState<Account[]>(() => listAccounts());
  const [vouches, setVouches] = useState<Vouch[]>(() => listVouches());
  const [activeUserId, setActive] = useState<string | null>(() => getActiveUserId());
  const [selectedUserId, setSelected] = useState<string | null>(() => {
    const list = listAccounts();
    return getActiveUserId() ?? list[0]?.userId ?? null;
  });
  const [view, setView] = useState<View>(() =>
    listAccounts().length === 0 ? { kind: "creating" } : { kind: "browsing" }
  );

  const accountsById = useMemo(() => {
    const m = new Map<string, Account>();
    for (const a of accounts) m.set(a.userId, a);
    return m;
  }, [accounts]);

  const trustLevels = useMemo(
    () => computeTrust(accounts.map((a) => a.userId), vouches),
    [accounts, vouches],
  );

  const activeAccount = activeUserId ? accountsById.get(activeUserId) ?? null : null;
  const selectedAccount = selectedUserId ? accountsById.get(selectedUserId) ?? null : null;

  // If the active account no longer exists, pick another.
  useEffect(() => {
    if (activeUserId && !accountsById.has(activeUserId)) {
      const next = accounts[0]?.userId ?? null;
      setActiveUserId(next);
      setActive(next);
    }
  }, [accounts, accountsById, activeUserId]);

  function refresh() {
    setAccounts(listAccounts());
    setVouches(listVouches());
    setActive(getActiveUserId());
  }

  function handleCreated(account: Account) {
    if (!activeUserId) {
      setActiveUserId(account.userId);
    }
    refresh();
    setSelected(account.userId);
    setView({ kind: "browsing" });
  }

  function handleSelect(userId: string) {
    setSelected(userId);
  }

  function handleSetActive(userId: string) {
    setActiveUserId(userId);
    setActive(userId);
  }

  async function handleVouch() {
    if (!activeAccount || !selectedAccount) return;
    await createVouch({
      voucherId: activeAccount.userId,
      voucherPublicKey: activeAccount.publicKey,
      vouchedForId: selectedAccount.userId,
    });
    setVouches(listVouches());
  }

  async function handleDelete() {
    if (!selectedAccount) return;
    const id = selectedAccount.userId;
    // Cascade: remove vouches involving this account.
    for (const v of listVouches()) {
      if (v.voucherId === id || v.vouchedForId === id) {
        deleteVouch(v.id);
      }
    }
    await deleteAccount(id);
    const remaining = listAccounts();
    setAccounts(remaining);
    setVouches(listVouches());
    setActive(getActiveUserId());
    setSelected(remaining[0]?.userId ?? null);
    if (remaining.length === 0) setView({ kind: "creating" });
  }

  async function handleClearAll() {
    if (!confirm("Wipe ALL accounts, keys, and vouches?")) return;
    await clearAllAccounts();
    localStorage.removeItem("blackout.vouches");
    setAccounts([]);
    setVouches([]);
    setActive(null);
    setSelected(null);
    setView({ kind: "creating" });
  }

  if (view.kind === "creating") {
    return (
      <Onboarding
        onCreated={handleCreated}
        onCancel={accounts.length > 0 ? () => setView({ kind: "browsing" }) : undefined}
      />
    );
  }

  const alreadyVouched = !!(
    activeAccount &&
    selectedAccount &&
    vouches.some(
      (v) => v.voucherId === activeAccount.userId && v.vouchedForId === selectedAccount.userId,
    )
  );

  return (
    <div className="layout">
      <header className="topbar">
        <h1>Blackout <span className="muted small">simulator</span></h1>
        <div className="topbar-actions">
          <span className="muted small">
            acting as {activeAccount?.name ?? <em>none</em>}
          </span>
          <button type="button" className="secondary" onClick={handleClearAll}>
            Wipe all
          </button>
        </div>
      </header>
      <div className="main">
        <AccountList
          accounts={accounts}
          selectedUserId={selectedUserId}
          activeUserId={activeUserId}
          trustLevels={trustLevels}
          onSelect={handleSelect}
          onSetActive={handleSetActive}
          onNew={() => setView({ kind: "creating" })}
        />
        <main className="content">
          {selectedAccount ? (
            <Profile
              account={selectedAccount}
              trustLevel={trustLevels.get(selectedAccount.userId) ?? 0}
              vouchesReceived={vouches.filter((v) => v.vouchedForId === selectedAccount.userId)}
              vouchesGiven={vouches.filter((v) => v.voucherId === selectedAccount.userId)}
              accountsById={accountsById}
              activeAccount={activeAccount}
              alreadyVouched={alreadyVouched}
              onVouch={handleVouch}
              onSetActive={() => handleSetActive(selectedAccount.userId)}
              onDelete={handleDelete}
            />
          ) : (
            <p className="muted">Select an account from the sidebar.</p>
          )}
        </main>
      </div>
    </div>
  );
}
