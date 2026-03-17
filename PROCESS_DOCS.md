# Balloons in the Sky — Sovereign System
## Technical Process Documentation

**Project:** Balloons in the Sky
**Artists:** Bård Ionson & Jennifer Ionson
**License:** CC BY-NC 4.0 (Attribution-NonCommercial)
**Date:** 2026-03-16

---

## Architecture Brainstorm — Session 1

### System Overview

Three-contract "Sovereign System" for a generative AI art installation.

| Contract | Role | Description |
|---|---|---|
| **Deed NFT** | The Soul | Single ERC-721 token (#0). Holder = Installation Owner. |
| **Installation Contract** | The Body + Metabolism | Vault, fund splits, StyleGAN2 machine controls. |
| **Child NFT ("Balloons")** | The Output | Unlimited ERC-721 mints via Crossmint. Royalties enforced. |

---

### Diagram 1 — Contract Relationships & Access Control

```
┌─────────────────────────────────────────────────────┐
│                    DEED NFT                         │
│           ERC-721 · single token #0                 │
│         ownerOf(0) = Installation Owner             │
└──────────────────────┬──────────────────────────────┘
                       │  live ownerOf(0) check
          ┌────────────┴────────────┐
          ▼                         ▼
┌─────────────────────┐   ┌─────────────────────────┐
│  INSTALLATION       │   │  CHILD NFT              │
│  CONTRACT           │   │  "Balloons in the Sky"  │
│                     │   │                         │
│  onlyDeedHolder()   │   │  onlyDeedHolder() admin │
│  onlyArtist()       │   │  onlyMinter() Crossmint │
│  Vault + Splits     │   │  ERC-2981 royalties     │
│  Machine Controls   │   │  8 genetic params       │
└─────────────────────┘   └─────────────────────────┘
          ▲
          │ ETH sent on mint
┌─────────────────────┐
│  CROSSMINT          │
│  (external)         │
└─────────────────────┘
```

---

### Access Control Design Decision — Option A Selected

**Pattern:** Custom Modifier Pattern (no external libraries)

```solidity
modifier onlyArtist()     { require(msg.sender == ARTIST_ADDRESS); }
modifier onlyDeedHolder() { require(msg.sender == IERC721(deed).ownerOf(0)); }
```

**Rationale:** Simplest, most gas-efficient, most auditable. Deed transfer = instant power transfer. No admin sync step required.

**Rejected alternatives:**
- Option B (OZ AccessControl + Deed Hook) — added bytecode complexity, no meaningful benefit
- Option C (Separate Governor Contract) — over-engineered, extra attack surface

---

### Role Summary

**Installation Contract:**

| Role | Set how | Controls |
|---|---|---|
| `ARTIST_ADDRESS` | Immutable at deployment | Artist splits, venue slot, 5% gallery reclaim, machine aesthetics |
| Deed Holder | Live `IERC721(deed).ownerOf(0)` | Collector splits, venue slot, 5% gallery reclaim, vault withdrawals, gallery assignments |

**Child NFT:**

| Role | Controls |
|---|---|
| Deed Holder (live) | Set/revoke minter, update royalty receiver |
| `MINTER_ADDRESS` | Call `mint()` — settable by deed holder |

---

### Revenue Split Schedule

**Pre-sale (artist holds deed):**
- Hash Gallery: 10%
- Vault: 25%
- Artist: 65%

**Post-sale (collector holds deed):**
- Gallery: 10%
- Vault: 45%
- Artist: 45%

**Collector options (post-sale):**
- Add 1 new gallery/venue (% subtracts from collector's 45%)
- Reclaim 5% from gallery's 10% → add to collector share

**Artist options (post-sale):**
- Add 1 new venue (% subtracts from artist's 45%)
- Reclaim 5% from gallery's 10% → add to artist share

---

### 8 Dynamic Genetic Parameters (Child NFT Metadata)

Passed by the StyleGAN2 GPU installation via Crossmint on each mint:

| # | Parameter | Type | Description |
|---|---|---|---|
| 1 | `uniqueName` | string | Name for this balloon |
| 2 | `unitNumber` | uint256 | Sequential unit number |
| 3 | `seed` | uint256 | Scraped from StyleGAN Docker logs |
| 4 | `timestamp` | uint256 | Unix timestamp of generation |
| 5 | `orientation` | uint256 | Image orientation |
| 6 | `truncation` | uint256 | StyleGAN truncation × 100 |
| 7 | `cid` | string | IPFS pointer to image/video |
| 8 | `eventName` | string | e.g., "NFC Lisbon 2026" |

---

*Documentation in progress — architecture approval pending*
