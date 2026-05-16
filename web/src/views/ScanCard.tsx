import { useState } from "react";
import type { Account } from "../shared/types/account";
import { vouchFromScannedCard } from "../storage/vouchStore";

interface Props {
  active: Account;
  onVouched: () => void;
  onClose: () => void;
}

export function ScanCard({ active, onVouched, onClose }: Props) {
  const [pasted, setPasted] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleVouch() {
    setError(null);
    setBusy(true);
    try {
      const card = JSON.parse(pasted);
      await vouchFromScannedCard(active, card);
      onVouched();
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
          <h2>Scan card</h2>
          <button type="button" className="link" onClick={onClose}>close</button>
        </header>
        <p className="muted small">
          On mobile this opens the camera to scan a QR. Here, paste the card JSON
          someone else generated. {active.name} will vouch for the card holder.
        </p>
        <textarea
          autoFocus
          rows={14}
          className="payload"
          value={pasted}
          onChange={(e) => setPasted(e.target.value)}
          placeholder='{"userId":"...","name":"...","publicKey":"...","nonce":"...","issuedAt":"...","signature":"..."}'
          spellCheck={false}
        />
        <div className="modal-footer">
          <span className="muted small">acting as {active.name}</span>
          <div className="actions">
            <button type="button" className="secondary" onClick={onClose}>Cancel</button>
            <button type="button" onClick={handleVouch} disabled={busy || pasted.trim() === ""}>
              {busy ? "Verifying…" : "Verify & vouch"}
            </button>
          </div>
        </div>
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
