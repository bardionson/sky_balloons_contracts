# Balloons in the Sky — Sovereign System
## Technical Specification v0.1

**Project:** Balloons in the Sky
**Artists:** Bård Ionson & Jennifer Ionson
**License:** CC BY-NC 4.0 (Attribution-NonCommercial)
**Date:** 2026-03-16
**Status:** Architecture Approved — Pending Implementation

---

## 1. System Overview

A three-contract "Sovereign System" for a generative AI art installation. A StyleGAN2 GPU generates balloon imagery; visitors select frames, pay via Crossmint, and receive an NFT. The installation is governed by a single Deed NFT whose holder controls the system.

| Contract | Nickname | Role |
|---|---|---|
| `DeedNFT.sol` | The Soul | Single ERC-721 token. Holder = Installation Owner. |
| `InstallationContract.sol` | The Body | Vault, fund splits, StyleGAN2 machine controls. |
| `BalloonsNFT.sol` | The Output | Unlimited ERC-721 mints via Crossmint. On-chain metadata. |

---

## 2. Contract: DeedNFT.sol

### 2.1 Overview
- ERC-721 with a single token: **Token ID #0**
- No special internal logic — pure transferable ownership token
- Being auctioned; the auction winner becomes the Installation Owner (Collector)
- `ownerOf(0)` is queried live by the other two contracts on every privileged call

### 2.2 Properties
- `name`: "Balloons in the Sky — Deed"
- `symbol`: "BSKY-DEED"
- Max supply: 1
- Minted to artist address at deployment

### 2.3 Metadata
- Token URI stored as a plain IPFS JSON pointer (off-chain metadata file)
- Artist can update at any time via `setTokenURI(string calldata uri) external onlyArtist`
- Metadata JSON on IPFS should include: name, description, image (artwork CID), artist, license

---

## 3. Contract: InstallationContract.sol

### 3.1 Overview
A combined vault and machine controller. Receives ETH from Crossmint mints, allocates it to named buckets at arrival time, and exposes on-chain parameters the StyleGAN2 GPU reads to control visual output.

### 3.2 Access Control

Three roles, resolved at call time (no stored role mapping):

```solidity
modifier onlyArtist() {
    require(msg.sender == ARTIST_ADDRESS);
}

modifier onlyDeedHolder() {
    require(msg.sender == IERC721(deedContract).ownerOf(0));
}

modifier onlyDeedHolderOrOperator() {
    require(
        msg.sender == IERC721(deedContract).ownerOf(0) ||
        msg.sender == exhibitionOperator
    );
}
```

| Role | How resolved | Set |
|---|---|---|
| Artist | Immutable address set at deployment | Deployment |
| Deed Holder | Live `ownerOf(0)` on DeedNFT | Automatic on Deed transfer |
| Exhibition Operator | Stored address, single slot | Deed holder calls `setExhibitionOperator(address)` |

### 3.3 Revenue Split System

#### Buckets
ETH is allocated to named buckets the moment it arrives in `receive()`. Each party withdraws their own balance independently (Pull pattern).

