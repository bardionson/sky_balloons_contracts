// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
