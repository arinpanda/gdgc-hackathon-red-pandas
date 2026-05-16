import { useState } from "react";
import type { Account } from "../shared/types/account";
import type { Vouch } from "../shared/types/vouch";
import { fingerprint, shortUserId } from "../shared/types/account";

interface Props {
  account: Account;
  vouchesReceived: Vouch[];
  vouchesGiven: Vouch[];
  accountsById: Map<string, Account>;
  activeAccount: Account | null;
  /** True iff a vouch already exists from active → this profile. */
  alreadyVouched: boolean;
  onVouch: () => Promise<void>;
  onSetActive: () => void;
  onDelete: () => Promise<void>;
}

export function Profile({
  account,
  vouchesReceived,
  vouchesGiven,
  accountsById,
  activeAccount,
  alreadyVouched,
  onVouch,
  onSetActive,
  onDelete,
}: Props) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const created = new Date(account.createdAt).toLocaleString();
  const isActive = activeAccount?.userId === account.userId;
  const professionDisplay = account.profession.trim() === ""
    ? <span className="muted">BASIC user (no profession claimed)</span>
    : account.profession;

  async function handleVouch() {
    setError(null);
    setBusy(true);
    try {
      await onVouch();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    if (!confirm(`Delete "${account.name}" and its identity key? Vouches involving this account will also be removed.`)) return;
    setError(null);
    setBusy(true);
    try {
      await onDelete();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setBusy(false);
    }
  }

  return (
    <section className="profile">
      <header className="profile-header">
        <h1>
          {account.name}
          {isActive && <span className="badge"> active</span>}
        </h1>
        <div className="profile-actions">
          {!isActive && (
            <button type="button" className="secondary" onClick={onSetActive} disabled={busy}>
              Act as {account.name}
            </button>
          )}
          {activeAccount && !isActive && (
            <button
              type="button"
              onClick={handleVouch}
              disabled={busy || alreadyVouched}
              title={alreadyVouched ? `${activeAccount.name} has already vouched for ${account.name}` : undefined}
            >
              {alreadyVouched ? `${activeAccount.name} already vouched` : `Vouch as ${activeAccount.name}`}
            </button>
          )}
          <button type="button" className="secondary danger" onClick={handleDelete} disabled={busy}>
            Delete
          </button>
        </div>
      </header>

      <dl className="kv">
        <dt>Age</dt><dd>{account.age}</dd>
        <dt>User ID</dt><dd><code>{shortUserId(account.userId)}</code></dd>
        <dt>Trust level</dt><dd><strong>{account.trustLevel.toFixed(2)}</strong></dd>
        <dt>Profession</dt><dd>{professionDisplay}</dd>
        <dt>Location</dt><dd>{account.locale}</dd>
        <dt>Key</dt><dd><code>{fingerprint(account)}</code></dd>
        <dt>Created</dt><dd>{created}</dd>
      </dl>

      {error && <p className="error">{error}</p>}

      <div className="vouch-lists">
        <div>
          <h3>Vouches received ({vouchesReceived.length})</h3>
          <VouchList vouches={vouchesReceived} accountsById={accountsById} otherKey="voucherId" />
        </div>
        <div>
          <h3>Vouches given ({vouchesGiven.length})</h3>
          <VouchList vouches={vouchesGiven} accountsById={accountsById} otherKey="vouchedForId" />
        </div>
      </div>
    </section>
  );
}

function VouchList({
  vouches,
  accountsById,
  otherKey,
}: {
  vouches: Vouch[];
  accountsById: Map<string, Account>;
  otherKey: "voucherId" | "vouchedForId";
}) {
  if (vouches.length === 0) return <p className="muted small">None yet.</p>;
  return (
    <ul className="vouch-list">
      {vouches.map((v) => {
        const otherId = v[otherKey];
        const other = accountsById.get(otherId);
        const otherName = other?.name ?? <code>{shortUserId(otherId)}</code>;
        return (
          <li key={v.id}>
            <span>{otherName}</span>
            <span className="muted small">
              {new Date(v.createdAt).toLocaleString()} · sig ✓
            </span>
          </li>
        );
      })}
    </ul>
  );
}
