import { useState } from "react";
import type { Account } from "../shared/types/account";
import type { OrgInvite } from "../shared/types/orgInvite";
import { verifyOrgInviteChain, membershipFromInvite } from "../shared/crypto/orgInvite";
import { addMembership } from "../storage/membershipStore";
import { listOrgs } from "../storage/orgStore";

interface Props {
  active: Account;
  onAccepted: () => void;
  onClose: () => void;
}

export function ScanInvite({ active, onAccepted, onClose }: Props) {
  const [pasted, setPasted] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleAccept() {
    setError(null);
    setBusy(true);
    try {
      const invite = JSON.parse(pasted) as OrgInvite;
      const result = await verifyOrgInviteChain(invite);
      if (!result.ok || !result.org) {
        throw new Error(`Invite invalid: ${result.error}`);
      }
      if (invite.inviterPublicKey === active.publicKey) {
        throw new Error("You issued this invite — pass it to someone else");
      }
      const membership = membershipFromInvite(active.userId, invite);
      addMembership(membership);
      // Locally cache the org if we don't already have it (org is signed; safe to keep).
      const knownOrgIds = new Set(listOrgs().map((o) => o.id));
      if (!knownOrgIds.has(result.org.id)) {
        // Mirror through localStorage to avoid coupling to orgStore internals.
        const orgs = listOrgs();
        localStorage.setItem("blackout.organizations", JSON.stringify([...orgs, result.org]));
      }
      onAccepted();
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="modal">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Scan invite</h2>
          <button type="button" className="link" onClick={onClose}>close</button>
        </header>
        <p className="muted small">
          Paste an organization invite payload. The full chain back to the founder will be verified.
          {active.name} will join the org if the chain is valid.
        </p>
        <textarea
          autoFocus
          rows={14}
          className="payload"
          value={pasted}
          onChange={(e) => setPasted(e.target.value)}
          placeholder='{"id":"...","orgId":"...","inviterPublicKey":"...","depth":2,...,"org":{...}}'
          spellCheck={false}
        />
        <div className="modal-footer">
          <span className="muted small">acting as {active.name}</span>
          <div className="actions">
            <button type="button" className="secondary" onClick={onClose}>Cancel</button>
            <button type="button" onClick={handleAccept} disabled={busy || pasted.trim() === ""}>
              {busy ? "Verifying chain…" : "Verify & join"}
            </button>
          </div>
        </div>
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
