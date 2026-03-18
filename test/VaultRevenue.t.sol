// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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

    uint256 constant PRE_GALLERY_BPS   = 1000;
    uint256 constant PRE_ENDOWMENT_BPS = 2500;
    uint256 constant POST_GALLERY_BPS   = 1000;
    uint256 constant POST_ENDOWMENT_BPS = 4500;
    uint256 constant POST_ARTIST_BPS    = 4500;

    function setUp() public {
        vm.prank(artist);
        deed = new DeedNFT(artist, "ipfs://deed");
        installation = new InstallationContract(
            address(deed), artist, gallery, PRE_GALLERY_BPS, PRE_ENDOWMENT_BPS
        );
    }

    function test_ethCreditedToBucketsOnReceivePreSale() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);
        uint256 expectedGallery     = 1 ether * PRE_GALLERY_BPS / 10000;
        uint256 expectedArtistTotal = 1 ether - expectedGallery;
        assertEq(installation.balances(gallery), expectedGallery);
        assertEq(installation.balances(artist),  expectedArtistTotal);
    }

    function test_splitChangesOnlyAffectFutureEth() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok);
        uint256 galleryAfterFirst = installation.balances(gallery);
        vm.prank(artist);
        installation.setPreSaleGalleryBps(2000);
        vm.deal(address(this), 1 ether);
        (bool ok2,) = address(installation).call{value: 1 ether}("");
        assertTrue(ok2);
        uint256 galleryAfterSecond = installation.balances(gallery);
        assertEq(galleryAfterFirst, 0.1 ether);
        assertEq(galleryAfterSecond - galleryAfterFirst, 0.2 ether);
    }

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
        vm.prank(artist);
        vm.expectRevert();
        installation.setCollectorVenue(venue1, 500);
    }

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
        vm.prank(artist);
        installation.reclaimFromGallery(300);
        vm.prank(artist);
        installation.reclaimFromGallery(200);
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
