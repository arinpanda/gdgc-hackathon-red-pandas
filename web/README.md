# Blackout — Web App

Walking skeleton for account creation. Vite + React + TypeScript. WebCrypto for the keypair, `localStorage` for persistence. No backend.

## What this first pass does

1. On first visit, prompts for a display name.
2. Generates a P-256 ECDSA keypair via WebCrypto.
3. Persists the account (id, name, public-key base64, createdAt) in `localStorage` under the key `blackout.account`.
4. On subsequent visits, skips onboarding and shows the profile screen.

No identity anchoring (passport / gov-ID), no vouches, no peer sync yet. The private key isn't persisted yet either — that lands when signing matters.

## Running it

```bash
cd web
npm install     # only the first time
npm run dev     # http://localhost:5173
npm run build   # type-check + production build into dist/
```

## File layout

```
web/src/
├── main.tsx                  # React entry
├── App.tsx                   # routes onboarding ↔ profile based on localStorage
├── index.css                 # global styles
├── types/
│   └── account.ts            # Account interface + fingerprint helper
├── storage/
│   └── accountStore.ts       # load / save / clear in localStorage
├── crypto/
│   └── identityKey.ts        # WebCrypto P-256 keypair → base64 public key
└── views/
    ├── Onboarding.tsx        # name input + Create account
    └── Profile.tsx           # name, key fingerprint, created date, reset
```

## Notes

- WebCrypto requires a **secure context** — `localhost` and `https://` are fine; raw `file://` is not.
- Clearing browser storage (or hitting "Reset account") wipes the local account; there's no recovery yet.
- The native iOS plan in `../agents.md` and `../ios/` is the long-term direction; this web app is the hackathon-demo path.
