# Sovereign System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and test three Solidity contracts — DeedNFT, InstallationContract, BalloonsNFT — forming a sovereign generative AI art installation system on Ethereum Mainnet.

**Architecture:** A single ERC-721 Deed token (ID #0) governs the system via live `ownerOf(0)` checks. The Installation Contract holds a revenue vault with dynamic split buckets and exposes on-chain machine control parameters for the StyleGAN2 GPU (including a `paused` flag that BalloonsNFT reads). The Balloons NFT mints unlimited ERC-721 tokens via Crossmint with 10 genetic parameters assembled into Base64 JSON on-chain.

**Tech Stack:** Solidity ^0.8.20, Foundry/Forge, OpenZeppelin (ERC-721, ERC-2981, Base64, Strings), Crossmint Custom Contract Minting API

**Reference:** `SPEC.md` — full architecture spec and decisions.

**Skills:** @foundry-solidity for gas optimization and Foundry patterns. Use `crossmint-docs` MCP server to validate `MintParams` before writing mint tests (Task 6).

---

## Chunk 1: Project Setup

### Task 1: Initialize Foundry Project

**Files:**
- Create: `foundry.toml`
- Create: `src/`, `test/`, `script/` directories

- [ ] **Step 1: Initialize Foundry in project directory**

```bash
cd /home/bardionson/sky_balloons_contracts
forge init --no-git --force
```

Expected: creates `src/`, `test/`, `script/`, `foundry.toml`, `lib/`

- [ ] **Step 2: Remove Foundry boilerplate**

```bash
rm src/Counter.sol test/Counter.t.sol script/Counter.s.sol
```

- [ ] **Step 3: Install OpenZeppelin contracts**

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-git
```

Expected: `lib/openzeppelin-contracts/` created

- [ ] **Step 4: Configure foundry.toml**

Replace contents of `foundry.toml` with:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.20"
optimizer = true
optimizer_runs = 200
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
]

[profile.default.fuzz]
runs = 256
```

- [ ] **Step 5: Verify build is clean**

```bash
forge build
```

Expected: `Compiler run successful` with no errors

- [ ] **Step 6: Initialize git and commit**

```bash
cd /home/bardionson/sky_balloons_contracts
git init
git add foundry.toml lib/ SPEC.md PROCESS_DOCS.md docs/
git commit -m "chore: initialize Foundry project with OpenZeppelin"
```

---

## Chunk 2: DeedNFT

### Task 2: DeedNFT — Failing Tests

**Files:**
- Create: `test/DeedAccess.t.sol`

- [ ] **Step 1: Write failing tests for DeedNFT**

Create `test/DeedAccess.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeedNFT.sol";

contract DeedAccessTest is Test {
    DeedNFT public deed;

    address public artist    = makeAddr("artist");
    address public collector = makeAddr("collector");
    address public stranger  = makeAddr("stranger");

    function setUp() public {
        vm.prank(artist);
        deed = new DeedNFT(artist, "ipfs://initial-metadata-cid");
    }

    // --- Ownership ---

    function test_artistHoldsTokenZeroAfterDeploy() public view {
        assertEq(deed.ownerOf(0), artist);
    }

    function test_artistAddressIsImmutable() public view {
        assertEq(deed.ARTIST(), artist);
    }

    // --- Token URI ---

    function test_tokenURIReturnsInitialValue() public view {
        assertEq(deed.tokenURI(0), "ipfs://initial-metadata-cid");
    }

    function test_artistCanUpdateTokenURI() public {
        vm.prank(artist);
        deed.setTokenURI("ipfs://updated-cid");
        assertEq(deed.tokenURI(0), "ipfs://updated-cid");
    }

    function test_strangerCannotUpdateTokenURI() public {
        vm.prank(stranger);
        vm.expectRevert();
        deed.setTokenURI("ipfs://hacked");
    }

    function test_collectorCannotUpdateTokenURIAfterTransfer() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
        vm.prank(collector);
        vm.expectRevert();
        deed.setTokenURI("ipfs://collector-override");
    }

    // --- Transfer & Sovereignty ---

    function test_deedTransferChangesOwner() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
        assertEq(deed.ownerOf(0), collector);
    }

    function test_tokenURIRevertsForNonexistentToken() public {
        vm.expectRevert();
        deed.tokenURI(1); // only token 0 exists
    }
}
```

- [ ] **Step 2: Run tests — confirm they all fail (contract does not exist)**

```bash
forge test --match-path test/DeedAccess.t.sol -v
```

Expected: `FAIL` — `DeedNFT` not found

### Task 3: DeedNFT — Implementation

**Files:**
- Create: `src/DeedNFT.sol`

- [ ] **Step 1: Implement DeedNFT**

Create `src/DeedNFT.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title DeedNFT
/// @notice Single-token ERC-721. Token #0 holder governs the installation.
///         Transferring this token transfers all sovereign control instantly.
///         ARTIST address is immutable — artist retains URI control forever.
contract DeedNFT is ERC721 {
    address public immutable ARTIST;
    string private _uri;

    modifier onlyArtist() {
        require(msg.sender == ARTIST, "DeedNFT: not artist");
        _;
    }

    constructor(address artist, string memory uri)
        ERC721("Balloons in the Sky \u2014 Deed", "BSKY-DEED")
    {
        ARTIST = artist;
        _uri = uri;
        _mint(artist, 0);
    }

    /// @notice Returns the metadata URI for token #0.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _uri;
    }

    /// @notice Artist can update the IPFS metadata URI at any time.
    function setTokenURI(string calldata uri) external onlyArtist {
        _uri = uri;
    }
}
```

- [ ] **Step 2: Run tests — confirm all pass**

```bash
forge test --match-path test/DeedAccess.t.sol -v
```

Expected: All tests `PASS`

- [ ] **Step 3: Commit**

```bash
git add src/DeedNFT.sol test/DeedAccess.t.sol
git commit -m "feat: DeedNFT single-token ERC-721 with artist-controlled URI"
```

---

## Chunk 3: InstallationContract — Vault & Splits

### Task 4: VaultRevenue — Failing Tests

**Files:**
- Create: `test/VaultRevenue.t.sol`

- [ ] **Step 1: Write failing vault and split tests**

Create `test/VaultRevenue.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeedNFT.sol";
import "../src/InstallationContract.sol";

contract VaultRevenueTest is Test {
    DeedNFT             public deed;
    InstallationContract public installation;

    address public artist    = makeAddr("artist");
    address public collector = makeAddr("collector");
    address public gallery   = makeAddr("gallery");
    address public venue1    = makeAddr("venue1");
    address public venue2    = makeAddr("venue2");

    // Pre-sale defaults: gallery=10%, endowment=25%
    uint256 constant PRE_GALLERY_BPS   = 1000;
    uint256 constant PRE_ENDOWMENT_BPS = 2500;

    // Post-sale defaults: gallery=10%, endowment=45%, artist=45%
    uint256 constant POST_GALLERY_BPS   = 1000;
    uint256 constant POST_ENDOWMENT_BPS = 4500;
    uint256 constant POST_ARTIST_BPS    = 4500;

    function setUp() public {
        vm.prank(artist);
        deed = new DeedNFT(artist, "ipfs://deed");

        installation = new InstallationContract(
            address(deed),
            artist,
            gallery,
            PRE_GALLERY_BPS,
            PRE_ENDOWMENT_BPS
        );
    }

    // -------------------------------------------------------------------------
    // Pre-sale: ETH arrives, buckets credited correctly
    // -------------------------------------------------------------------------

    function test_ethCreditedToBucketsOnReceivePreSale() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);

        uint256 expectedGallery          = 1 ether * PRE_GALLERY_BPS / 10000;
        uint256 expectedArtistEndowment  = 1 ether * PRE_ENDOWMENT_BPS / 10000;
        // Pre-sale: endowment credited to artist (deed holder = artist)
        // Artist bucket = artistCut + endowmentCut
        uint256 expectedArtistTotal = 1 ether - expectedGallery;

        assertEq(installation.balances(gallery), expectedGallery);
        assertEq(installation.balances(artist),  expectedArtistTotal);
        // Endowment is folded into artist balance pre-sale (same address)
        _ = expectedArtistEndowment; // used to show intent in test naming
    }

    function test_splitChangesOnlyAffectFutureEth() public {
        // First mint at 10% gallery
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);
        uint256 galleryAfterFirst = installation.balances(gallery);

        // Artist changes gallery to 20%
        vm.prank(artist);
        installation.setPreSaleGalleryBps(2000);

        // Second mint — new split applies
        vm.deal(address(this), 1 ether);
        (bool ok2,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok2);

        uint256 galleryAfterSecond = installation.balances(gallery);
        // Second ETH credits 20%, total should be 10% + 20% = 30% of 2 ETH
        assertEq(galleryAfterFirst, 0.1 ether);
        assertEq(galleryAfterSecond - galleryAfterFirst, 0.2 ether);
    }

    // -------------------------------------------------------------------------
    // Pull withdrawal
    // -------------------------------------------------------------------------

    function test_pullWithdrawal() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);

        uint256 balanceBefore = artist.balance;
        vm.prank(artist);
        installation.withdraw();
        assertGt(artist.balance, balanceBefore);
        assertEq(installation.balances(artist), 0);
    }

    function test_withdrawRevertsWithZeroBalance() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.withdraw();
    }

    function test_galleryCanWithdrawItsShare() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);

        uint256 before = gallery.balance;
        vm.prank(gallery);
        installation.withdraw();
        assertEq(gallery.balance - before, 0.1 ether);
    }

    // -------------------------------------------------------------------------
    // Pre-sale: artist controls splits
    // -------------------------------------------------------------------------

    function test_artistCanSetGalleryBpsPreSale() public {
        vm.prank(artist);
        installation.setPreSaleGalleryBps(1500);
        assertEq(installation.preSaleGalleryBps(), 1500);
    }

    function test_artistCanSetEndowmentBpsPreSale() public {
        vm.prank(artist);
        installation.setPreSaleEndowmentBps(3000);
        assertEq(installation.preSaleEndowmentBps(), 3000);
    }

    function test_strangerCannotSetSplitsPreSale() public {
        vm.prank(collector);
        vm.expectRevert();
        installation.setPreSaleGalleryBps(2000);
    }

    function test_artistCanSetGalleryToZero() public {
        vm.prank(artist);
        installation.setPreSaleGalleryBps(0);
        assertEq(installation.preSaleGalleryBps(), 0);
    }

    // -------------------------------------------------------------------------
    // Post-sale: splits flip automatically on deed transfer
    // -------------------------------------------------------------------------

    function test_isPreSaleReturnsTrueWhileArtistHoldsDeed() public view {
        assertTrue(installation.isPreSale());
    }

    function test_isPreSaleReturnsFalseAfterDeedTransfer() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
        assertFalse(installation.isPreSale());
    }

    function test_splitsFlipAutomaticallyOnDeedTransfer() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);

        assertEq(installation.balances(gallery),   1 ether * POST_GALLERY_BPS / 10000);
        assertEq(installation.balances(collector), 1 ether * POST_ENDOWMENT_BPS / 10000);
        assertEq(installation.balances(artist),    1 ether * POST_ARTIST_BPS / 10000);
    }

    function test_artistCannotChangeSplitsPostSale() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
        vm.prank(artist);
        vm.expectRevert();
        installation.setPreSaleGalleryBps(500);
    }

    // -------------------------------------------------------------------------
    // Post-sale: venue slots
    // -------------------------------------------------------------------------

    function test_deedHolderCanAddCollectorVenue() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(collector);
        installation.setCollectorVenue(venue1, 500);

        assertEq(installation.collectorVenueBps(),    500);
        assertEq(installation.postSaleEndowmentBps(), POST_ENDOWMENT_BPS - 500);
    }

    function test_artistCanAddArtistVenue() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(artist);
        installation.setArtistVenue(venue2, 500);

        assertEq(installation.artistVenueBps(),    500);
        assertEq(installation.postSaleArtistBps(), POST_ARTIST_BPS - 500);
    }

    function test_venueSlotCreditedCorrectlyOnReceive() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
        vm.prank(collector);
        installation.setCollectorVenue(venue1, 500);

        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);

        assertEq(installation.balances(venue1), 1 ether * 500 / 10000);
    }

    function test_deedHolderCannotAddVenuePreSale() public {
        // artist holds deed — still pre-sale
        vm.prank(artist);
        vm.expectRevert();
        installation.setCollectorVenue(venue1, 500);
    }

    // -------------------------------------------------------------------------
    // Post-sale: gallery reclaim (5% cap PER PARTY, cumulative)
    // -------------------------------------------------------------------------

    function test_artistCanReclaimFivePercentFromGallery() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(artist);
        installation.reclaimFromGallery(500);

        assertEq(installation.postSaleGalleryBps(),  POST_GALLERY_BPS - 500);
        assertEq(installation.postSaleArtistBps(),   POST_ARTIST_BPS + 500);
    }

    function test_deedHolderCanReclaimFivePercentFromGallery() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(collector);
        installation.reclaimFromGallery(500);

        assertEq(installation.postSaleGalleryBps(),   POST_GALLERY_BPS - 500);
        assertEq(installation.postSaleEndowmentBps(), POST_ENDOWMENT_BPS + 500);
    }

    function test_cannotReclaimMoreThanFivePercentInSingleCall() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(artist);
        vm.expectRevert();
        installation.reclaimFromGallery(600);
    }

    function test_cannotReclaimCumulativelyMoreThanFivePercent() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        // First reclaim: 300 bps
        vm.prank(artist);
        installation.reclaimFromGallery(300);

        // Second reclaim: 200 more = total 500, allowed
        vm.prank(artist);
        installation.reclaimFromGallery(200);

        // Third reclaim: 1 more = total 501, should revert
        vm.prank(artist);
        vm.expectRevert();
        installation.reclaimFromGallery(1);
    }

    function test_strangerCannotReclaimFromGallery() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        installation.reclaimFromGallery(500);
    }

    // -------------------------------------------------------------------------
    // Total always sums to 10000
    // -------------------------------------------------------------------------

    function test_splitsAlwaysSumToTenThousand() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(collector);
        installation.setCollectorVenue(venue1, 300);
        vm.prank(artist);
        installation.setArtistVenue(venue2, 200);
        vm.prank(artist);
        installation.reclaimFromGallery(500);

        uint256 total = installation.postSaleGalleryBps()
            + installation.postSaleEndowmentBps()
            + installation.postSaleArtistBps()
            + installation.collectorVenueBps()
            + installation.artistVenueBps();

        assertEq(total, 10000);
    }
}
```

- [ ] **Step 2: Run tests — confirm all fail**

```bash
forge test --match-path test/VaultRevenue.t.sol -v
```

Expected: `FAIL` — `InstallationContract` not found

### Task 5: InstallationContract — Implementation

**Files:**
- Create: `src/InstallationContract.sol`

- [ ] **Step 1: Implement InstallationContract**

Create `src/InstallationContract.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title InstallationContract
/// @notice Vault, revenue splits, and StyleGAN2 machine controls for the
///         "Balloons in the Sky" installation. Revenue is allocated into named
///         buckets the moment ETH arrives; each party pulls their own balance.
///
/// @dev Two operating states:
///      PRE-SALE:  artist holds Deed #0. Artist controls all split %.
///                 3 buckets: Gallery, Endowment (→ artist), Artist.
///      POST-SALE: collector holds Deed #0. Splits locked at 10/45/45.
///                 Up to 5 buckets. Each party can add 1 venue slot
///                 and reclaim up to 5% cumulatively from Gallery.
contract InstallationContract {

    // -------------------------------------------------------------------------
    // Immutables
    // -------------------------------------------------------------------------

    address public immutable ARTIST;
    IERC721 public immutable deedContract;

    // -------------------------------------------------------------------------
    // Bucket addresses
    // -------------------------------------------------------------------------

    address public galleryAddress;
    address public collectorVenueAddress;
    address public artistVenueAddress;

    // -------------------------------------------------------------------------
    // Pre-sale split BPS (artist-controlled, used only while isPreSale())
    // -------------------------------------------------------------------------

    uint256 public preSaleGalleryBps;
    uint256 public preSaleEndowmentBps;
    // preSaleArtistBps = 10000 - preSaleGalleryBps - preSaleEndowmentBps (implicit)

    // -------------------------------------------------------------------------
    // Post-sale split BPS (locked at deployment values; adjustable only via
    // venue slots and gallery reclaim)
    // -------------------------------------------------------------------------

    uint256 public postSaleGalleryBps   = 1000; // 10%
    uint256 public postSaleEndowmentBps = 4500; // 45%
    uint256 public postSaleArtistBps    = 4500; // 45%
    uint256 public collectorVenueBps;
    uint256 public artistVenueBps;

    // Per-party cumulative gallery reclaim tracking (max 500 bps each)
    uint256 public artistReclaimedBps;
    uint256 public collectorReclaimedBps;

    // -------------------------------------------------------------------------
    // Balances (Pull pattern)
    // -------------------------------------------------------------------------

    mapping(address => uint256) public balances;

    // -------------------------------------------------------------------------
    // Exhibition Operator
    // -------------------------------------------------------------------------

    address public exhibitionOperator;

    // -------------------------------------------------------------------------
    // Machine Control Parameters
    // -------------------------------------------------------------------------

    int256  public truncation;          // ×100, range -200 to 500 (-2.00 to 5.00)
    uint256 public orientation;         // 0=Portrait, 1=Landscape
    string  public activeEventName;
    bool    public paused;              // halts mints on BalloonsNFT
    uint256 public speed = 525;         // range 50–1000 (midpoint default)
    uint256 public interpolation;       // 0=linear,1=lerp,2=slerp,3=spline,4=noise
    string  public modelSource;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyArtist() {
        require(msg.sender == ARTIST, "IC: not artist");
        _;
    }

    modifier onlyDeedHolder() {
        require(msg.sender == deedContract.ownerOf(0), "IC: not deed holder");
        _;
    }

    modifier onlyDeedHolderOrOperator() {
        require(
            msg.sender == deedContract.ownerOf(0) ||
            msg.sender == exhibitionOperator,
            "IC: not deed holder or operator"
        );
        _;
    }

    modifier onlyPreSale() {
        require(isPreSale(), "IC: not pre-sale");
        _;
    }

    modifier onlyPostSale() {
        require(!isPreSale(), "IC: not post-sale");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        address _deed,
        address _artist,
        address _gallery,
        uint256 _galleryBps,
        uint256 _endowmentBps
    ) {
        deedContract        = IERC721(_deed);
        ARTIST              = _artist;
        galleryAddress      = _gallery;
        preSaleGalleryBps   = _galleryBps;
        preSaleEndowmentBps = _endowmentBps;
    }

    // -------------------------------------------------------------------------
    // State helper
    // -------------------------------------------------------------------------

    function isPreSale() public view returns (bool) {
        return deedContract.ownerOf(0) == ARTIST;
    }

    // -------------------------------------------------------------------------
    // Vault: receive and allocate
    // -------------------------------------------------------------------------

    receive() external payable {
        if (isPreSale()) {
            _allocatePreSale(msg.value);
        } else {
            _allocatePostSale(msg.value);
        }
    }

    function _allocatePreSale(uint256 amount) internal {
        uint256 galleryCut   = amount * preSaleGalleryBps / 10000;
        uint256 endowmentCut = amount * preSaleEndowmentBps / 10000;
        uint256 artistCut    = amount - galleryCut - endowmentCut;
        // Pre-sale: deed holder == ARTIST, so endowment accrues to artist address
        balances[galleryAddress]          += galleryCut;
        balances[ARTIST]                  += endowmentCut + artistCut;
    }

    function _allocatePostSale(uint256 amount) internal {
        address deedHolder = deedContract.ownerOf(0);

        uint256 galleryCut        = amount * postSaleGalleryBps / 10000;
        uint256 endowmentCut      = amount * postSaleEndowmentBps / 10000;
        uint256 artistCut         = amount * postSaleArtistBps / 10000;
        uint256 collectorVenueCut = amount * collectorVenueBps / 10000;
        uint256 artistVenueCut    = amount * artistVenueBps / 10000;

        balances[galleryAddress]  += galleryCut;
        balances[deedHolder]      += endowmentCut;
        balances[ARTIST]          += artistCut;

        if (collectorVenueAddress != address(0))
            balances[collectorVenueAddress] += collectorVenueCut;
        if (artistVenueAddress != address(0))
            balances[artistVenueAddress]    += artistVenueCut;
    }

    // -------------------------------------------------------------------------
    // Vault: withdraw
    // -------------------------------------------------------------------------

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "IC: nothing to withdraw");
        balances[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "IC: transfer failed");
    }

    // -------------------------------------------------------------------------
    // Pre-sale split setters (artist only)
    // -------------------------------------------------------------------------

    function setPreSaleGalleryBps(uint256 bps) external onlyArtist onlyPreSale {
        preSaleGalleryBps = bps;
    }

    function setPreSaleEndowmentBps(uint256 bps) external onlyArtist onlyPreSale {
        preSaleEndowmentBps = bps;
    }

    // -------------------------------------------------------------------------
    // Post-sale venue slots
    // -------------------------------------------------------------------------

    function setCollectorVenue(address venue, uint256 bps)
        external onlyDeedHolder onlyPostSale
    {
        require(bps <= postSaleEndowmentBps, "IC: exceeds endowment share");
        if (collectorVenueAddress != address(0)) {
            postSaleEndowmentBps += collectorVenueBps; // return old allocation
        }
        collectorVenueAddress = venue;
        collectorVenueBps     = bps;
        postSaleEndowmentBps  -= bps;
    }

    function setArtistVenue(address venue, uint256 bps)
        external onlyArtist onlyPostSale
    {
        require(bps <= postSaleArtistBps, "IC: exceeds artist share");
        if (artistVenueAddress != address(0)) {
            postSaleArtistBps += artistVenueBps; // return old allocation
        }
        artistVenueAddress = venue;
        artistVenueBps     = bps;
        postSaleArtistBps  -= bps;
    }

    // -------------------------------------------------------------------------
    // Gallery reclaim (5% max cumulative per party, post-sale only)
    // -------------------------------------------------------------------------

    function reclaimFromGallery(uint256 bps) external onlyPostSale {
        require(bps <= 500, "IC: max 5% per call");
        require(postSaleGalleryBps >= bps, "IC: insufficient gallery %");

        bool isDeedHolder   = msg.sender == deedContract.ownerOf(0);
        bool isArtistCaller = msg.sender == ARTIST;
        require(isDeedHolder || isArtistCaller, "IC: not authorized");

        if (isArtistCaller) {
            require(artistReclaimedBps + bps <= 500, "IC: artist reclaim cap exceeded");
            artistReclaimedBps  += bps;
            postSaleGalleryBps  -= bps;
            postSaleArtistBps   += bps;
        } else {
            require(collectorReclaimedBps + bps <= 500, "IC: collector reclaim cap exceeded");
            collectorReclaimedBps += bps;
            postSaleGalleryBps    -= bps;
            postSaleEndowmentBps  += bps;
        }
    }

    // -------------------------------------------------------------------------
    // Exhibition Operator
    // -------------------------------------------------------------------------

    function setExhibitionOperator(address operator) external onlyDeedHolder {
        exhibitionOperator = operator;
    }

    // -------------------------------------------------------------------------
    // Machine Controls
    // -------------------------------------------------------------------------

    function setTruncation(int256 val) external onlyDeedHolderOrOperator {
        require(val >= -200 && val <= 500, "IC: truncation out of range");
        truncation = val;
    }

    function setOrientation(uint256 val) external onlyDeedHolderOrOperator {
        require(val <= 1, "IC: orientation must be 0 or 1");
        orientation = val;
    }

    function setSpeed(uint256 val) external onlyDeedHolderOrOperator {
        require(val >= 50 && val <= 1000, "IC: speed out of range");
        speed = val;
    }

    function setInterpolation(uint256 val) external onlyDeedHolderOrOperator {
        require(val <= 4, "IC: interpolation must be 0-4");
        interpolation = val;
    }

    function setActiveEventName(string calldata name) external onlyDeedHolder {
        activeEventName = name;
    }

    function setPaused(bool val) external onlyDeedHolder {
        paused = val;
    }

    function setModelSource(string calldata src) external onlyDeedHolder {
        modelSource = src;
    }
}
```

- [ ] **Step 2: Run vault tests — all pass**

```bash
forge test --match-path test/VaultRevenue.t.sol -v
```

Expected: All tests `PASS`

- [ ] **Step 3: Commit**

```bash
git add src/InstallationContract.sol test/VaultRevenue.t.sol
git commit -m "feat: InstallationContract vault, splits, machine controls"
```

---

## Chunk 4: InstallationContract — Machine Controls & Operator

### Task 6: Machine Controls — Failing Tests

**Files:**
- Create: `test/MachineControls.t.sol`

- [ ] **Step 1: Write failing machine controls and operator tests**

Create `test/MachineControls.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeedNFT.sol";
import "../src/InstallationContract.sol";

contract MachineControlsTest is Test {
    DeedNFT             public deed;
    InstallationContract public installation;

    address public artist    = makeAddr("artist");
    address public collector = makeAddr("collector");
    address public operator  = makeAddr("operator");
    address public stranger  = makeAddr("stranger");

    function setUp() public {
        vm.prank(artist);
        deed = new DeedNFT(artist, "ipfs://deed");
        installation = new InstallationContract(
            address(deed), artist, makeAddr("gallery"), 1000, 2500
        );
    }

    // -------------------------------------------------------------------------
    // Exhibition Operator management
    // -------------------------------------------------------------------------

    function test_deedHolderCanSetExhibitionOperator() public {
        vm.prank(artist); // artist holds deed
        installation.setExhibitionOperator(operator);
        assertEq(installation.exhibitionOperator(), operator);
    }

    function test_strangerCannotSetExhibitionOperator() public {
        vm.prank(stranger);
        vm.expectRevert();
        installation.setExhibitionOperator(operator);
    }

    function test_artistCannotSetExhibitionOperator() public {
        // Transfer deed to collector so artist is no longer deed holder
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);

        vm.prank(artist);
        vm.expectRevert();
        installation.setExhibitionOperator(operator);
    }

    function test_settingOperatorToZeroRevokesRole() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(artist);
        installation.setExhibitionOperator(address(0));
        assertEq(installation.exhibitionOperator(), address(0));
    }

    // -------------------------------------------------------------------------
    // onlyDeedHolderOrOperator functions
    // -------------------------------------------------------------------------

    function test_deedHolderCanSetTruncation() public {
        vm.prank(artist);
        installation.setTruncation(350);
        assertEq(installation.truncation(), 350);
    }

    function test_operatorCanSetTruncation() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        installation.setTruncation(-150);
        assertEq(installation.truncation(), -150);
    }

    function test_strangerCannotSetTruncation() public {
        vm.prank(stranger);
        vm.expectRevert();
        installation.setTruncation(100);
    }

    function test_truncationRejectsValueAbove500() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.setTruncation(501);
    }

    function test_truncationRejectsValueBelow200Negative() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.setTruncation(-201);
    }

    function test_truncationAcceptsBoundaryValues() public {
        vm.prank(artist);
        installation.setTruncation(-200);
        assertEq(installation.truncation(), -200);

        vm.prank(artist);
        installation.setTruncation(500);
        assertEq(installation.truncation(), 500);
    }

    function test_deedHolderCanSetOrientation() public {
        vm.prank(artist);
        installation.setOrientation(1);
        assertEq(installation.orientation(), 1);
    }

    function test_orientationRejectsInvalidValue() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.setOrientation(2);
    }

    function test_operatorCanSetOrientation() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        installation.setOrientation(1);
        assertEq(installation.orientation(), 1);
    }

    function test_deedHolderCanSetSpeed() public {
        vm.prank(artist);
        installation.setSpeed(800);
        assertEq(installation.speed(), 800);
    }

    function test_speedRejectsValueBelow50() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.setSpeed(49);
    }

    function test_speedRejectsValueAbove1000() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.setSpeed(1001);
    }

    function test_operatorCanSetSpeed() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        installation.setSpeed(200);
        assertEq(installation.speed(), 200);
    }

    function test_deedHolderCanSetInterpolation() public {
        vm.prank(artist);
        installation.setInterpolation(2); // slerp
        assertEq(installation.interpolation(), 2);
    }

    function test_interpolationRejectsValueAbove4() public {
        vm.prank(artist);
        vm.expectRevert();
        installation.setInterpolation(5);
    }

    function test_operatorCanSetInterpolation() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        installation.setInterpolation(4); // noise
        assertEq(installation.interpolation(), 4);
    }

    // -------------------------------------------------------------------------
    // onlyDeedHolder-only machine controls (operator cannot access)
    // -------------------------------------------------------------------------

    function test_deedHolderCanSetActiveEventName() public {
        vm.prank(artist);
        installation.setActiveEventName("NFC Lisbon 2026");
        assertEq(installation.activeEventName(), "NFC Lisbon 2026");
    }

    function test_operatorCannotSetActiveEventName() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        vm.expectRevert();
        installation.setActiveEventName("hacked event");
    }

    function test_strangerCannotSetActiveEventName() public {
        vm.prank(stranger);
        vm.expectRevert();
        installation.setActiveEventName("hacked event");
    }

    function test_deedHolderCanSetPaused() public {
        vm.prank(artist);
        installation.setPaused(true);
        assertTrue(installation.paused());
        vm.prank(artist);
        installation.setPaused(false);
        assertFalse(installation.paused());
    }

    function test_operatorCannotSetPaused() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        vm.expectRevert();
        installation.setPaused(true);
    }

    function test_deedHolderCanSetModelSource() public {
        vm.prank(artist);
        installation.setModelSource("ipfs://QmModelCID");
        assertEq(installation.modelSource(), "ipfs://QmModelCID");
    }

    function test_operatorCannotSetModelSource() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        vm.expectRevert();
        installation.setModelSource("https://evil.com/model");
    }

    // -------------------------------------------------------------------------
    // Operator loses access after revocation
    // -------------------------------------------------------------------------

    function test_revokedOperatorCannotCallMachineControls() public {
        vm.prank(artist);
        installation.setExhibitionOperator(operator);

        // Operator works
        vm.prank(operator);
        installation.setSpeed(300);

        // Deed holder revokes operator
        vm.prank(artist);
        installation.setExhibitionOperator(address(0));

        // Operator now reverts
        vm.prank(operator);
        vm.expectRevert();
        installation.setSpeed(400);
    }
}
```

- [ ] **Step 2: Run tests — confirm all fail**

```bash
forge test --match-path test/MachineControls.t.sol -v
```

Expected: `FAIL` — tests compile but all revert (contract exists from previous task, but tests should pass now — verify none are unexpectedly failing for wrong reasons)

- [ ] **Step 3: Run full suite to confirm all tests pass**

```bash
forge test -v
```

Expected: All `DeedAccess`, `VaultRevenue`, and `MachineControls` tests `PASS`

- [ ] **Step 4: Commit**

```bash
git add test/MachineControls.t.sol
git commit -m "test: machine controls and exhibition operator access tests"
```

---

## Chunk 5: Crossmint Validation & BalloonsNFT

### Task 7: Validate Crossmint MintParams Schema

- [ ] **Step 1: Query Crossmint docs via MCP**

Use the `crossmint-docs` MCP server to fetch the Custom Contract Minting API docs. Verify:
- What parameter types Crossmint can pass in a `callData` / `mintParameters` payload
- Whether `int256` is supported or must be encoded differently
- Whether structs are passed as ABI-encoded calldata or as individual fields
- Any ABI encoding requirements for the `mint(address to, MintParams calldata)` signature

**Important:** If `int256` is not supported by Crossmint's API, the same adjustment must be made in BOTH places:
  1. `MintParams.imagination` in `BalloonsNFT.sol`
  2. `truncation` state variable in `InstallationContract.sol`

Update `SPEC.md` Section 4.5 and this plan if any type adjustments are needed before proceeding.

### Task 8: MetadataAssembly — Failing Tests

**Files:**
- Create: `test/MetadataAssembly.t.sol`

- [ ] **Step 1: Write failing metadata tests**

Create `test/MetadataAssembly.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeedNFT.sol";
import "../src/InstallationContract.sol";
import "../src/BalloonsNFT.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract MetadataAssemblyTest is Test {
    DeedNFT              public deed;
    InstallationContract public installation;
    BalloonsNFT          public balloons;

    address public artist    = makeAddr("artist");
    address public collector = makeAddr("collector");
    address public minter    = makeAddr("minter");
    address public customer  = makeAddr("customer");

    BalloonsNFT.MintParams public sampleParams;

    function setUp() public {
        vm.prank(artist);
        deed = new DeedNFT(artist, "ipfs://deed");

        installation = new InstallationContract(
            address(deed), artist, makeAddr("gallery"), 1000, 2500
        );

        balloons = new BalloonsNFT(address(deed), address(installation), artist, minter);

        sampleParams = BalloonsNFT.MintParams({
            uniqueName:      "Rising Blue",
            unitNumber:      42,
            seed:            839201,
            timestamp:       "16/03/2026 14:32 CET",
            orientation:     0,
            imagination:     75,    // represents 0.75
            cid:             "QmTest123",
            eventName:       "NFC Lisbon 2026",
            pieceType:       "Artist Proof",
            pixelDimensions: "1920x1080"
        });
    }

    // -------------------------------------------------------------------------
    // Access Control
    // -------------------------------------------------------------------------

    function test_minterCanMint() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertEq(balloons.ownerOf(0), customer);
    }

    function test_strangerCannotMint() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        balloons.mint(customer, sampleParams);
    }

    function test_deedHolderCanSetMinter() public {
        address newMinter = makeAddr("newMinter");
        vm.prank(artist);
        balloons.setMinter(newMinter);
        assertEq(balloons.minterAddress(), newMinter);
    }

    function test_strangerCannotSetMinter() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        balloons.setMinter(makeAddr("badMinter"));
    }

    // -------------------------------------------------------------------------
    // Paused: mint blocked when installation is paused
    // -------------------------------------------------------------------------

    function test_mintRevertsWhenInstallationPaused() public {
        vm.prank(artist);
        installation.setPaused(true);

        vm.prank(minter);
        vm.expectRevert();
        balloons.mint(customer, sampleParams);
    }

    function test_mintSucceedsAfterUnpause() public {
        vm.prank(artist);
        installation.setPaused(true);
        vm.prank(artist);
        installation.setPaused(false);

        vm.prank(minter);
        balloons.mint(customer, sampleParams); // should not revert
        assertEq(balloons.ownerOf(0), customer);
    }

    // -------------------------------------------------------------------------
    // Royalties
    // -------------------------------------------------------------------------

    function test_defaultRoyaltyIsTenPercent() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        (address receiver, uint256 amount) = balloons.royaltyInfo(0, 1 ether);
        assertEq(receiver, artist);
        assertEq(amount, 0.1 ether);
    }

    function test_artistCanUpdateRoyaltyRate() public {
        vm.prank(artist);
        balloons.setRoyalty(artist, 500); // 5%
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        (, uint256 amount) = balloons.royaltyInfo(0, 1 ether);
        assertEq(amount, 0.05 ether);
    }

    function test_deedHolderCannotUpdateRoyaltyRate() public {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
        vm.prank(collector);
        vm.expectRevert();
        balloons.setRoyalty(collector, 500);
    }

    // -------------------------------------------------------------------------
    // Token URI: structure
    // -------------------------------------------------------------------------

    function test_tokenURIIsBase64JSON() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        string memory uri = balloons.tokenURI(0);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
    }

    function test_tokenURIContainsUniqueName() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "Rising Blue"));
    }

    function test_tokenURIContainsAllTraits() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);

        assertTrue(_containsInURI(0, "Unit Number"));
        assertTrue(_containsInURI(0, "Seed"));
        assertTrue(_containsInURI(0, "Orientation"));
        assertTrue(_containsInURI(0, "Imagination"));
        assertTrue(_containsInURI(0, "Event"));
        assertTrue(_containsInURI(0, "Timestamp"));
        assertTrue(_containsInURI(0, "Type"));
        assertTrue(_containsInURI(0, "Pixel Dimensions"));
    }

    function test_orientationRendersAsPortrait() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams); // orientation=0
        assertTrue(_containsInURI(0, "Portrait"));
    }

    function test_orientationRendersAsLandscape() public {
        sampleParams.orientation = 1;
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "Landscape"));
    }

    function test_imaginationRendersAsPositiveFloat() public {
        // imagination=75 → "0.75"
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "0.75"));
    }

    function test_imaginationRendersAsNegativeFloat() public {
        sampleParams.imagination = -150; // → "-1.50"
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "-1.50"));
    }

    function test_imaginationRendersAtBoundaryMax() public {
        sampleParams.imagination = 500; // → "5.00"
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "5.00"));
    }

    function test_imaginationRendersAtBoundaryMin() public {
        sampleParams.imagination = -200; // → "-2.00"
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "-2.00"));
    }

    function test_tokenURIContainsIPFSImage() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "ipfs://QmTest123"));
    }

    function test_tokenURIContainsHardcodedArtist() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "Ionson"));
    }

    function test_tokenURIContainsLicense() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        assertTrue(_containsInURI(0, "CC BY-NC 4.0"));
    }

    // -------------------------------------------------------------------------
    // CID update
    // -------------------------------------------------------------------------

    function test_artistCanUpdateTokenCID() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);

        vm.prank(artist);
        balloons.setTokenCID(0, "QmUpdatedCID");

        assertTrue(_containsInURI(0, "ipfs://QmUpdatedCID"));
        assertFalse(_containsInURI(0, "QmTest123"));
    }

    function test_strangerCannotUpdateTokenCID() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        balloons.setTokenCID(0, "QmHacked");
    }

    function test_cidUpdateDoesNotChangeOtherTraits() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams);
        vm.prank(artist);
        balloons.setTokenCID(0, "QmNewCID");

        assertTrue(_containsInURI(0, "Rising Blue"));
        assertTrue(_containsInURI(0, "0.75"));
        assertTrue(_containsInURI(0, "NFC Lisbon 2026"));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _containsInURI(uint256 tokenId, string memory needle)
        internal view returns (bool)
    {
        return _contains(_decodeTokenURI(balloons.tokenURI(tokenId)), needle);
    }

    function _startsWith(string memory str, string memory prefix)
        internal pure returns (bool)
    {
        bytes memory s = bytes(str);
        bytes memory p = bytes(prefix);
        if (s.length < p.length) return false;
        for (uint i = 0; i < p.length; i++) {
            if (s[i] != p[i]) return false;
        }
        return true;
    }

    function _contains(string memory haystack, string memory needle)
        internal pure returns (bool)
    {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint i = 0; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) { found = false; break; }
            }
            if (found) return true;
        }
        return false;
    }

    function _decodeTokenURI(string memory uri)
        internal pure returns (string memory)
    {
        bytes memory uriBytes = bytes(uri);
        uint256 prefixLen = 29; // len("data:application/json;base64,")
        bytes memory encoded = new bytes(uriBytes.length - prefixLen);
        for (uint256 i = 0; i < encoded.length; i++) {
            encoded[i] = uriBytes[i + prefixLen];
        }
        return string(Base64.decode(string(encoded)));
    }
}
```

- [ ] **Step 2: Run tests — confirm all fail**

```bash
forge test --match-path test/MetadataAssembly.t.sol -v
```

Expected: `FAIL` — `BalloonsNFT` not found

### Task 9: BalloonsNFT — Implementation

**Files:**
- Create: `src/BalloonsNFT.sol`

- [ ] **Step 1: Implement BalloonsNFT**

Create `src/BalloonsNFT.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IInstallationContract {
    function paused() external view returns (bool);
}

/// @title BalloonsNFT
/// @notice Unlimited ERC-721 minted via Crossmint. 10 genetic parameters
///         stored on-chain per token; tokenURI assembles Base64 JSON entirely
///         on-chain. Royalties managed exclusively by the artist.
contract BalloonsNFT is ERC721, ERC2981 {
    using Strings for uint256;

    // -------------------------------------------------------------------------
    // Immutables
    // -------------------------------------------------------------------------

    address public immutable ARTIST;
    IERC721 public immutable deedContract;
    IInstallationContract public immutable installationContract;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address  public minterAddress;
    uint256  private _nextTokenId;

    // -------------------------------------------------------------------------
    // Mint Parameters (10 genetic parameters per token)
    // -------------------------------------------------------------------------

    struct MintParams {
        string  uniqueName;
        uint256 unitNumber;
        uint256 seed;
        string  timestamp;        // pre-formatted: "16/03/2026 14:32 CET"
        uint256 orientation;      // 0=Portrait, 1=Landscape
        int256  imagination;      // ×100, range -200 to 500 (-2.00 to 5.00)
        string  cid;              // IPFS CID
        string  eventName;
        string  pieceType;        // e.g. "Artist Proof"
        string  pixelDimensions;  // e.g. "1920x1080"
    }

    mapping(uint256 => MintParams) private _params;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyArtist() {
        require(msg.sender == ARTIST, "BN: not artist");
        _;
    }

    modifier onlyDeedHolder() {
        require(msg.sender == deedContract.ownerOf(0), "BN: not deed holder");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minterAddress, "BN: not minter");
        _;
    }

    modifier whenNotPaused() {
        require(!installationContract.paused(), "BN: minting paused");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        address _deed,
        address _installation,
        address _artist,
        address _minter
    ) ERC721("Balloons in the Sky", "BSKY") {
        deedContract         = IERC721(_deed);
        installationContract = IInstallationContract(_installation);
        ARTIST               = _artist;
        minterAddress        = _minter;
        _setDefaultRoyalty(_artist, 1000); // 10%
    }

    // -------------------------------------------------------------------------
    // Minting
    // -------------------------------------------------------------------------

    function mint(address to, MintParams calldata params)
        external onlyMinter whenNotPaused
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _params[tokenId] = params;
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    /// @notice Deed holder sets or updates the Crossmint minter address.
    function setMinter(address _minter) external onlyDeedHolder {
        minterAddress = _minter;
    }

    /// @notice Artist controls royalty rate and receiver (exclusively).
    function setRoyalty(address receiver, uint96 feeBps) external onlyArtist {
        _setDefaultRoyalty(receiver, feeBps);
    }

    /// @notice Artist can update the IPFS image CID for any token.
    ///         All other genetic parameters are immutable once minted.
    function setTokenCID(uint256 tokenId, string calldata cid) external onlyArtist {
        _requireOwned(tokenId);
        _params[tokenId].cid = cid;
    }

    // -------------------------------------------------------------------------
    // Metadata: on-chain Base64 JSON renderer
    // -------------------------------------------------------------------------

    function tokenURI(uint256 tokenId)
        public view override returns (string memory)
    {
        _requireOwned(tokenId);
        MintParams memory p = _params[tokenId];

        string memory json = string.concat(
            '{"name":"Balloons in the Sky #',
            tokenId.toString(),
            ' \u2014 ',
            p.uniqueName,
            '","description":"Balloons in the Sky by B\xC3\xA5rd Ionson & Jennifer Ionson"',
            ',"image":"ipfs://',
            p.cid,
            '","license":"CC BY-NC 4.0"',
            ',"attributes":[',
            _buildAttributes(p),
            ']}'
        );

        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        );
    }

    function _buildAttributes(MintParams memory p)
        internal pure returns (string memory)
    {
        return string.concat(
            _trait("Unit Number",       p.unitNumber.toString()),
            ',', _trait("Seed",         p.seed.toString()),
            ',', _trait("Orientation",  p.orientation == 0 ? "Portrait" : "Landscape"),
            ',', _trait("Imagination",  _formatImagination(p.imagination)),
            ',', _trait("Event",        p.eventName),
            ',', _trait("Timestamp",    p.timestamp),
            ',', _trait("Type",         p.pieceType),
            ',', _trait("Pixel Dimensions", p.pixelDimensions)
        );
    }

    function _trait(string memory traitType, string memory value)
        internal pure returns (string memory)
    {
        return string.concat(
            '{"trait_type":"', traitType, '","value":"', value, '"}'
        );
    }

    /// @dev Converts int256 ×100 to float string.
    ///      75 → "0.75" | -150 → "-1.50" | 500 → "5.00" | -200 → "-2.00"
    function _formatImagination(int256 val) internal pure returns (string memory) {
        bool negative = val < 0;
        uint256 abs   = negative ? uint256(-val) : uint256(val);
        uint256 whole = abs / 100;
        uint256 frac  = abs % 100;

        string memory fracStr = frac < 10
            ? string.concat("0", frac.toString())
            : frac.toString();

        return string.concat(
            negative ? "-" : "",
            whole.toString(),
            ".",
            fracStr
        );
    }

    // -------------------------------------------------------------------------
    // ERC-165
    // -------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC2981) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

- [ ] **Step 2: Run all metadata tests — all pass**

```bash
forge test --match-path test/MetadataAssembly.t.sol -v
```

Expected: All tests `PASS`

- [ ] **Step 3: Run full test suite — all pass**

```bash
forge test -v
```

Expected: All tests across all four test files `PASS`

- [ ] **Step 4: Commit**

```bash
git add src/BalloonsNFT.sol test/MetadataAssembly.t.sol
git commit -m "feat: BalloonsNFT on-chain metadata renderer, ERC-2981, pause guard"
```

---

## Chunk 6: Deployment & Final Verification

### Task 10: Deployment Script

**Files:**
- Create: `script/Deploy.s.sol`

- [ ] **Step 1: Write deployment script**

Create `script/Deploy.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DeedNFT.sol";
import "../src/InstallationContract.sol";
import "../src/BalloonsNFT.sol";

/// @notice Deploy all three Sovereign System contracts in dependency order.
///         Run: forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
///
/// @dev BEFORE RUNNING: replace all placeholder addresses and CIDs below.
contract Deploy is Script {

    // -------------------------------------------------------------------------
    // !! CONFIGURE BEFORE DEPLOY !!
    // -------------------------------------------------------------------------

    address constant ARTIST_ADDRESS   = address(0); // REPLACE: artist wallet
    address constant GALLERY_ADDRESS  = address(0); // REPLACE: Hash Gallery wallet
    address constant MINTER_ADDRESS   = address(0); // REPLACE: Crossmint wallet

    string constant DEED_METADATA_URI = "ipfs://REPLACE_WITH_DEED_METADATA_CID";

    // Pre-sale splits: Gallery 10%, Endowment 25%, Artist 65% (implicit)
    uint256 constant PRE_GALLERY_BPS   = 1000;
    uint256 constant PRE_ENDOWMENT_BPS = 2500;

    // -------------------------------------------------------------------------

    function run() external {
        require(ARTIST_ADDRESS  != address(0), "Set ARTIST_ADDRESS");
        require(GALLERY_ADDRESS != address(0), "Set GALLERY_ADDRESS");
        require(MINTER_ADDRESS  != address(0), "Set MINTER_ADDRESS");

        vm.startBroadcast();

        // 1. Deploy Deed NFT — mints token #0 to artist
        DeedNFT deed = new DeedNFT(ARTIST_ADDRESS, DEED_METADATA_URI);
        console.log("DeedNFT deployed:           ", address(deed));

        // 2. Deploy Installation Contract
        InstallationContract installation = new InstallationContract(
            address(deed),
            ARTIST_ADDRESS,
            GALLERY_ADDRESS,
            PRE_GALLERY_BPS,
            PRE_ENDOWMENT_BPS
        );
        console.log("InstallationContract:       ", address(installation));

        // 3. Deploy Balloons NFT (references both deed and installation)
        BalloonsNFT balloons = new BalloonsNFT(
            address(deed),
            address(installation),
            ARTIST_ADDRESS,
            MINTER_ADDRESS
        );
        console.log("BalloonsNFT deployed:       ", address(balloons));

        vm.stopBroadcast();

        // Post-deploy verification
        require(deed.ownerOf(0)          == ARTIST_ADDRESS, "Deed: wrong owner");
        require(deed.ARTIST()            == ARTIST_ADDRESS, "Deed: wrong artist");
        require(balloons.minterAddress() == MINTER_ADDRESS, "Balloons: wrong minter");
        require(balloons.ARTIST()        == ARTIST_ADDRESS, "Balloons: wrong artist");

        console.log("Deployment verification passed.");
    }
}
```

- [ ] **Step 2: Dry run (no broadcast)**

```bash
forge script script/Deploy.s.sol -vvv
```

Expected: Script executes without revert. Three contract addresses logged.

- [ ] **Step 3: Commit**

```bash
git add script/Deploy.s.sol
git commit -m "chore: deployment script for Sovereign System"
```

### Task 11: Gas Snapshot & Size Check

- [ ] **Step 1: Run gas snapshot**

```bash
forge snapshot
```

Expected: `.gas-snapshot` created. Key functions to review:
- `receive()` — called on every Crossmint mint
- `tokenURI()` — called by every marketplace on every load
- `mint()` — called by Crossmint

- [ ] **Step 2: Check contract sizes (24KB limit)**

```bash
forge build --sizes
```

Expected: All contracts well under 24KB. If `BalloonsNFT` is over, extract `_formatImagination` and `_buildAttributes` into a `RendererLib` library.

- [ ] **Step 3: Full final test run**

```bash
forge test --gas-report
```

Expected: All tests `PASS`. Review gas report.

- [ ] **Step 4: Commit**

```bash
git add .gas-snapshot
git commit -m "chore: gas snapshot baseline"
```

---

## Pre-Mainnet Deployment Checklist

- [ ] Replace `ARTIST_ADDRESS` with real artist wallet in `Deploy.s.sol`
- [ ] Replace `GALLERY_ADDRESS` with Hash Gallery wallet
- [ ] Replace `MINTER_ADDRESS` with Crossmint's contract minting wallet
- [ ] Replace `DEED_METADATA_URI` with final IPFS CID of deed artwork JSON
- [ ] Validate `MintParams` struct against Crossmint API (Task 7)
- [ ] Deploy and test on Sepolia with a real Crossmint test mint
- [ ] Verify `tokenURI()` renders correctly on OpenSea testnet
- [ ] Verify `paused` halts mints via Crossmint test environment
- [ ] Confirm post-sale split flip works by simulating Deed transfer on testnet
- [ ] Artist reviews and approves all deployed contract addresses

---

*Plan authored: 2026-03-16*
*Spec reference: SPEC.md*
*Reviewed and approved before implementation*
