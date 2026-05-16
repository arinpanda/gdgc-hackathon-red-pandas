import { useState } from "react";
import type { Account } from "../shared/types/account";
import type { VouchToken } from "../shared/types/identityCard";
import { vouchFromScannedToken } from "../storage/vouchStore";

interface Props {
  active: Account;
  onVouched: () => void;
  onClose: () => void;
}

export function ScanCard({ active, onVouched, onClose }: Props) {
  const [pasted, setPasted] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleScan() {
    setError(null);
    setBusy(true);
    try {
      const token = JSON.parse(pasted) as VouchToken;
      await vouchFromScannedToken(active, token);
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
          Paste the card JSON someone is showing you. {active.name} will receive
          trust from the card holder.
          On mobile this opens the camera to scan their QR code.
        </p>
        <textarea
          autoFocus
          rows={14}
          className="payload"
          value={pasted}
          onChange={(e) => setPasted(e.target.value)}
          placeholder='{"voucherId":"...","name":"...","voucherPublicKey":"...","voucherTrustAtTime":0,"nonce":"...","issuedAt":"...","signature":"..."}'
          spellCheck={false}
        />
        <div className="modal-footer">
          <span className="muted small">acting as {active.name}</span>
          <div className="actions">
            <button type="button" className="secondary" onClick={onClose}>Cancel</button>
            <button type="button" onClick={handleScan} disabled={busy || pasted.trim() === ""}>
              {busy ? "Verifying…" : "Scan & receive trust"}
            </button>
          </div>
        </div>
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
