/**
 * Tiny IndexedDB wrapper that stores per-account WebCrypto CryptoKey objects.
 * CryptoKeys are structured-cloneable, so they survive in IDB and retain their
 * non-extractable property. This keeps the private key inside the browser's
 * crypto boundary — closest analogue to iOS Secure Enclave / Android Keystore.
 *
 * Each account's keypair is stored under its userId as the IDB record key.
 */

const DB_NAME = "blackout";
const DB_VERSION = 1;
const STORE = "keys";

export interface StoredIdentityKey {
  privateKey: CryptoKey; // non-extractable
  publicKey: CryptoKey;
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function putIdentityKey(userId: string, key: StoredIdentityKey): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).put(key, userId);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

export async function getIdentityKey(userId: string): Promise<StoredIdentityKey | null> {
  const db = await openDb();
  const result = await new Promise<StoredIdentityKey | null>((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const req = tx.objectStore(STORE).get(userId);
    req.onsuccess = () => resolve((req.result as StoredIdentityKey | undefined) ?? null);
    req.onerror = () => reject(req.error);
  });
  db.close();
  return result;
}

export async function deleteIdentityKey(userId: string): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).delete(userId);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

export async function clearAllIdentityKeys(): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).clear();
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}
