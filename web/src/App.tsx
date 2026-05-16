import { useEffect, useMemo, useState } from "react";
import type { Account } from "./shared/types/account";
import type { Vouch } from "./shared/types/vouch";
import {
  listAccounts,
  getActiveUserId,
  setActiveUserId,
  deleteAccount,
  clearAllAccounts,
} from "./storage/accountStore";
import { listVouches, deleteVouch } from "./storage/vouchStore";
import { Onboarding } from "./views/Onboarding";
import { AccountList } from "./views/AccountList";
import { Profile } from "./views/Profile";
import { ShowCard } from "./views/ShowCard";
import { ScanCard } from "./views/ScanCard";

type View = { kind: "creating" } | { kind: "browsing" };
type Modal = null | { kind: "show" } | { kind: "scan" };

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
  const [modal, setModal] = useState<Modal>(null);

  const accountsById = useMemo(() => {
    const m = new Map<string, Account>();
    for (const a of accounts) m.set(a.userId, a);
    return m;
  }, [accounts]);

  const activeAccount = activeUserId ? accountsById.get(activeUserId) ?? null : null;
  const selectedAccount = selectedUserId ? accountsById.get(selectedUserId) ?? null : null;

  useEffect(() => {
    if (activeUserId && !accountsById.has(activeUserId)) {
      const next = accounts[0]?.userId ?? null;
      setActiveUserId(next);
      setActive(next);
    }
  }, [accounts, accountsById, activeUserId]);

  function handleCreated(account: Account) {
    if (!activeUserId) {
      setActiveUserId(account.userId);
      setActive(account.userId);
    }
    setAccounts(listAccounts());
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

  async function handleDelete() {
    if (!selectedAccount) return;
    const id = selectedAccount.userId;
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

  function handleVouched() {
    // ScanCard already persisted; just refresh local state.
    setAccounts(listAccounts());
    setVouches(listVouches());
  }

  if (view.kind === "creating") {
    return (
      <Onboarding
        onCreated={handleCreated}
        onCancel={accounts.length > 0 ? () => setView({ kind: "browsing" }) : undefined}
      />
    );
  }

  return (
    <div className="layout">
      <header className="topbar">
        <h1>Blackout <span className="muted small">simulator</span></h1>
        <div className="topbar-actions">
          <span className="muted small">
            acting as {activeAccount?.name ?? <em>none</em>}
          </span>
          <button
            type="button"
            className="secondary"
            onClick={() => setModal({ kind: "show" })}
            disabled={!activeAccount}
            title={activeAccount ? undefined : "Set an active account first"}
          >
            Show my card
          </button>
          <button
            type="button"
            onClick={() => setModal({ kind: "scan" })}
            disabled={!activeAccount}
            title={activeAccount ? undefined : "Set an active account first"}
          >
            Scan card
          </button>
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
          onSelect={handleSelect}
          onSetActive={handleSetActive}
          onNew={() => setView({ kind: "creating" })}
        />
        <main className="content">
          {selectedAccount ? (
            <Profile
              account={selectedAccount}
              vouchesReceived={vouches.filter((v) => v.vouchedForId === selectedAccount.userId)}
              vouchesGiven={vouches.filter((v) => v.voucherId === selectedAccount.userId)}
              accountsById={accountsById}
              isActive={activeAccount?.userId === selectedAccount.userId}
              onSetActive={() => handleSetActive(selectedAccount.userId)}
              onDelete={handleDelete}
            />
          ) : (
            <p className="muted">Select an account from the sidebar.</p>
          )}
        </main>
      </div>

      {modal?.kind === "show" && activeAccount && (
        <ShowCard account={activeAccount} onClose={() => setModal(null)} />
      )}
      {modal?.kind === "scan" && activeAccount && (
        <ScanCard
          active={activeAccount}
          onVouched={handleVouched}
          onClose={() => setModal(null)}
        />
      )}
    </div>
  );
}
