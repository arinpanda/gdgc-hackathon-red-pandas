import { useEffect, useMemo, useState } from "react";
import type { Account } from "./shared/types/account";
import type { Vouch } from "./shared/types/vouch";
import type { Organization } from "./shared/types/organization";
import type { Membership } from "./shared/types/orgInvite";
import {
  listAccounts,
  getActiveUserId,
  setActiveUserId,
  deleteAccount,
  clearAllAccounts,
} from "./storage/accountStore";
import { listVouches, deleteVouch } from "./storage/vouchStore";
import { listOrgs } from "./storage/orgStore";
import {
  listMemberships,
  membershipsFor,
  deleteMembershipsForMember,
} from "./storage/membershipStore";
import { Onboarding } from "./views/Onboarding";
import { AccountList } from "./views/AccountList";
import { Profile } from "./views/Profile";
import { ShowCard } from "./views/ShowCard";
import { ScanCard } from "./views/ScanCard";
import { CreateOrg } from "./views/CreateOrg";
import { ShowInvite } from "./views/ShowInvite";
import { ScanInvite } from "./views/ScanInvite";

type View = { kind: "creating" } | { kind: "browsing" };
type Modal =
  | null
  | { kind: "show-card" }
  | { kind: "scan-card" }
  | { kind: "create-org" }
  | { kind: "show-invite" }
  | { kind: "scan-invite" };

export default function App() {
  const [accounts, setAccounts] = useState<Account[]>(() => listAccounts());
  const [vouches, setVouches] = useState<Vouch[]>(() => listVouches());
  const [orgs, setOrgs] = useState<Organization[]>(() => listOrgs());
  const [memberships, setMemberships] = useState<Membership[]>(() => listMemberships());
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

  const orgsById = useMemo(() => {
    const m = new Map<string, Organization>();
    for (const o of orgs) m.set(o.id, o);
    return m;
  }, [orgs]);

  const activeAccount = activeUserId ? accountsById.get(activeUserId) ?? null : null;
  const selectedAccount = selectedUserId ? accountsById.get(selectedUserId) ?? null : null;
  const selectedMemberships = useMemo(
    () => (selectedAccount ? memberships.filter((m) => m.memberId === selectedAccount.userId) : []),
    [memberships, selectedAccount],
  );

  useEffect(() => {
    if (activeUserId && !accountsById.has(activeUserId)) {
      const next = accounts[0]?.userId ?? null;
      setActiveUserId(next);
      setActive(next);
    }
  }, [accounts, accountsById, activeUserId]);

  function refreshAll() {
    setAccounts(listAccounts());
    setVouches(listVouches());
    setOrgs(listOrgs());
    setMemberships(listMemberships());
    setActive(getActiveUserId());
  }

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
      if (v.voucherId === id || v.vouchedForId === id) deleteVouch(v.id);
    }
    deleteMembershipsForMember(id);
    await deleteAccount(id);
    const remaining = listAccounts();
    setAccounts(remaining);
    setVouches(listVouches());
    setMemberships(listMemberships());
    setActive(getActiveUserId());
    setSelected(remaining[0]?.userId ?? null);
    if (remaining.length === 0) setView({ kind: "creating" });
  }

  async function handleClearAll() {
    if (!confirm("Wipe ALL accounts, keys, vouches, organizations, and memberships?")) return;
    await clearAllAccounts();
    localStorage.removeItem("blackout.vouches");
    localStorage.removeItem("blackout.organizations");
    localStorage.removeItem("blackout.memberships");
    setAccounts([]);
    setVouches([]);
    setOrgs([]);
    setMemberships([]);
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

  const activeIsSuperuser = !!activeAccount?.isSuperuser;
  const activeIsMember = !!(activeAccount && membershipsFor(activeAccount.userId).length > 0);

  return (
    <div className="layout">
      <header className="topbar">
        <h1>Blackout <span className="muted small">simulator</span></h1>
        <div className="topbar-actions">
          <span className="muted small">
            acting as {activeAccount?.name ?? <em>none</em>}
            {activeIsSuperuser && <span className="badge super"> super</span>}
          </span>
          <button type="button" className="secondary" onClick={() => setModal({ kind: "show-card" })} disabled={!activeAccount}>
            Show my card
          </button>
          <button type="button" onClick={() => setModal({ kind: "scan-card" })} disabled={!activeAccount}>
            Scan card
          </button>
          {activeIsSuperuser && (
            <button type="button" className="secondary" onClick={() => setModal({ kind: "create-org" })}>
              Create org
            </button>
          )}
          {activeIsMember && (
            <button type="button" className="secondary" onClick={() => setModal({ kind: "show-invite" })}>
              Show invite
            </button>
          )}
          <button type="button" className="secondary" onClick={() => setModal({ kind: "scan-invite" })} disabled={!activeAccount}>
            Scan invite
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
              memberships={selectedMemberships}
              orgsById={orgsById}
              isActive={activeAccount?.userId === selectedAccount.userId}
              onSetActive={() => handleSetActive(selectedAccount.userId)}
              onDelete={handleDelete}
            />
          ) : (
            <p className="muted">Select an account from the sidebar.</p>
          )}
        </main>
      </div>

      {modal?.kind === "show-card" && activeAccount && (
        <ShowCard account={activeAccount} onClose={() => setModal(null)} />
      )}
      {modal?.kind === "scan-card" && activeAccount && (
        <ScanCard active={activeAccount} onVouched={refreshAll} onClose={() => setModal(null)} />
      )}
      {modal?.kind === "create-org" && activeAccount && activeAccount.isSuperuser && (
        <CreateOrg founder={activeAccount} onCreated={refreshAll} onClose={() => setModal(null)} />
      )}
      {modal?.kind === "show-invite" && activeAccount && (
        <ShowInvite account={activeAccount} onClose={() => setModal(null)} />
      )}
      {modal?.kind === "scan-invite" && activeAccount && (
        <ScanInvite active={activeAccount} onAccepted={refreshAll} onClose={() => setModal(null)} />
      )}
    </div>
  );
}
