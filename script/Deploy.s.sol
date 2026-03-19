// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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

    address constant ARTIST_ADDRESS   = 0x2167DB9C3bfdCA18FEaE891a5c5F7713DcD3171b; // Sepolia test: artist wallet
    address constant GALLERY_ADDRESS  = 0xEA1ac22F0833dB1f17FFA8eBCdaF702521052472; // Sepolia test: gallery stand-in
    address constant MINTER_ADDRESS   = 0x0A772399c89763D331D121236ADD4D6AecEfB134; // Sepolia test: minter stand-in (replace with Crossmint wallet post-registration)

    string constant DEED_METADATA_URI = "ipfs://bafybeiabc123placeholder"; // Sepolia test: placeholder CID

    // Pre-sale splits: Gallery 10%, Endowment 25%, Artist 65% (implicit)
    uint256 constant PRE_GALLERY_BPS   = 1000;
    uint256 constant PRE_ENDOWMENT_BPS = 2500;

    // -------------------------------------------------------------------------

    function run() external {
        require(ARTIST_ADDRESS  != address(0), "Set ARTIST_ADDRESS");
        require(GALLERY_ADDRESS != address(0), "Set GALLERY_ADDRESS");
        require(MINTER_ADDRESS  != address(0), "Set MINTER_ADDRESS");
        require(
            keccak256(bytes(DEED_METADATA_URI)) != keccak256(bytes("ipfs://REPLACE_WITH_DEED_METADATA_CID")),
            "Set DEED_METADATA_URI"
        );

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
