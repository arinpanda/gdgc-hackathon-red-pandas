import { useState } from "react";
import type { Account, IdType } from "../shared/types/account";
import { ID_TYPE_LABELS, INITIAL_TRUST_LEVEL } from "../shared/types/account";
import { createIdentity } from "../shared/crypto/identityKey";
import { saveAccount } from "../storage/accountStore";

interface Props {
  onCreated: (account: Account) => void;
  onCancel?: () => void;
}

const ID_TYPES: IdType[] = ["passport", "drivers_license"];
const MIN_AGE = 13;
const MAX_AGE = 120;

export function Onboarding({ onCreated, onCancel }: Props) {
  const [name, setName] = useState("");
  const [age, setAge] = useState("");
  const [profession, setProfession] = useState("");
  const [locale, setLocale] = useState("");
  const [idType, setIdType] = useState<IdType>("passport");
  const [idNumber, setIdNumber] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const trimmedName = name.trim();
  const trimmedLocale = locale.trim();
  const trimmedIdNumber = idNumber.trim();
  const parsedAge = Number(age);
  const ageValid = Number.isInteger(parsedAge) && parsedAge >= MIN_AGE && parsedAge <= MAX_AGE;

  const canSubmit =
    !isCreating &&
    trimmedName.length > 0 &&
    ageValid &&
    trimmedLocale.length > 0 &&
    trimmedIdNumber.length > 0;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    setError(null);
    setIsCreating(true);
    try {
      const userId = crypto.randomUUID();
      const { publicKeyBase64 } = await createIdentity(userId);
      const account: Account = {
        userId,
        name: trimmedName,
        age: parsedAge,
        trustLevel: INITIAL_TRUST_LEVEL,
        profession: profession.trim(),
        locale: trimmedLocale,
        publicKey: publicKeyBase64,
        createdAt: new Date().toISOString(),
      };
      saveAccount(account);
      onCreated(account);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsCreating(false);
    }
  }

  return (
    <div className="card">
      <h1>New account</h1>
      <p className="lede">
        A signing key will be generated in your browser and stored securely.
        Your ID is checked here but not saved.
      </p>
      <form onSubmit={handleSubmit}>
        <label htmlFor="name">Name</label>
        <input id="name" type="text" value={name} onChange={(e) => setName(e.target.value)} autoComplete="off" autoFocus />

        <label htmlFor="age">Age</label>
        <input id="age" type="number" inputMode="numeric" min={MIN_AGE} max={MAX_AGE} value={age} onChange={(e) => setAge(e.target.value)} />

        <label htmlFor="profession">Profession <span className="muted">(optional)</span></label>
        <input id="profession" type="text" value={profession} onChange={(e) => setProfession(e.target.value)} placeholder="e.g. Doctor, Lawyer, Teacher" autoComplete="off" />

        <label htmlFor="locale">Location</label>
        <input id="locale" type="text" value={locale} onChange={(e) => setLocale(e.target.value)} placeholder="e.g. London, UK" autoComplete="off" />

        <fieldset className="gate">
          <legend>Government ID</legend>
          <p className="muted small">Required to create an account. Not stored on this device or transmitted.</p>
          <label htmlFor="idType">ID type</label>
          <select id="idType" value={idType} onChange={(e) => setIdType(e.target.value as IdType)}>
            {ID_TYPES.map((t) => (
              <option key={t} value={t}>{ID_TYPE_LABELS[t]}</option>
            ))}
          </select>
          <label htmlFor="idNumber">ID number</label>
          <input id="idNumber" type="text" value={idNumber} onChange={(e) => setIdNumber(e.target.value)} autoComplete="off" spellCheck={false} />
        </fieldset>

        <div className="actions">
          <button type="submit" disabled={!canSubmit}>
            {isCreating ? "Creating…" : "Create account"}
          </button>
          {onCancel && (
            <button type="button" className="secondary" onClick={onCancel} disabled={isCreating}>
              Cancel
            </button>
          )}
        </div>
        {error && <p className="error">Couldn't create account: {error}</p>}
      </form>
    </div>
  );
}
