import type { Account } from "../shared/types/account";

interface Props {
  accounts: Account[];
  selectedUserId: string | null;
  activeUserId: string | null;
  trustLevels: Map<string, number>;
  onSelect: (userId: string) => void;
  onSetActive: (userId: string) => void;
  onNew: () => void;
}

export function AccountList({
  accounts,
  selectedUserId,
  activeUserId,
  trustLevels,
  onSelect,
  onSetActive,
  onNew,
}: Props) {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <h2>Accounts</h2>
        <button type="button" onClick={onNew}>+ New</button>
      </div>
      <ul className="account-list">
        {accounts.map((a) => {
          const trust = trustLevels.get(a.userId) ?? 0;
          const isActive = a.userId === activeUserId;
          const isSelected = a.userId === selectedUserId;
          return (
            <li
              key={a.userId}
              className={`account-item${isSelected ? " selected" : ""}`}
            >
              <button
                type="button"
                className="account-row"
                onClick={() => onSelect(a.userId)}
              >
                <span className="account-name">
                  {a.name}
                  {isActive && <span className="badge"> active</span>}
                </span>
                <span className="account-meta">
                  trust {trust.toFixed(2)} · {a.profession || "BASIC"}
                </span>
              </button>
              {!isActive && (
                <button
                  type="button"
                  className="link"
                  onClick={() => onSetActive(a.userId)}
                  title="Act as this user"
                >
                  act as
                </button>
              )}
            </li>
          );
        })}
        {accounts.length === 0 && (
          <li className="muted small empty">No accounts yet.</li>
        )}
      </ul>
    </aside>
  );
}
