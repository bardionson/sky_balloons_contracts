// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

    address public immutable ARTIST;
    IERC721 public immutable deedContract;

    address public galleryAddress;
    address public collectorVenueAddress;
    address public artistVenueAddress;

    uint256 public preSaleGalleryBps;
    uint256 public preSaleEndowmentBps;

    uint256 public postSaleGalleryBps   = 1000;
    uint256 public postSaleEndowmentBps = 4500;
    uint256 public postSaleArtistBps    = 4500;
    uint256 public collectorVenueBps;
    uint256 public artistVenueBps;

    uint256 public artistReclaimedBps;
    uint256 public collectorReclaimedBps;

    mapping(address => uint256) public balances;

    address public exhibitionOperator;

    int256  public truncation;
    uint256 public orientation;
    string  public activeEventName;
    bool    public paused;
    uint256 public speed = 525;
    uint256 public interpolation;
    string  public modelSource;

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

    function isPreSale() public view returns (bool) {
        return deedContract.ownerOf(0) == ARTIST;
    }

    receive() external payable {
        address deedHolder = deedContract.ownerOf(0);
        if (deedHolder == ARTIST) {
            _allocatePreSale(msg.value);
        } else {
            _allocatePostSale(msg.value, deedHolder);
        }
    }

    function _allocatePreSale(uint256 amount) internal {
        uint256 galleryCut   = amount * preSaleGalleryBps / 10000;
        uint256 endowmentCut = amount * preSaleEndowmentBps / 10000;
        uint256 artistCut    = amount - galleryCut - endowmentCut;
        balances[galleryAddress] += galleryCut;
        balances[ARTIST]         += endowmentCut + artistCut;
    }

    function _allocatePostSale(uint256 amount, address deedHolder) internal {
        uint256 galleryCut        = amount * postSaleGalleryBps / 10000;
        uint256 endowmentCut      = amount * postSaleEndowmentBps / 10000;
        uint256 artistCut         = amount * postSaleArtistBps / 10000;
        uint256 collectorVenueCut = amount * collectorVenueBps / 10000;
        uint256 artistVenueCut    = amount * artistVenueBps / 10000;
        balances[galleryAddress] += galleryCut;
        balances[deedHolder]     += endowmentCut;
        balances[ARTIST]         += artistCut;
        if (collectorVenueAddress != address(0))
            balances[collectorVenueAddress] += collectorVenueCut;
        if (artistVenueAddress != address(0))
            balances[artistVenueAddress]    += artistVenueCut;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "IC: nothing to withdraw");
        balances[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "IC: transfer failed");
    }

    function setPreSaleGalleryBps(uint256 bps) external onlyArtist onlyPreSale {
        preSaleGalleryBps = bps;
    }

    function setPreSaleEndowmentBps(uint256 bps) external onlyArtist onlyPreSale {
        preSaleEndowmentBps = bps;
    }

    function setCollectorVenue(address venue, uint256 bps)
        external onlyDeedHolder onlyPostSale
    {
        if (collectorVenueAddress != address(0)) {
            postSaleEndowmentBps += collectorVenueBps; // restore old allocation first
        }
        require(bps <= postSaleEndowmentBps, "IC: exceeds endowment share");
        collectorVenueAddress = venue;
        collectorVenueBps     = bps;
        postSaleEndowmentBps  -= bps;
    }

    function setArtistVenue(address venue, uint256 bps)
        external onlyArtist onlyPostSale
    {
        if (artistVenueAddress != address(0)) {
            postSaleArtistBps += artistVenueBps; // restore old allocation first
        }
        require(bps <= postSaleArtistBps, "IC: exceeds artist share");
        artistVenueAddress = venue;
        artistVenueBps     = bps;
        postSaleArtistBps  -= bps;
    }

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

    function setExhibitionOperator(address operator) external onlyDeedHolder {
        exhibitionOperator = operator;
    }

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
