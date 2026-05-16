import { useState } from "react";
import type { Account } from "../shared/types/account";
import { foundOrganization } from "../storage/orgStore";

interface Props {
  founder: Account;
  onCreated: () => void;
  onClose: () => void;
}

export function CreateOrg({ founder, onCreated, onClose }: Props) {
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCreate() {
    setError(null);
    setBusy(true);
    try {
      await foundOrganization(founder, name);
      onCreated();
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
          <h2>Create organization</h2>
          <button type="button" className="link" onClick={onClose}>close</button>
        </header>
        <p className="muted small">
          {founder.name} will be the founder. The org is signed by their key.
        </p>
        <label htmlFor="orgName">Organization name</label>
        <input
          id="orgName"
          type="text"
          autoFocus
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <div className="modal-footer">
          <span />
          <div className="actions">
            <button type="button" className="secondary" onClick={onClose} disabled={busy}>Cancel</button>
            <button type="button" onClick={handleCreate} disabled={busy || name.trim() === ""}>
              {busy ? "Creating…" : "Create"}
            </button>
          </div>
        </div>
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
