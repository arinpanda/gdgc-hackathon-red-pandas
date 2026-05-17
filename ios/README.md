# Blackout iOS App

Walking skeleton for account creation. Native iOS, SwiftUI, iOS 17+. Local-only JSON persistence. No backend.

## What this first pass does

1. On first launch, prompts for a display name.
2. Generates a P-256 keypair (Secure Enclave on real devices, ephemeral fallback on simulator).
3. Persists the account as JSON in the app's Documents directory.
4. On subsequent launches, skips onboarding and shows the profile screen.

No identity anchoring (passport / gov-ID), no vouches, no peer sync yet — those are the next steps.

## Bootstrapping the Xcode project

Xcode isn't installed yet on this machine. Install it (free from the Mac App Store), then:

1. **File → New → Project → iOS → App**
2. Product Name: `Blackout`
3. Interface: **SwiftUI**, Language: **Swift**, Storage: **None**, include tests if you want
4. Save the project somewhere convenient (the generated `.xcodeproj` does **not** need to live in this repo — keep it elsewhere and reference these sources)
5. In Xcode's Project Navigator, delete the auto-generated `ContentView.swift` and `BlackoutApp.swift`
6. Drag the contents of `ios/Blackout/` from this repo into the Xcode project (check "Create groups", not "Create folder references")
7. In the target's **General** tab, set **Minimum Deployments** to iOS 17.0
8. Build & run on the iOS 17+ simulator

## File layout

```
ios/Blackout/
├── BlackoutApp.swift           # @main entry point
├── Models/
│   └── Account.swift           # Codable local account record
├── Storage/
│   └── AccountStore.swift      # JSON read/write in Documents/
├── Crypto/
│   └── IdentityKey.swift       # P-256 keypair (Secure Enclave + simulator fallback)
└── Views/
    ├── ContentView.swift       # Routes onboarding ↔ profile
    ├── OnboardingView.swift    # Name input + Create account
    └── ProfileView.swift       # Name, pubkey fingerprint, created date
```

## Simulator caveats

- **Secure Enclave is not available on the simulator.** `IdentityKey` falls back to an ephemeral in-memory P-256 key. The account JSON still records the public key, so the app flow is end-to-end testable — you just don't get hardware-backed key isolation until you run on a real device.
- NFC, Bluetooth peer discovery, and camera-based ID capture also don't work on simulator. Those land in later steps.

## Next steps (not in this pass)

- Camera + on-device OCR flow for any government photo ID
- Passport NFC flow (CoreNFC + BAC/PACE)
- BASIC vs Professional claim step
- Local trust graph (vouches + counter-vouches)
- Peer sync over Bluetooth / MultipeerConnectivity
