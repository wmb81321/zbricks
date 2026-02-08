// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AuctionManager.sol";

/**
 * @title AuctionFactory
 * @notice Factory contract for deploying independent AuctionManager instances
 * @dev Owner-controlled factory that creates new auction contracts with configurable parameters
 */
contract AuctionFactory is Ownable {
    
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
        uint256 timestamp
    );
    
    /**
     * @notice Constructs the AuctionFactory
     * @param initialOwner The address that will own the factory
     */
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @notice Creates a new independent auction instance
     * @param _admin Owner address for the new auction
     * @param _paymentToken Payment token contract (e.g., USDC)
     * @param _nftContract NFT contract to auction
     * @param _tokenId Token ID of the NFT (must already be transferred to the new auction address)
     * @param _phaseDurations Array of 3 phase durations (each >= 1 day)
     * @param _floorPrice Minimum first bid amount
     * @param _minBidIncrementPercent Minimum bid increment percentage (1-100)
     * @param _enforceMinIncrement Whether to enforce the minimum increment
     * @return The address of the newly deployed auction
     */
    function createAuction(
        address _admin,
        address _paymentToken,
        address _nftContract,
        uint256 _tokenId,
        uint256[4] memory _phaseDurations,
        uint256 _floorPrice,
        uint256 _minBidIncrementPercent,
        bool _enforceMinIncrement
    ) external onlyOwner returns (address) {
        // Deploy new AuctionManager instance
        AuctionManager newAuction = new AuctionManager(
            _admin,
            _paymentToken,
            _nftContract,
            _tokenId,
            _phaseDurations,
            _floorPrice,
            _minBidIncrementPercent,
            _enforceMinIncrement
        );
        
        address auctionAddress = address(newAuction);
        
        // Store auction address
        auctions.push(auctionAddress);
        isAuction[auctionAddress] = true;
        
        // Emit comprehensive event with all parameters
        emit AuctionCreated(
            auctionAddress,
            _nftContract,
            _tokenId,
            _paymentToken,
            _admin,
            _phaseDurations,
            _floorPrice,
            _minBidIncrementPercent,
            _enforceMinIncrement,
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
