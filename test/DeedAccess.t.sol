// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
