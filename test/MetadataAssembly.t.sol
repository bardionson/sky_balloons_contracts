// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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
        assertTrue(_containsInURI(0, "Jennifer Ionson"));
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

    function test_numericTraitsAreNotQuoted() public {
        vm.prank(minter);
        balloons.mint(customer, sampleParams); // unitNumber=42, seed=839201
        string memory decoded = _decodeTokenURI(balloons.tokenURI(0));
        // Numeric values must NOT be quoted in JSON
        assertTrue(_contains(decoded, '"value":42'));
        assertTrue(_contains(decoded, '"value":839201'));
        // String values remain quoted
        assertTrue(_contains(decoded, '"value":"Portrait"'));
    }

    // -------------------------------------------------------------------------
    // Input validation
    // -------------------------------------------------------------------------

    function test_mintRevertsOnInvalidImagination() public {
        sampleParams.imagination = 501; // out of range
        vm.prank(minter);
        vm.expectRevert("BN: imagination out of range");
        balloons.mint(customer, sampleParams);
    }

    function test_mintRevertsOnInvalidOrientation() public {
        sampleParams.orientation = 2; // invalid
        vm.prank(minter);
        vm.expectRevert("BN: invalid orientation");
        balloons.mint(customer, sampleParams);
    }

    // -------------------------------------------------------------------------
    // Imagination fuzz
    // -------------------------------------------------------------------------

    function testFuzz_imaginationFormatNeverPanics(int256 raw) public {
        raw = bound(raw, -200, 500);
        sampleParams.imagination = raw;
        vm.prank(minter);
        balloons.mint(customer, sampleParams);

        // tokenURI must not revert and must contain a dot (decimal format)
        string memory uri = balloons.tokenURI(0);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));

        // Decoded JSON must contain a decimal point (float format)
        string memory decoded = _decodeTokenURI(uri);
        assertTrue(_contains(decoded, "."));
    }

    function testFuzz_imaginationOutOfRangeReverts(int256 raw) public {
        // Bound to values strictly outside [-200, 500]
        if (raw >= -200 && raw <= 500) return; // skip valid range
        sampleParams.imagination = raw;
        vm.prank(minter);
        vm.expectRevert("BN: imagination out of range");
        balloons.mint(customer, sampleParams);
    }

    // -------------------------------------------------------------------------
    // Multi-token parameter isolation
    // -------------------------------------------------------------------------

    function test_multipleTokensHaveIsolatedParams() public {
        // Mint token 0
        BalloonsNFT.MintParams memory p0 = BalloonsNFT.MintParams({
            uniqueName:      "Token Zero",
            unitNumber:      0,
            seed:            111,
            timestamp:       "01/01/2026 10:00 CET",
            orientation:     0,
            imagination:     0,
            cid:             "QmCID0",
            eventName:       "Event A",
            pieceType:       "Edition",
            pixelDimensions: "1920x1080"
        });
        vm.prank(minter);
        balloons.mint(customer, p0);

        // Mint token 1
        BalloonsNFT.MintParams memory p1 = BalloonsNFT.MintParams({
            uniqueName:      "Token One",
            unitNumber:      1,
            seed:            222,
            timestamp:       "02/01/2026 11:00 CET",
            orientation:     1,
            imagination:     200,
            cid:             "QmCID1",
            eventName:       "Event B",
            pieceType:       "Artist Proof",
            pixelDimensions: "3840x2160"
        });
        vm.prank(minter);
        balloons.mint(customer, p1);

        // Mint token 2
        BalloonsNFT.MintParams memory p2 = BalloonsNFT.MintParams({
            uniqueName:      "Token Two",
            unitNumber:      2,
            seed:            333,
            timestamp:       "03/01/2026 12:00 CET",
            orientation:     0,
            imagination:     -100,
            cid:             "QmCID2",
            eventName:       "Event C",
            pieceType:       "Edition",
            pixelDimensions: "1080x1920"
        });
        vm.prank(minter);
        balloons.mint(customer, p2);

        // Each token URI contains only its own data
        assertTrue(_containsInURI(0, "Token Zero"));
        assertTrue(_containsInURI(0, "QmCID0"));
        assertTrue(_containsInURI(0, "Event A"));
        assertFalse(_containsInURI(0, "Token One"));
        assertFalse(_containsInURI(0, "Token Two"));

        assertTrue(_containsInURI(1, "Token One"));
        assertTrue(_containsInURI(1, "QmCID1"));
        assertTrue(_containsInURI(1, "Landscape"));
        assertTrue(_containsInURI(1, "2.00"));
        assertFalse(_containsInURI(1, "Token Zero"));
        assertFalse(_containsInURI(1, "Token Two"));

        assertTrue(_containsInURI(2, "Token Two"));
        assertTrue(_containsInURI(2, "QmCID2"));
        assertTrue(_containsInURI(2, "Portrait"));
        assertTrue(_containsInURI(2, "-1.00"));
        assertFalse(_containsInURI(2, "Token Zero"));
        assertFalse(_containsInURI(2, "Token One"));
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
