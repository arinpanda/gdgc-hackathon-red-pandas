import { useEffect, useMemo, useState } from "react";
import type { Account } from "../shared/types/account";
import type { Membership, OrgInvite } from "../shared/types/orgInvite";
import { FOUNDER_DEPTH, ORG_INVITE_TTL_SECONDS } from "../shared/types/orgInvite";
import { createOrgInvite } from "../shared/crypto/orgInvite";
import { membershipsFor } from "../storage/membershipStore";
import { getOrg } from "../storage/orgStore";

interface Props {
  account: Account;
  onClose: () => void;
}

export function ShowInvite({ account, onClose }: Props) {
  const memberships = useMemo(() => membershipsFor(account.userId), [account.userId]);
  const [orgId, setOrgId] = useState<string | null>(memberships[0]?.orgId ?? null);
  const [depth, setDepth] = useState<number>(1);
  const [invite, setInvite] = useState<OrgInvite | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [secondsRemaining, setSecondsRemaining] = useState(ORG_INVITE_TTL_SECONDS);

  const selectedMembership: Membership | null = useMemo(
    () => memberships.find((m) => m.orgId === orgId) ?? null,
    [memberships, orgId],
  );

  const maxDepth = selectedMembership
    ? Math.min(10, selectedMembership.joinedAtDepth === FOUNDER_DEPTH ? 10 : selectedMembership.joinedAtDepth - 1)
    : 0;

  useEffect(() => {
    if (selectedMembership && depth > maxDepth) setDepth(maxDepth);
    if (selectedMembership && depth < 1) setDepth(1);
  }, [selectedMembership, maxDepth, depth]);

  async function regenerate() {
    if (!selectedMembership) return;
    setError(null);
    try {
      const org = getOrg(selectedMembership.orgId);
      if (!org) throw new Error("Org not found locally");
      const next = await createOrgInvite({
        issuerUserId: account.userId,
        issuerPublicKey: account.publicKey,
        membership: selectedMembership,
        depth,
        org,
      });
      setInvite(next);
      setSecondsRemaining(ORG_INVITE_TTL_SECONDS);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    setInvite(null);
  }, [orgId, depth]);

  useEffect(() => {
    if (!invite) return;
    const t = setInterval(() => setSecondsRemaining((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, [invite]);

  const json = invite ? JSON.stringify(invite, null, 2) : "";

  if (memberships.length === 0) {
    return (
      <div className="modal">
        <div className="modal-card">
          <header className="modal-header">
            <h2>Show invite</h2>
            <button type="button" className="link" onClick={onClose}>close</button>
          </header>
          <p>{account.name} is not a member of any organization yet.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="modal">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Invite to organization</h2>
          <button type="button" className="link" onClick={onClose}>close</button>
        </header>

        <label htmlFor="invOrg">Organization</label>
        <select
          id="invOrg"
          value={orgId ?? ""}
          onChange={(e) => setOrgId(e.target.value || null)}
        >
          {memberships.map((m) => {
            const org = getOrg(m.orgId);
            const yourDepth = m.joinedAtDepth === FOUNDER_DEPTH ? "founder" : `joined depth ${m.joinedAtDepth}`;
            return (
              <option key={m.orgId} value={m.orgId}>
                {org?.name ?? m.orgId} ({yourDepth})
              </option>
            );
          })}
        </select>

        <label htmlFor="invDepth">Invite depth (1 = leaf, recipient cannot re-invite)</label>
        <input
          id="invDepth"
          type="number"
          min={1}
          max={maxDepth}
          value={depth}
          onChange={(e) => setDepth(Math.max(1, Math.min(maxDepth, Number(e.target.value) || 1)))}
        />
        <p className="muted small">
          You can issue invites at depths 1..{maxDepth}.
        </p>

        {!invite ? (
          <div className="modal-footer">
            <span />
            <button type="button" onClick={regenerate}>Generate invite</button>
          </div>
        ) : (
          <>
            <textarea readOnly value={json} rows={12} className="payload" />
            <div className="modal-footer">
              <span className="muted small">
                {secondsRemaining > 0 ? `valid for ${secondsRemaining}s` : "expired — regenerate"}
              </span>
              <div className="actions">
                <button type="button" className="secondary" onClick={() => navigator.clipboard.writeText(json)}>
                  Copy
                </button>
                <button type="button" onClick={regenerate}>Regenerate</button>
              </div>
            </div>
          </>
        )}
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
