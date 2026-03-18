// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/DeedNFT.sol";
import "../src/InstallationContract.sol";

contract ReentrancyAttacker {
    InstallationContract public target;
    uint256 public reentrancyAttempts;
    uint256 public ethReceived;

    constructor(address payable _target) {
        target = InstallationContract(payable(_target));
    }

    function setTarget(address payable _target) external {
        target = InstallationContract(_target);
    }

    receive() external payable {
        ethReceived += msg.value;
        // Try to re-enter withdraw
        if (target.balances(address(this)) > 0) {
            reentrancyAttempts++;
            target.withdraw();
        }
    }

    function attack() external {
        target.withdraw();
    }
}

contract AdvancedVaultTest is Test {
    DeedNFT              public deed;
    InstallationContract public installation;

    address public artist    = makeAddr("artist");
    address public collector = makeAddr("collector");
    address public gallery   = makeAddr("gallery");
    address public venue1    = makeAddr("venue1");
    address public venue2    = makeAddr("venue2");

    uint256 constant PRE_GALLERY_BPS   = 1000;
    uint256 constant PRE_ENDOWMENT_BPS = 2500;

    function setUp() public {
        vm.prank(artist);
        deed = new DeedNFT(artist, "ipfs://deed");
        installation = new InstallationContract(
            address(deed), artist, gallery, PRE_GALLERY_BPS, PRE_ENDOWMENT_BPS
        );
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    function _transferDeedToCollector() internal {
        vm.prank(artist);
        deed.transferFrom(artist, collector, 0);
    }

    function _sendEth(address target, uint256 amount) internal {
        vm.deal(address(this), amount);
        (bool ok,) = target.call{value: amount}("");
        assertTrue(ok, "ETH send failed");
    }

    // Allow this test contract to receive ETH (needed for some tests)
    receive() external payable {}

    // -----------------------------------------------------------------------
    // Section 1: Revenue Splitting Invariants
    // -----------------------------------------------------------------------

    /// @notice Fuzz: pre-sale, sum of all credited balances == msg.value (no stranded ETH)
    function testFuzz_preSaleNoEthStranded(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        vm.deal(address(this), amount);
        (bool ok,) = address(installation).call{value: amount}("");
        assertTrue(ok);
        uint256 total = installation.balances(gallery) + installation.balances(artist);
        assertEq(total, amount);
    }

    /// @notice Fuzz: post-sale (no venues), sum of all credited balances == msg.value
    function testFuzz_postSaleNoEthStranded(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        _transferDeedToCollector();
        vm.deal(address(this), amount);
        (bool ok,) = address(installation).call{value: amount}("");
        assertTrue(ok);
        uint256 total = installation.balances(gallery)
            + installation.balances(collector)
            + installation.balances(artist);
        assertEq(total, amount);
    }

    /// @notice Fuzz: post-sale with both venues set, sum of all 5 balances == msg.value
    function testFuzz_postSaleWithVenuesNoEthStranded(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        _transferDeedToCollector();
        vm.prank(collector);
        installation.setCollectorVenue(venue1, 300);
        vm.prank(artist);
        installation.setArtistVenue(venue2, 200);
        vm.deal(address(this), amount);
        (bool ok,) = address(installation).call{value: amount}("");
        assertTrue(ok);
        uint256 total = installation.balances(gallery)
            + installation.balances(collector)
            + installation.balances(artist)
            + installation.balances(venue1)
            + installation.balances(venue2);
        assertEq(total, amount);
    }

    /// @notice Fuzz: arbitrary pre-sale bps values, no stranded ETH
    function testFuzz_preSaleArbitraryBps(uint256 galleryBps, uint256 endowmentBps) public {
        galleryBps = bound(galleryBps, 0, 9000);
        endowmentBps = bound(endowmentBps, 0, 9000);
        vm.assume(galleryBps + endowmentBps <= 10000);
        vm.prank(artist);
        installation.setPreSaleGalleryBps(galleryBps);
        vm.prank(artist);
        installation.setPreSaleEndowmentBps(endowmentBps);
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);
        uint256 total = installation.balances(gallery) + installation.balances(artist);
        assertEq(total, 1 ether);
    }

    /// @notice 10 repeated 0.1 ether mints accumulate correctly
    function test_repeatedMintsAccumulateCorrectly() public {
        uint256 galleryCutPerTx = 0.1 ether * PRE_GALLERY_BPS / 10000;
        uint256 artistCutPerTx = 0.1 ether - galleryCutPerTx;
        for (uint256 i = 0; i < 10; i++) {
            vm.deal(address(this), 0.1 ether);
            (bool ok,) = address(installation).call{value: 0.1 ether}("");
            assertTrue(ok);
        }
        assertEq(installation.balances(artist), artistCutPerTx * 10);
        assertEq(installation.balances(gallery), galleryCutPerTx * 10);
    }

    /// @notice 1 wei post-sale, no venues: dust goes to artist, no ETH lost
    function test_postSaleDustGoesToArtist() public {
        _transferDeedToCollector();
        vm.deal(address(this), 1);
        (bool ok,) = address(installation).call{value: 1}("");
        assertTrue(ok);
        uint256 total = installation.balances(gallery)
            + installation.balances(collector)
            + installation.balances(artist);
        assertEq(total, 1, "1 wei must be fully accounted for");
    }

    /// @notice 1 wei post-sale with both venues active (1 bps each): no ETH lost
    function test_postSaleDustWithVenuesGoesToArtist() public {
        _transferDeedToCollector();
        vm.prank(collector);
        installation.setCollectorVenue(venue1, 1);
        vm.prank(artist);
        installation.setArtistVenue(venue2, 1);
        vm.deal(address(this), 1);
        (bool ok,) = address(installation).call{value: 1}("");
        assertTrue(ok);
        uint256 total = installation.balances(gallery)
            + installation.balances(collector)
            + installation.balances(artist)
            + installation.balances(venue1)
            + installation.balances(venue2);
        assertEq(total, 1, "1 wei must be fully accounted for with venues");
    }

    // -----------------------------------------------------------------------
    // Section 2: Reentrancy Attack Simulations
    // -----------------------------------------------------------------------

    /// @notice Reentrancy attack via receive() callback is neutralized by CEI
    function test_reentrancyAttackFails() public {
        // Deploy attacker with placeholder target
        ReentrancyAttacker attacker = new ReentrancyAttacker(payable(address(0)));

        // Deploy a fresh installation where the gallery IS the attacker contract
        vm.prank(artist);
        DeedNFT deed2 = new DeedNFT(artist, "ipfs://deed2");
        InstallationContract vulnerable = new InstallationContract(
            address(deed2), artist, address(attacker), 1000, 2500
        );

        // Wire attacker to the correct target
        attacker.setTarget(payable(address(vulnerable)));

        // Send 1 ether so attacker (as gallery) gets 10% = 0.1 ether balance
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(vulnerable).call{value: 1 ether}("");
        assertTrue(ok);

        uint256 attackerBalance = vulnerable.balances(address(attacker));
        assertEq(attackerBalance, 0.1 ether, "attacker should have gallery share");

        // Execute attack
        attacker.attack();

        // CEI pattern: balance was zeroed before the call, so reentrancy found balance=0
        assertEq(attacker.reentrancyAttempts(), 0, "reentrancy should not have been possible");
        assertEq(attacker.ethReceived(), attackerBalance, "attacker received exactly their share");
        assertEq(vulnerable.balances(address(attacker)), 0, "balance should be zero after withdraw");
    }

    /// @notice Simple CEI verification: balance zeroed before transfer
    function test_withdrawZeroesBalanceBeforeTransfer() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);
        uint256 expected = installation.balances(artist);
        assertGt(expected, 0);
        vm.prank(artist);
        installation.withdraw();
        assertEq(installation.balances(artist), 0);
        assertEq(artist.balance, expected);
    }

    // -----------------------------------------------------------------------
    // Section 3: Access Control -- Exact Error String Tests
    // -----------------------------------------------------------------------

    /// @notice Stranger calling setPreSaleGalleryBps gets "IC: not artist"
    function test_onlyArtistExactError() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(bytes("IC: not artist"));
        installation.setPreSaleGalleryBps(500);
    }

    /// @notice Stranger calling setExhibitionOperator gets "IC: not deed holder"
    function test_onlyDeedHolderExactError() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(bytes("IC: not deed holder"));
        installation.setExhibitionOperator(stranger);
    }

    /// @notice Post-sale, artist calls setPreSaleGalleryBps, gets "IC: not pre-sale"
    function test_onlyPreSaleExactError() public {
        _transferDeedToCollector();
        vm.prank(artist);
        vm.expectRevert(bytes("IC: not pre-sale"));
        installation.setPreSaleGalleryBps(500);
    }

    /// @notice Pre-sale, deed holder (artist) calls setCollectorVenue, gets "IC: not post-sale"
    function test_onlyPostSaleExactError() public {
        vm.prank(artist);
        vm.expectRevert(bytes("IC: not post-sale"));
        installation.setCollectorVenue(venue1, 500);
    }

    /// @notice Operator with zero balance calling withdraw gets "IC: nothing to withdraw"
    function test_exhibitionOperatorCannotWithdraw() public {
        address operator = makeAddr("operator");
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        vm.expectRevert(bytes("IC: nothing to withdraw"));
        installation.withdraw();
    }

    /// @notice Operator calling setPaused gets "IC: not deed holder"
    function test_exhibitionOperatorCannotSetPaused() public {
        address operator = makeAddr("operator");
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        vm.expectRevert(bytes("IC: not deed holder"));
        installation.setPaused(true);
    }

    /// @notice Operator calling reclaimFromGallery post-sale gets revert (not authorized)
    function test_exhibitionOperatorCannotCallFinancials() public {
        _transferDeedToCollector();
        address operator = makeAddr("operator");
        vm.prank(collector);
        installation.setExhibitionOperator(operator);
        vm.prank(operator);
        vm.expectRevert(bytes("IC: not authorized"));
        installation.reclaimFromGallery(100);
    }

    /// @notice After deed transfer, artist is no longer deed holder
    function test_artistIsNotDeedHolderPostSale() public {
        _transferDeedToCollector();
        vm.prank(artist);
        vm.expectRevert(bytes("IC: not deed holder"));
        installation.setExhibitionOperator(venue1);
    }

    /// @notice Deed transfer instantly changes control -- collector can act same block
    function test_deedTransferInstantlyChangesControl() public {
        _transferDeedToCollector();
        vm.prank(collector);
        installation.setExhibitionOperator(venue1);
        assertEq(installation.exhibitionOperator(), venue1);
    }
}