**Pre-sale state** (3 buckets — active while artist holds Deed #0):

| Bucket | Default % | Who controls % |
|---|---|---|
| Gallery | 10% | Artist |
| Endowment | 25% | Artist |
| Artist | Remainder (100% - gallery - endowment) | Automatic |

Artist can freely adjust Gallery % and Endowment % at any time pre-sale. No floor enforced.

**Post-sale state** (up to 5 buckets — active after Deed #0 transfers to Collector):

| Bucket | Default % | Who controls % |
|---|---|---|
| Gallery | 10% | Fixed (adjustable only via reclaim) |
| Endowment | 45% | Locked — Deed holder withdraws |
| Artist | 45% | Locked from Deed holder's view |
| Collector Venue *(optional)* | Set by deed holder | Subtracts from Endowment % |
| Artist Venue *(optional)* | Set by artist | Subtracts from Artist % |

- Deed holder may add **1 venue slot** — % comes from their Endowment share
- Artist may add **1 venue slot** — % comes from their Artist share
- Each party may reclaim **up to 5%** from the Gallery bucket into their own share
- Total always sums to 100%
- State transition (pre → post) is triggered automatically when `ownerOf(0) != ARTIST_ADDRESS`

#### Accounting
```
receive() → msg.value arrives
    gallery.balance    += msg.value * galleryBps / 10000
    endowment.balance  += msg.value * endowmentBps / 10000
    artist.balance     += msg.value * artistBps / 10000
    collectorVenue.balance += msg.value * collectorVenueBps / 10000  // 0 if unset
    artistVenue.balance    += msg.value * artistVenueBps / 10000     // 0 if unset
```

Split changes only affect future incoming ETH. Past allocations are immutable once credited.

#### Withdrawal
```solidity
function withdraw() external  // caller withdraws their own bucket balance
```

### 3.4 Machine Control Parameters

Polled by the StyleGAN2 GPU installation via `eth_call` at a regular interval.

| Parameter | Type | Valid Range | Modifier | Description |
|---|---|---|---|---|
| `truncation` | `int256` (×100) | -200 to 500 | `onlyDeedHolderOrOperator` | StyleGAN2 truncation trick (-2.00 to 5.00) |
| `orientation` | `uint256` | 0 or 1 | `onlyDeedHolderOrOperator` | 0 = Portrait, 1 = Landscape |
| `activeEventName` | `string` | — | `onlyDeedHolder` | Event name stamped on new mints |
| `paused` | `bool` | — | `onlyDeedHolder` | Halts new mints on BalloonsNFT |
| `speed` | `uint256` | 50–1000 | `onlyDeedHolderOrOperator` | Generation/playback speed |
| `interpolation` | `uint256` | 0–4 | `onlyDeedHolderOrOperator` | 0=linear, 1=lerp, 2=slerp, 3=spline, 4=noise |
| `modelSource` | `string` | IPFS CID or any URI | `onlyDeedHolder` | Remote model/checkpoint pointer for GPU pull |

### 3.5 Exhibition Operator
- Single address slot: `exhibitionOperator`
- Granted/revoked by deed holder via `setExhibitionOperator(address)`
- Setting to `address(0)` revokes the role
- Can adjust machine config params (all except `paused`, `activeEventName`, `modelSource`)
- Cannot access financials, splits, or administrative functions

### 3.6 Full Permissions Matrix

| Action | Artist | Deed Holder | Exhibition Operator |
|---|---|---|---|
| Set Gallery % (pre-sale) | ✓ | ✗ | ✗ |
| Set Endowment % (pre-sale) | ✓ | ✗ | ✗ |
| Withdraw artist share | ✓ | ✗ | ✗ |
| Withdraw endowment | ✗ | ✓ | ✗ |
| Add venue slot | ✓ (artist slice) | ✓ (endowment slice) | ✗ |
| Reclaim 5% from gallery | ✓ | ✓ | ✗ |
| `truncation` | ✗ | ✓ | ✓ |
| `orientation` | ✗ | ✓ | ✓ |
| `speed` | ✗ | ✓ | ✓ |
| `interpolation` | ✗ | ✓ | ✓ |
| `activeEventName` | ✗ | ✓ | ✗ |
| `paused` | ✗ | ✓ | ✗ |
| `modelSource` | ✗ | ✓ | ✗ |
| Set exhibition operator | ✗ | ✓ | ✗ |

---

## 4. Contract: BalloonsNFT.sol

### 4.1 Overview
- ERC-721, unlimited supply
- Minted exclusively by Crossmint with 10 genetic parameters
- Metadata assembled entirely on-chain using the Renderer Pattern
- ERC-2981 royalties enforced

### 4.2 Access Control

```solidity
modifier onlyDeedHolder() {
    require(msg.sender == IERC721(deedContract).ownerOf(0));
}

modifier onlyArtist() {
    require(msg.sender == ARTIST_ADDRESS);
}

modifier onlyMinter() {
    require(msg.sender == minterAddress);
}
```

| Role | Controls |
|---|---|
| Deed Holder | Set/revoke minter address |
| Artist | Set royalty rate and receiver |
| Minter (Crossmint) | Call `mint(to, params)` |

### 4.3 Permissions Matrix

| Action | Artist | Deed Holder | Minter |
|---|---|---|---|
| Mint NFT | ✗ | ✗ | ✓ |
| Set minter address | ✗ | ✓ | ✗ |
| Set royalty rate | ✓ | ✗ | ✗ |
| Set royalty receiver | ✓ | ✗ | ✗ |
| Update token image CID | ✓ | ✗ | ✗ |

### 4.4 Royalties
- Standard: ERC-2981
- Default rate: **10%** (1000 basis points)
- Default receiver: `ARTIST_ADDRESS`
- Both rate and receiver are changeable by artist only

### 4.5 Mint Function

```solidity
struct MintParams {
    string  uniqueName;
    uint256 unitNumber;
    uint256 seed;
    string  timestamp;        // pre-formatted: "16/03/2026 14:32 CET"
    uint256 orientation;      // 0 = Portrait, 1 = Landscape
    int256  imagination;      // ×100, range -200 to 500 (-2.00 to 5.00)
    string  cid;              // IPFS URI
    string  eventName;
    string  pieceType;        // e.g. "Artist Proof", "Edition"
    string  pixelDimensions;  // e.g. "1920x1080"
}

function mint(address to, MintParams calldata params) external onlyMinter;
```

### 4.6 Image CID Update

Artist can update the IPFS image CID for any token. All other genetic parameters are immutable once minted.

```solidity
function setTokenCID(uint256 tokenId, string calldata cid) external onlyArtist;
```

Use case: IPFS pin migration, quality upgrade, or swapping a still for a video variant.

### 4.7 On-Chain Metadata (Renderer Pattern)

`tokenURI()` merges hardcoded constants with stored genetic parameters and returns a Base64-encoded JSON string. No external metadata server required.

**Hardcoded constants:**
- Artist: `Bård Ionson & Jennifer Ionson`
- Project: `Balloons in the Sky`
- License: `CC BY-NC 4.0 (Attribution-NonCommercial)`

**Output JSON shape:**
```json
{
  "name": "Balloons in the Sky #42 — [uniqueName]",
  "description": "Balloons in the Sky by Bård Ionson & Jennifer Ionson",
  "image": "ipfs://[cid]",
  "license": "CC BY-NC 4.0",
  "attributes": [
    { "trait_type": "Unit Number",      "value": 42 },
    { "trait_type": "Seed",             "value": 839201 },
    { "trait_type": "Orientation",      "value": "Portrait" },
    { "trait_type": "Imagination",      "value": "0.75" },
    { "trait_type": "Event",            "value": "NFC Lisbon 2026" },
    { "trait_type": "Timestamp",        "value": "16/03/2026 14:32 CET" },
    { "trait_type": "Type",             "value": "Artist Proof" },
    { "trait_type": "Pixel Dimensions", "value": "1920x1080" }
  ]
}
```

**Orientation rendering:** `0` → `"Portrait"`, `1` → `"Landscape"`
**Imagination rendering:** `int256 / 100` formatted as decimal string e.g. `75` → `"0.75"`, `-150` → `"-1.50"`
**Interpolation rendering (machine control only):** `0`→`"linear"`, `1`→`"lerp"`, `2`→`"slerp"`, `3`→`"spline"`, `4`→`"noise"`

---

## 5. Mint Flow (End to End)

```
1. StyleGAN2 GPU generates frame on installation PC
2. Visitor selects frame → presses button
3. Installation uploads JPEG to IPFS → receives CID
4. QR code generated → visitor scans → Crossmint payment page
5. Visitor pays via Crossmint button
6. Crossmint calls BalloonsNFT.mint(visitorWallet, params)
   └─ ETH transferred → InstallationContract.receive()
       └─ Buckets credited at current split %
7. BalloonsNFT stores 10 genetic params on-chain for tokenId
8. tokenURI() returns Base64 JSON → NFT appears in visitor wallet
```

---

## 6. TDD Test Plan

| Test File | Covers |
|---|---|
| `DeedAccess.t.sol` | Only Deed #0 holder can call `onlyDeedHolder` functions. Non-holder reverts. Transfer of Deed transfers control instantly. |
| `VaultRevenue.t.sol` | ETH from mock Crossmint mint reaches InstallationContract. Buckets credited correctly at current split %. Pull withdrawal works per party. |
| `MetadataAssembly.t.sol` | `tokenURI()` returns valid Base64 JSON. All 10 traits present. Orientation renders as string. Imagination renders as float string. |

---

## 7. Tech Stack

- **Solidity** ^0.8.20
- **Foundry / Forge** — build, test, deploy
- **OpenZeppelin** — ERC-721, ERC-2981 base contracts
- **Crossmint** — primary mint interface
- **IPFS** — image/video storage (CID passed at mint time)
- **StyleGAN2** — generative model running on installation GPU

---

## 8. Resolved Decisions

| Item | Decision |
|---|---|
| Deployment network | Ethereum Mainnet |
| Deed auction | Off-chain via Verse Works (verse.works) — Hash Gallery's platform. No auction contract required. Deed is standard transferable ERC-721. |
| Royalty receiver | Artist's personal wallet (set at deployment, updatable by artist via `setRoyalty()`) |
| Gallery wallet address | Deployment parameter — supplied by Hash Gallery before mainnet deploy. Test wallet used for local/Foundry testing. |
| Crossmint API validation | Validate `MintParams` struct against Crossmint Custom Contract Minting API at implementation start using `crossmint-docs` MCP server. |
| GPU polling interval | Every 15–30 minutes. Machine parameters are set-and-forget. GPU polls via `eth_call` on a slow interval. |

---

*Specification drafted: 2026-03-16*
*Architecture approved by artist prior to implementation*
