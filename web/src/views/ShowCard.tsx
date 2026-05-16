import { useEffect, useState } from "react";
import type { Account } from "../shared/types/account";
import type { VouchToken } from "../shared/types/identityCard";
import { CARD_TTL_SECONDS } from "../shared/types/identityCard";
import { createVouchToken } from "../shared/crypto/identityCard";

interface Props {
  account: Account;
  onClose: () => void;
}

export function ShowCard({ account, onClose }: Props) {
  const [token, setToken] = useState<VouchToken | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [secondsRemaining, setSecondsRemaining] = useState(CARD_TTL_SECONDS);

  async function regenerate() {
    setError(null);
    try {
      const next = await createVouchToken(account);
      setToken(next);
      setSecondsRemaining(CARD_TTL_SECONDS);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    void regenerate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [account.userId]);

  useEffect(() => {
    if (!token) return;
    const t = setInterval(() => {
      setSecondsRemaining((s) => Math.max(0, s - 1));
    }, 1000);
    return () => clearInterval(t);
  }, [token]);

  const json = token ? JSON.stringify(token, null, 2) : "";

  return (
    <div className="modal">
      <div className="modal-card">
        <header className="modal-header">
          <h2>{account.name}'s card</h2>
          <button type="button" className="link" onClick={onClose}>close</button>
        </header>
        <p className="muted small">
          Show this to someone so they can scan it and receive your trust.
          On mobile this is a QR code; here, copy the JSON into another account's "Scan card" view.
        </p>
        <textarea readOnly value={json} rows={14} className="payload" />
        <div className="modal-footer">
          <span className="muted small">
            {secondsRemaining > 0
              ? `valid for ${secondsRemaining}s`
              : "expired — regenerate"}
          </span>
          <div className="actions">
            <button type="button" className="secondary" onClick={() => navigator.clipboard.writeText(json)}>
              Copy
            </button>
            <button type="button" onClick={regenerate}>Regenerate</button>
          </div>
        </div>
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
