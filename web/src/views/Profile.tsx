import { useState } from "react";
import type { Account } from "../shared/types/account";
import type { Vouch } from "../shared/types/vouch";
import type { Membership, OrgInvite } from "../shared/types/orgInvite";
import type { Organization } from "../shared/types/organization";
import { FOUNDER_DEPTH } from "../shared/types/orgInvite";
import { fingerprint, shortUserId } from "../shared/types/account";

function keyFingerprint(pubKeyBase64: string): string {
  const bin = atob(pubKeyBase64);
  let hex = "";
  for (let i = 0; i < bin.length; i++) hex += bin.charCodeAt(i).toString(16).padStart(2, "0");
  return `${hex.slice(0, 4)}…${hex.slice(-4)}`;
}

interface ChainHop {
  invite: OrgInvite;
  isFounder: boolean;
}

function flattenChain(invite: OrgInvite): ChainHop[] {
  const hops: ChainHop[] = [];
  let cur: OrgInvite | null = invite;
  while (cur) {
    hops.push({ invite: cur, isFounder: cur.parent === null });
    cur = cur.parent;
  }
  return hops.reverse();
}

function ChainView({
  membership,
  accountsById,
}: {
  membership: Membership;
  accountsById: Map<string, Account>;
}) {
  const chain = membership.inviteChain ? flattenChain(membership.inviteChain) : [];
  if (chain.length === 0) return <p className="muted small">Founder — no invite chain.</p>;

  function labelForKey(pubKey: string): string {
    for (const acc of accountsById.values()) {
      if (acc.publicKey === pubKey) return acc.name;
    }
    return keyFingerprint(pubKey);
  }

  return (
    <ol style={{ margin: "8px 0 0", padding: "0 0 0 20px", fontSize: 13, lineHeight: 1.8 }}>
      {chain.map(({ invite, isFounder }, i) => (
        <li key={invite.id}>
          <strong>{isFounder ? "Founder" : `Hop ${i + 1}`}</strong>
          {" — "}
          <code style={{ fontSize: 12 }}>{labelForKey(invite.inviterPublicKey)}</code>
          {" issued depth "}
          <strong>{invite.depth === FOUNDER_DEPTH ? "∞" : invite.depth}</strong>
          <span className="muted small">
            {" · "}
            {new Date(invite.issuedAt).toLocaleString()}
          </span>
        </li>
      ))}
      <li>
        <strong>You</strong>
        <span className="muted small">
          {" — joined at depth "}
          {membership.joinedAtDepth === FOUNDER_DEPTH ? "∞" : membership.joinedAtDepth}
        </span>
      </li>
    </ol>
  );
}

interface Props {
  account: Account;
  vouchesReceived: Vouch[];
  vouchesGiven: Vouch[];
  accountsById: Map<string, Account>;
  memberships: Membership[];
  orgsById: Map<string, Organization>;
  isActive: boolean;
  onSetActive: () => void;
  onDelete: () => Promise<void>;
}

export function Profile({
  account,
  vouchesReceived,
  vouchesGiven,
  accountsById,
  memberships,
  orgsById,
  isActive,
  onSetActive,
  onDelete,
}: Props) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expandedChain, setExpandedChain] = useState<string | null>(null);
  const created = new Date(account.createdAt).toLocaleString();
  const professionDisplay = account.profession.trim() === ""
    ? <span className="muted">BASIC user (no profession claimed)</span>
    : account.profession;

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
          {account.isSuperuser && <span className="badge super"> superuser</span>}
          {isActive && <span className="badge"> active</span>}
        </h1>
        <div className="profile-actions">
          {!isActive && (
            <button type="button" className="secondary" onClick={onSetActive} disabled={busy}>
              Act as {account.name}
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

      <div>
        <h3>Organizations ({memberships.length})</h3>
        {memberships.length === 0 ? (
          <p className="muted small">Not a member of any organization.</p>
        ) : (
          <ul className="vouch-list">
            {memberships.map((m) => {
              const org = orgsById.get(m.orgId);
              const role = m.joinedAtDepth === FOUNDER_DEPTH
                ? "founder"
                : `joined at depth ${m.joinedAtDepth}`;
              const canInvite = m.joinedAtDepth === FOUNDER_DEPTH || m.joinedAtDepth > 1;
              const chainOpen = expandedChain === m.orgId;
              return (
                <li key={m.orgId} style={{ flexDirection: "column", alignItems: "stretch", gap: 4 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <span>{org?.name ?? <code>{m.orgId.slice(0, 8)}</code>}</span>
                    <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span className="muted small">
                        {role}{canInvite ? " · can invite" : " · leaf (cannot invite)"}
                      </span>
                      <button
                        type="button"
                        className="link"
                        onClick={() => setExpandedChain(chainOpen ? null : m.orgId)}
                      >
                        {chainOpen ? "hide chain" : "view chain"}
                      </button>
                    </span>
                  </div>
                  {chainOpen && (
                    <ChainView membership={m} accountsById={accountsById} />
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </div>

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
