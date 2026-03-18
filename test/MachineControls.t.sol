// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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
        vm.prank(artist);
        installation.setExhibitionOperator(operator);
        assertEq(installation.exhibitionOperator(), operator);
    }

    function test_strangerCannotSetExhibitionOperator() public {
        vm.prank(stranger);
        vm.expectRevert();
        installation.setExhibitionOperator(operator);
    }

    function test_artistCannotSetExhibitionOperatorAfterDeedTransfer() public {
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
    // truncation: onlyDeedHolderOrOperator, range -200 to 500
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

    // -------------------------------------------------------------------------
    // orientation: onlyDeedHolderOrOperator, 0 or 1
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // speed: onlyDeedHolderOrOperator, 50-1000
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // interpolation: onlyDeedHolderOrOperator, 0-4
    // -------------------------------------------------------------------------

    function test_deedHolderCanSetInterpolation() public {
        vm.prank(artist);
        installation.setInterpolation(2);
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
        installation.setInterpolation(4);
        assertEq(installation.interpolation(), 4);
    }

    // -------------------------------------------------------------------------
    // activeEventName: onlyDeedHolder ONLY
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

    // -------------------------------------------------------------------------
    // paused: onlyDeedHolder ONLY
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // modelSource: onlyDeedHolder ONLY
    // -------------------------------------------------------------------------

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
        vm.prank(operator);
        installation.setSpeed(300);
        vm.prank(artist);
        installation.setExhibitionOperator(address(0));
        vm.prank(operator);
        vm.expectRevert();
        installation.setSpeed(400);
    }
}
