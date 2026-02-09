// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AuctionManager.sol";
import "./HouseNFT.sol";

/**
 * @title AuctionFactory
 * @notice Factory contract for deploying independent AuctionManager instances
 * @dev Owner-controlled factory that creates new auction contracts with configurable parameters
 * @dev Factory is set as trusted in HouseNFT to enable automated controller setup
 */
contract AuctionFactory is Ownable {
    
    /// @notice HouseNFT contract (immutable)
    HouseNFT public immutable nftContract;
    
    /// @notice Payment token contract (immutable, typically USDC)
    IERC20 public immutable paymentToken;
    
    /// @notice Array of all deployed auction addresses
    address[] public auctions;
    
    /// @notice Mapping to check if an address is a deployed auction
    mapping(address => bool) public isAuction;
    
    // Events
    event AuctionCreated(
        address indexed auctionAddress,
        address indexed nftContract,
        uint256 indexed tokenId,
        address paymentToken,
        address admin,
        uint256[4] phaseDurations,
        uint256 floorPrice,
        uint256 minBidIncrementPercent,
        bool enforceMinIncrement,
        uint256 participationFee,
        address treasury,
        uint256 timestamp
    );
    
    /**
     * @notice Constructs the AuctionFactory
     * @param initialOwner The address that will own the factory
     * @param _nftContract Address of the HouseNFT contract
     * @param _paymentToken Address of the payment token (e.g., USDC)
     */
    constructor(
        address initialOwner,
        address _nftContract,
        address _paymentToken
    ) Ownable(initialOwner) {
        require(_nftContract != address(0), "Invalid NFT contract");
        require(_paymentToken != address(0), "Invalid payment token");
        
        nftContract = HouseNFT(_nftContract);
        paymentToken = IERC20(_paymentToken);
    }
    
    /**
     * @notice Creates a new independent auction instance
     * @dev Atomically: deploys auction, sets controller, transfers NFT
     * @param _admin Owner address for the new auction
     * @param _tokenId Token ID of the NFT (must be owned by factory)
     * @param _phaseDurations Array of 4 phase durations in seconds (phase 3 duration not used)
     * @param _floorPrice Minimum first bid amount
     * @param _minBidIncrementPercent Minimum bid increment percentage (1-100)
     * @param _enforceMinIncrement Whether to enforce the minimum increment
     * @param _participationFee One-time fee to participate (can be 0)
     * @param _treasury Address that receives participation fees and winning bid
     * @return The address of the newly deployed auction
     */
    function createAuction(
        address _admin,
        uint256 _tokenId,
        uint256[4] memory _phaseDurations,
        uint256 _floorPrice,
        uint256 _minBidIncrementPercent,
        bool _enforceMinIncrement,
        uint256 _participationFee,
        address _treasury
    ) external onlyOwner returns (address) {
        // Security: Verify factory owns the NFT before proceeding
        require(
            nftContract.ownerOf(_tokenId) == address(this),
            "Factory must own NFT"
        );
        
        // Deploy new AuctionManager instance
        AuctionManager newAuction = new AuctionManager(
            _admin,
            address(paymentToken),
            address(nftContract),
            _tokenId,
            _phaseDurations,
            _floorPrice,
            _minBidIncrementPercent,
            _enforceMinIncrement,
            _participationFee,
            _treasury
        );
        
        address auctionAddress = address(newAuction);
        
        // Security: Set controller BEFORE transferring NFT (atomic operation)
        nftContract.setController(_tokenId, auctionAddress);
        
        // Security: Transfer NFT from factory to auction (escrow)
        nftContract.transferFrom(address(this), auctionAddress, _tokenId);
        
        // Store auction address
        auctions.push(auctionAddress);
        isAuction[auctionAddress] = true;
        
        // Emit comprehensive event with all parameters
        emit AuctionCreated(
            auctionAddress,
            address(nftContract),
            _tokenId,
            address(paymentToken),
            _admin,
            _phaseDurations,
            _floorPrice,
            _minBidIncrementPercent,
            _enforceMinIncrement,
            _participationFee,
            _treasury,
            block.timestamp
        );
        
        return auctionAddress;
    }
    
    /**
     * @notice Returns the total number of auctions created
     * @return The count of deployed auctions
     */
    function getAuctionCount() external view returns (uint256) {
        return auctions.length;
    }
    
    /**
     * @notice Returns the auction address at a specific index
     * @param index The index in the auctions array
     * @return The auction address
     */
    function getAuction(uint256 index) external view returns (address) {
        require(index < auctions.length, "Index out of bounds");
        return auctions[index];
    }
    
    /**
     * @notice Returns all deployed auction addresses
     * @return Array of all auction addresses
     */
    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }
}
