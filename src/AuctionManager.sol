// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./HouseNFT.sol";

/**
 * @title AuctionManager
 * @notice Manages a multi-phase continuous clearing auction for a single NFT with flexible payment token bidding
 * @dev Implements flexible bid management with withdrawal, automatic NFT phase sync, and emergency controls
 * @dev Deployed via AuctionFactory for independent auction instances
 */
contract AuctionManager is Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    // ============ Immutable Storage ============
    
    /// @notice Payment token contract for bidding (e.g., USDC, DAI)
    IERC20 public immutable paymentToken;
    
    /// @notice NFT contract being auctioned
    IERC721 public immutable nftContract;
    
    /// @notice Token ID of the NFT being auctioned
    uint256 public immutable tokenId;
    
    /// @notice Minimum first bid amount (floor price)
    uint256 public immutable floorPrice;
    
    /// @notice Minimum bid increment as percentage (e.g., 5 = 5%)
    uint256 public immutable minBidIncrementPercent;
    
    /// @notice Whether to enforce minimum bid increment
    bool public immutable enforceMinIncrement;
    
    /// @notice Participation fee required to place first bid (can be 0)
    uint256 public immutable participationFee;
    
    /// @notice Treasury address that receives participation fees and winning bid
    address public immutable treasury;
    
    // ============ Mutable Storage ============
    
    /// @notice Current auction phase (0-2)
    uint8 public currentPhase;
    
    /// @notice Current highest bidder
    address public currentLeader;
    
    /// @notice Current highest bid amount
    uint256 public currentHighBid;
    
    /// @notice Winner of the auction (set upon finalization)
    address public winner;
    
    /// @notice Whether the auction has been finalized
    bool public finalized;
    
    /// @notice Whether proceeds have been withdrawn by owner
    bool private proceedsWithdrawn;
    
    /// @notice Set of all unique bidders
    EnumerableSet.AddressSet private bidders;
    
    /// @notice Mapping of bidder address to their total bid amount
    mapping(address => uint256) public userBids;
    
    /// @notice Tracks whether a bidder has paid the participation fee
    mapping(address => bool) public hasPaid;
    
    /// @notice Total participation fees collected
    uint256 public totalParticipationFees;
    
    /// @notice Information for each auction phase
    mapping(uint8 => PhaseInfo) public phases;
    
    // ============ Structs ============
    
    struct PhaseInfo {
        uint256 minDuration;  // Minimum duration in seconds
        uint256 startTime;    // Timestamp when phase started
        address leader;       // Leader at end of phase
        uint256 highBid;      // Highest bid at end of phase
        bool revealed;        // Whether phase has been revealed
    }
    
    // ============ Events ============
    
    event BidPlaced(address indexed bidder, uint256 incrementalAmount, uint256 newTotalBid, uint8 indexed phase);
    event BidWithdrawn(address indexed bidder, uint256 amount, uint8 indexed phase);
    event ParticipationFeePaid(address indexed bidder, uint256 amount, uint8 indexed phase);
    event PhaseAdvanced(uint8 indexed phase, uint256 timestamp);
    event AuctionFinalized(address indexed winner, uint256 amount);
    event ProceedsWithdrawn(uint256 amount);
    event EmergencyNFTWithdrawal(uint256 indexed tokenId, address indexed to);
    
    // ============ Constructor ============
    
    /**
     * @notice Constructs a single-auction manager with configurable parameters
     * @param _initialOwner Owner address with control privileges (receives ownership)
     * @param _paymentToken Payment token contract address (e.g., USDC)
     * @param _nftContract NFT contract address to auction
     * @param _tokenId Token ID of the NFT (must already be owned by this contract)
     * @param _phaseDurations Array of 3 phase durations in seconds (each must be > 0)
     * @param _floorPrice Minimum first bid amount
     * @param _minBidIncrementPercent Minimum bid increment as percentage (1-100)
     * @param _enforceMinIncrement Whether to enforce the minimum increment
     * @param _participationFee One-time fee required to participate (can be 0)
     * @param _treasury Address that receives participation fees and winning bid (cannot be 0)
     */
    constructor(
        address _initialOwner,
        address _paymentToken,
        address _nftContract,
        uint256 _tokenId,
        uint256[4] memory _phaseDurations,
        uint256 _floorPrice,
        uint256 _minBidIncrementPercent,
        bool _enforceMinIncrement,
        uint256 _participationFee,
        address _treasury
    ) Ownable(_initialOwner) {
        require(_paymentToken != address(0), "Invalid payment token");
        require(_nftContract != address(0), "Invalid NFT address");
        require(_floorPrice > 0, "Floor price must be > 0");
        require(_minBidIncrementPercent > 0 && _minBidIncrementPercent <= 100, "Invalid increment percent");
        require(_treasury != address(0), "Invalid treasury address");
        
        // Validate NFT ownership
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == address(this),
            "Contract must own NFT"
        );
        
        paymentToken = IERC20(_paymentToken);
        nftContract = IERC721(_nftContract);
        tokenId = _tokenId;
        floorPrice = _floorPrice;
        minBidIncrementPercent = _minBidIncrementPercent;
        enforceMinIncrement = _enforceMinIncrement;
        participationFee = _participationFee;
        treasury = _treasury;
        
        // Validate and initialize phase durations (can be any value in seconds)
        for (uint8 i = 0; i < 3; i++) {
            require(_phaseDurations[i] > 0, "Duration must be > 0");
            phases[i].minDuration = _phaseDurations[i];
        }
        
        // Start phase 0
        phases[0].startTime = block.timestamp;
        currentHighBid = 0; // Will be enforced via floorPrice in placeBid
    }
    
    // ============ Bidding Functions ============
    
    /**
     * @notice Places an incremental bid in the current auction phase
     * @dev Users can increase their own bids multiple times. Total bid must meet requirements.
     * @dev First-time bidders must pay the participation fee if configured (non-refundable)
     * @param amount The incremental amount to add to user's current bid
     */
    function placeBid(uint256 amount) external whenNotPaused nonReentrant {
        require(!finalized, "Auction ended");
        require(currentPhase <= 2, "Bidding closed");
        require(amount > 0, "Amount must be > 0");
        
        // Handle participation fee for first-time bidders
        if (participationFee > 0 && !hasPaid[msg.sender]) {
            // Transfer participation fee to treasury (non-refundable)
            require(
                paymentToken.transferFrom(msg.sender, treasury, participationFee),
                "Participation fee transfer failed"
            );
            
            // Mark as paid and update counter
            hasPaid[msg.sender] = true;
            totalParticipationFees += participationFee;
            
            emit ParticipationFeePaid(msg.sender, participationFee, currentPhase);
        }
        
        // Calculate user's new total bid
        uint256 newTotalBid = userBids[msg.sender] + amount;
        
        // Validate floor price
        require(newTotalBid >= floorPrice, "Bid below floor price");
        
        // Validate minimum increment (if enforced and user is not current leader)
        if (enforceMinIncrement && msg.sender != currentLeader && currentHighBid > 0) {
            uint256 minRequired = currentHighBid + (currentHighBid * minBidIncrementPercent / 100);
            require(newTotalBid >= minRequired, "Bid increment too low");
        }
        
        // Transfer incremental amount from bidder
        require(
            paymentToken.transferFrom(msg.sender, address(this), amount),
            "Payment transfer failed"
        );
        
        // Update user's total bid
        userBids[msg.sender] = newTotalBid;
        
        // Add to bidders set (no-op if already exists)
        bidders.add(msg.sender);
        
        // Recalculate leader
        _updateLeader();
        
        emit BidPlaced(msg.sender, amount, newTotalBid, currentPhase);
    }
    
    /**
     * @notice Allows user to withdraw their full bid before auction finalization
     * @dev Useful for users who want to exit and re-bid with a different amount
     */
    function withdrawBid() external whenNotPaused nonReentrant {
        require(!finalized, "Auction ended - cannot withdraw");
        require(userBids[msg.sender] > 0, "No bid to withdraw");
        
        uint256 bidAmount = userBids[msg.sender];
        
        // Clear user's bid
        userBids[msg.sender] = 0;
        
        // Remove from bidders set
        bidders.remove(msg.sender);
        
        // Transfer funds back
        require(
            paymentToken.transfer(msg.sender, bidAmount),
            "Payment transfer failed"
        );
        
        // Recalculate leader after withdrawal
        _updateLeader();
        
        emit BidWithdrawn(msg.sender, bidAmount, currentPhase);
    }
    
    /**
     * @notice Internal function to recalculate current leader and highest bid
     * @dev Iterates through all bidders to find the highest bid
     */
    function _updateLeader() internal {
        address newLeader = address(0);
        uint256 newHighBid = 0;
        
        uint256 length = bidders.length();
        for (uint256 i = 0; i < length; i++) {
            address bidder = bidders.at(i);
            uint256 bid = userBids[bidder];
            
            if (bid > newHighBid) {
                newHighBid = bid;
                newLeader = bidder;
            }
        }
        
        currentLeader = newLeader;
        currentHighBid = newHighBid;
    }
    
    // ============ Phase Management ============
    
    /**
     * @notice Advances to the next auction phase (owner only)
     * @dev Locks current phase data, progresses auction phase, and syncs NFT metadata phase
     */
    function advancePhase() external onlyOwner whenNotPaused {
        require(currentPhase < 2, "Cannot advance beyond phase 2");
        require(!finalized, "Auction ended");
        
        PhaseInfo storage currentPhaseInfo = phases[currentPhase];
        
        // Check minimum duration has elapsed
        require(
            block.timestamp >= currentPhaseInfo.startTime + currentPhaseInfo.minDuration,
            "Duration not met"
        );
        
        // Lock current phase data
        currentPhaseInfo.leader = currentLeader;
        currentPhaseInfo.highBid = currentHighBid;
        currentPhaseInfo.revealed = true;
        
        // Advance to next phase
        currentPhase++;
        phases[currentPhase].startTime = block.timestamp;
        
        // Attempt to sync NFT metadata phase
        _syncNFTPhase(currentPhase);
        
        emit PhaseAdvanced(currentPhase, block.timestamp);
    }
    
    /**
     * @notice Finalizes the auction and transfers NFT to winner (owner only)
     * @dev Requires phase 2 complete, locks final data, transfers NFT, and syncs to phase 3
     */
    function finalizeAuction() external onlyOwner {
        require(currentPhase == 2, "Must be at phase 2");
        require(!finalized, "Already finalized");
        require(currentLeader != address(0), "No winner");
        
        // Check minimum duration for phase 2 has elapsed
        PhaseInfo storage phase2Info = phases[2];
        require(
            block.timestamp >= phase2Info.startTime + phase2Info.minDuration,
            "Phase 2 duration not met"
        );
        
        // Lock phase 2 data
        phases[2].leader = currentLeader;
        phases[2].highBid = currentHighBid;
        phases[2].revealed = true;
        
        // Store winner
        winner = currentLeader;
        
        // Mark as finalized
        finalized = true;
        
        // Transfer NFT to winner
        nftContract.safeTransferFrom(address(this), winner, tokenId);
        
        // Sync NFT to final phase (phase 3)
        _syncNFTPhase(3);
        
        emit AuctionFinalized(winner, currentHighBid);
    }
    
    /**
     * @notice Internal function to sync NFT metadata phase if supported
     * @dev Attempts to call advancePhase on HouseNFT, silently fails if not supported
     * @param phase The phase number to advance to
     */
    function _syncNFTPhase(uint8 phase) internal {
        try HouseNFT(address(nftContract)).advancePhase(tokenId, phase) {
            // Successfully synced NFT phase
        } catch {
            // NFT doesn't support phase advancement or caller is not controller
            // This is acceptable - admin can manually sync if needed
        }
    }
    
    // ============ Owner Functions ============
    
    /**
     * @notice Withdraws auction proceeds to treasury (once after finalization)
     * @dev Only the winning bid goes to treasury; participation fees already sent during bidding
     */
    function withdrawProceeds() external onlyOwner nonReentrant {
        require(finalized, "Not finalized");
        require(!proceedsWithdrawn, "Already withdrawn");
        
        uint256 amount = currentHighBid;
        require(amount > 0, "No proceeds");
        
        proceedsWithdrawn = true;
        
        require(paymentToken.transfer(treasury, amount), "Payment transfer failed");
        
        emit ProceedsWithdrawn(amount);
    }
    
    /**
     * @notice Emergency function to withdraw funds to owner
     * @dev Can be called anytime by owner for emergency situations
     * @dev Allows owner to recover funds if needed (e.g., treasury issues, contract problems)
     */
    function emergencyWithdrawFunds() external onlyOwner nonReentrant {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        
        require(paymentToken.transfer(owner(), balance), "Payment transfer failed");
    }
    
    /**
     * @notice Emergency function to withdraw NFT to owner
     * @dev Can only be called after finalization or in emergency (when paused)
     * @dev Useful if winner cannot receive NFT or other emergencies
     */
    function emergencyWithdrawNFT() external onlyOwner {
        require(finalized || paused(), "Must be finalized or paused");
        
        nftContract.safeTransferFrom(address(this), owner(), tokenId);
        
        emit EmergencyNFTWithdrawal(tokenId, owner());
    }
    
    /**
     * @notice Pauses bidding, withdrawals, and phase advancement (emergency only)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpauses the auction
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Returns all unique bidders in the auction
     * @return Array of bidder addresses
     */
    function getBidders() public view returns (address[] memory) {
        return bidders.values();
    }
    
    /**
     * @notice Returns the number of unique bidders
     * @return Number of bidders
     */
    function getBidderCount() public view returns (uint256) {
        return bidders.length();
    }
    
    /**
     * @notice Returns information about the current phase
     */
    function getCurrentPhaseInfo() external view returns (
        uint256 minDuration,
        uint256 startTime,
        address leader,
        uint256 highBid,
        bool revealed
    ) {
        PhaseInfo storage info = phases[currentPhase];
        return (info.minDuration, info.startTime, info.leader, info.highBid, info.revealed);
    }
    
    /**
     * @notice Checks if the auction is still active
     */
    function isAuctionActive() external view returns (bool) {
        return !finalized;
    }
    
    /**
     * @notice Returns time remaining in current phase
     */
    function getTimeRemaining() external view returns (uint256) {
        PhaseInfo storage info = phases[currentPhase];
        uint256 elapsed = block.timestamp - info.startTime;
        
        if (elapsed >= info.minDuration) {
            return 0;
        }
        
        return info.minDuration - elapsed;
    }
    
    /**
     * @notice Returns current leader and highest bid
     */
    function getCurrentLeaderAndBid() external view returns (address leader, uint256 highBid) {
        return (currentLeader, currentHighBid);
    }
    
    /**
     * @notice Returns complete information for a specific phase
     */
    function getPhaseInfo(uint8 phase) external view returns (
        uint256 minDuration,
        uint256 startTime,
        address leader,
        uint256 highBid,
        bool revealed
    ) {
        require(phase <= 2, "Invalid phase");
        PhaseInfo storage info = phases[phase];
        return (info.minDuration, info.startTime, info.leader, info.highBid, info.revealed);
    }
    
    /**
     * @notice Returns auction state summary
     */
    function getAuctionState() external view returns (
        uint8 _currentPhase,
        address _currentLeader,
        uint256 _currentHighBid,
        bool _finalized,
        bool _biddingOpen
    ) {
        return (
            currentPhase,
            currentLeader,
            currentHighBid,
            finalized,
            !finalized && currentPhase <= 2
        );
    }
    
    // ============ ERC721 Receiver ============
    
    /**
     * @notice Handles receipt of an ERC721 token
     * @dev Required to receive the NFT mint
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
