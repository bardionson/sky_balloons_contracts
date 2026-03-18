// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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
        require(
            params.imagination >= -200 && params.imagination <= 500,
            "BN: imagination out of range"
        );
        require(params.orientation <= 1, "BN: invalid orientation");
        uint256 tokenId = _nextTokenId++;
        _params[tokenId] = params;
        _safeMint(to, tokenId);
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
            '","description":"Balloons in the Sky by B\u00e5rd Ionson & Jennifer Ionson"',
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
            _traitNumeric("Unit Number", p.unitNumber.toString()),
            ',', _traitNumeric("Seed",   p.seed.toString()),
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

    function _traitNumeric(string memory traitType, string memory value)
        internal pure returns (string memory)
    {
        return string.concat(
            '{"trait_type":"', traitType, '","value":', value, '}'
        );
    }

    /// @dev Converts int256 ×100 to float string.
    ///      75 → "0.75" | -150 → "-1.50" | 500 → "5.00" | -200 → "-2.00"
    function _formatImagination(int256 val) internal pure returns (string memory) {
        bool negative = val < 0;
        // safe: imagination is validated to [-200, 500] in mint(), so int256.min is unreachable
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
