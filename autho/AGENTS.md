<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->


# BLACKOUT — Viral Trust

**Event:** GDGC UDA Hackathon 2026 (GRIDAKL)
**Team:** Red Pandas

## The Premise
At 3:47 am on Tuesday, a solar flare struck Earth, instantaneously corrupting every digital record globally. The physical infrastructure — lights, internet, roads, hospitals — remains entirely intact. However, the data that gives it meaning has vanished.

Accounts, property titles, medical records, and access credentials no longer exist. Banks, courts, and institutions are frozen.

## The Imminent Crisis
London (population 9 million) is currently T+14 hours post-flare. The city is temporarily running on "momentum" — people going to work and operating out of pure habit. But within the next 28 hours, this momentum will fail as urgent questions arise: *Who owns what? Who has the right to decide? How do you prove who you are?*

The most urgent of these: **how do you know the stranger claiming to be a surgeon really is one?**

---

## Our Solution: Viral Trust

Centralized credentialing is dead. We replace it with a **peer-to-peer web of trust** that spreads virally between people, requires no servers, and grows stronger as it grows wider.

The core idea: **trust is contagious, but only along chains of already-trusted people.** One person who is trusted by their neighbors can extend that trust to a doctor; that doctor can extend it to other medical professionals; those professionals' competence vouches now carry weight for everyone downstream of the original community.

### Core Principles

1. **Viral, peer-to-peer** — Trust spreads person-to-person, with no central authority. There is no registry, no certifying body, no "official" list. Every vouch is a person staking their own reputation on someone else's.

2. **Additive-only, never destructive** — No vouch can ever be deleted or edited. Mistakes and bad actors are corrected by *appending* counter-vouches (negative signals from trusted sources), not by erasing history. The full record is always preserved; the score reflects the latest aggregate.

3. **Decentralized storage** — Each person's vouches live on their own device. When two devices meet (Bluetooth, local mesh, NFC), they sync the slice of the trust graph relevant to both. No server, no internet required. The graph rebuilds itself from the bottom up.

4. **Inherent trust, earned by being trusted** — Every medical, legal, government, or otherwise safety-critical professional starts at a baseline trust score. That score *only* rises when they are vouched for by people who themselves are trusted. Trust begets trust.

---

## How It Works

### Bootstrap: Web-of-Trust Seeding
There are no anointed authorities. Trust emerges from the bottom up:

- People vouch for each other in person — your neighbor knows you, you know your neighbor, you both append a vouch on each other's devices.
- As more vouchers vouch for the same person, that person's score rises.
- Clusters of mutual trust form naturally around streets, workplaces, hospitals, congregations.
- Eventually, clusters interconnect via people who belong to multiple clusters, and the global graph emerges.

### Trust Math: Weighted *and* Diverse

A professional's score increases according to **two** factors:

- **Weight** — A vouch from a high-trust person raises the recipient's score more than a vouch from a low-trust person. Trust compounds: being trusted by the trusted matters most.
- **Diversity** — Many independent vouches from *different social clusters* count more than the same number of vouches from one tight-knit group. This makes collusion expensive: a single clique cannot manufacture trust on its own; it has to convince the rest of the world.

Together, weight and diversity make the graph robust against both lone bad actors and coordinated attacks.

### Domain-Specific Trust
Trust is **per-domain**. A doctor vouching for another doctor on *medical competence* carries far more weight than a lawyer vouching for that same doctor's medical skills. The lawyer's vouch still counts — but for general character, not technical competence.

Domains include (at minimum):
- **Medical** — doctors, nurses, paramedics, pharmacists
- **Legal** — lawyers, judges, arbitrators
- **Government** — elected representatives, civil servants, regulators
- **Other critical skills** — engineers, pilots, teachers, electricians, anyone whose claimed competence affects others' safety

Each person carries a vector of domain scores, not a single number.

### Handling Bad Actors: Counter-Vouches
Since the ledger is additive-only, mistakes and fraud are handled by **appending negative signals**:

- If you vouched for someone who turned out to be a fraud, you (or anyone else) can append a counter-vouch.
- A counter-vouch from a high-trust source heavily reduces the target's score.
- The original vouch is *never deleted* — the history of who trusted whom, and when, remains permanently auditable.
- This creates strong incentives for careful vouching: your reputation is on the line every time you stake it on someone else.

### Consumption: Score *and* Path

When you encounter a professional and need to decide whether to trust them, your device shows you **two things**:

1. **An aggregate score** in the relevant domain — quick, glanceable, useful for low-stakes decisions.
2. **The trust path** — the shortest chain of vouches from someone *you* trust to *them*. e.g.: *"Trusted by Maria (your neighbor) → who is trusted by Dr. Chen → who vouches for this surgeon's medical competence."*

The score is for speed. The path is for the moments that matter — before surgery, before signing, before voting.

---

## Why It Works

- **No central point of failure** — There is no server to attack, no database to corrupt, no authority to capture. The trust graph survives as long as people and their devices survive.
- **Resilient to the next blackout** — The same architecture that rebuilds society after this solar flare would survive the next one too. Every device is a partial backup of humanity's reputation graph.
- **Aligned incentives** — Every vouch puts the voucher's own reputation at stake. Sloppy or fraudulent vouching is self-punishing.
- **Naturally viral** — The system rewards interconnection. The more people you vouch for and are vouched for by, the more useful your slice of the graph becomes to everyone else.

---

## Problems Addressed

From the hackathon brief, this directly addresses:

- **Identity without records** — Your identity *is* your position in the trust graph.
- **Credentials without verification** — Professional competence is established by domain-specific peer vouches.
- **Trust without authority** — Communities enforce agreements through who they collectively vouch for.
- **Information without truth** — Information from high-trust sources can be weighted above rumor.

And lays groundwork for the rest: ownership, exchange, governance, and coordination all become tractable once you can answer *"who is this person, and who trusts them?"*
