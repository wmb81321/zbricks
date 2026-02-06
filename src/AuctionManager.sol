// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HouseNFT.sol";

/**
 * @title AuctionManager
 * @notice Manages a multi-phase continuous clearing auction for a single house NFT with USDC bidding
 * @dev Implements Checks-Effects-Interactions pattern, pull-based refunds, and emergency pause
 */
contract AuctionManager is Pausable, ReentrancyGuard, IERC721Receiver {
    // ============ Immutable Storage ============
    
    /// @notice USDC token contract for bidding
    IERC20 public immutable usdc;
    
    /// @notice House NFT being auctioned
    HouseNFT public immutable houseNFT;
    
    /// @notice Fixed token ID for the house NFT
    uint256 private constant TOKEN_ID = 1;
    
    // ============ Mutable Storage ============
    
    /// @notice Admin address with control privileges
    address public admin;
    
    /// @notice Current auction phase (0-3)
    uint8 public currentPhase;
    
    /// @notice Current highest bidder
    address public currentLeader;
    
    /// @notice Current highest bid amount
    uint256 public currentHighBid;
    
    /// @notice Whether the auction has been finalized
    bool public finalized;
    
    /// @notice Whether proceeds have been withdrawn by admin
    bool private proceedsWithdrawn;
    
    /// @notice Mapping of bidder address to refund balance
    mapping(address => uint256) public refundBalance;
    
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
    
    event BidPlaced(uint8 indexed phase, address indexed bidder, uint256 amount);
    event PhaseAdvanced(uint8 indexed phase, uint256 timestamp);
    event AuctionFinalized(address indexed winner, uint256 amount);
    event RefundWithdrawn(address indexed bidder, uint256 amount);
    event ProceedsWithdrawn(uint256 amount);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
    
    // ============ Modifiers ============
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    // ============ Constructor ============
    
    /**
     * @notice Constructs the auction manager with configurable phase durations
     * @param _usdc USDC token contract address
     * @param _houseNFT HouseNFT contract address
     * @param _admin Admin address for control functions
     * @param _phaseDurations Array of 4 phase durations (must each be >= 24 hours)
     */
    constructor(
        address _usdc,
        address _houseNFT,
        address _admin,
        uint256[4] memory _phaseDurations
    ) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_houseNFT != address(0), "Invalid NFT address");
        require(_admin != address(0), "Invalid admin address");
        
        usdc = IERC20(_usdc);
        houseNFT = HouseNFT(_houseNFT);
        admin = _admin;
        
        // Validate and initialize phase durations (minimum 24 hours each)
        for (uint8 i = 0; i < 4; i++) {
            require(_phaseDurations[i] >= 24 hours, "Duration must be >= 24 hours");
            phases[i].minDuration = _phaseDurations[i];
        }
        
        // Start phase 0
        phases[0].startTime = block.timestamp;
    }
    
    // ============ Bidding Functions ============
    
    /**
     * @notice Places a bid in the current auction phase
     * @dev Implements Checks-Effects-Interactions pattern to prevent reentrancy
     * @param amount The bid amount in USDC (must be > currentHighBid)
     */
    function placeBid(uint256 amount) external whenNotPaused nonReentrant {
        // ===== CHECKS =====
        require(!finalized, "Auction ended");
        require(currentPhase <= 2, "Bidding closed");
        require(amount > currentHighBid, "Bid too low");
        
        // ===== EFFECTS =====
        // Update refund for previous leader
        if (currentLeader != address(0)) {
            refundBalance[currentLeader] += currentHighBid;
        }
        
        // Update current leader and bid
        currentLeader = msg.sender;
        currentHighBid = amount;
        
        emit BidPlaced(currentPhase, msg.sender, amount);
        
        // ===== INTERACTIONS =====
        // Transfer USDC from bidder (external call last)
        require(usdc.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
    }
    
    /**
     * @notice Withdraws refund balance for caller (pull-payment pattern)
     * @dev Can be called even when paused or after finalization for user fund safety
     */
    function withdraw() external nonReentrant {
        uint256 amount = refundBalance[msg.sender];
        require(amount > 0, "No refund");
        
        // Clear balance before transfer (reentrancy protection)
        refundBalance[msg.sender] = 0;
        
        require(usdc.transfer(msg.sender, amount), "USDC transfer failed");
        
        emit RefundWithdrawn(msg.sender, amount);
    }
    
    // ============ Phase Management ============
    
    /**
     * @notice Advances to the next auction phase (admin only)
     * @dev Locks current phase data and progresses auction phase
     * @dev Admin must manually advance NFT metadata separately using HouseNFT.advancePhase()
     */
    function advancePhase() external onlyAdmin whenNotPaused {
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
        
        emit PhaseAdvanced(currentPhase, block.timestamp);
    }
    
    /**
     * @notice Finalizes the auction and transfers NFT to winner (admin only)
     * @dev Requires phase 2 complete, locks final data, and transfers to winner
     * @dev Admin must manually advance NFT to phase 3 after finalization
     */
    function finalizeAuction() external onlyAdmin {
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
        
        // Mark as finalized
        finalized = true;
        
        // Transfer NFT to winner
        houseNFT.safeTransferFrom(address(this), currentLeader, TOKEN_ID);
        
        emit AuctionFinalized(currentLeader, currentHighBid);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Withdraws auction proceeds to admin (once after finalization)
     * @dev Only the final winner's bid is proceeds; all others are refunded
     */
    function withdrawProceeds() external onlyAdmin nonReentrant {
        require(finalized, "Not finalized");
        require(!proceedsWithdrawn, "Already withdrawn");
        
        uint256 amount = currentHighBid;
        require(amount > 0, "No proceeds");
        
        proceedsWithdrawn = true;
        
        require(usdc.transfer(admin, amount), "USDC transfer failed");
        
        emit ProceedsWithdrawn(amount);
    }
    
    /**
     * @notice Transfers admin role to a new address
     * @param newAdmin The new admin address
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin");
        
        address oldAdmin = admin;
        admin = newAdmin;
        
        emit AdminTransferred(oldAdmin, newAdmin);
    }
    
    /**
     * @notice Pauses bidding and phase advancement (emergency only)
     * @dev Does NOT pause withdrawals for user fund safety
     */
    function pause() external onlyAdmin {
        _pause();
    }
    
    /**
     * @notice Unpauses the auction
     */
    function unpause() external onlyAdmin {
        _unpause();
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Returns information about the current phase
     * @return minDuration Minimum duration of current phase
     * @return startTime When current phase started
     * @return leader Leader at end of phase (if revealed)
     * @return highBid Highest bid at end of phase (if revealed)
     * @return revealed Whether phase has been revealed
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
     * @notice Returns the refund balance for a given bidder
     * @param bidder The bidder address
     * @return The refund balance in USDC
     */
    function getBidderRefund(address bidder) external view returns (uint256) {
        return refundBalance[bidder];
    }
    
    /**
     * @notice Checks if the auction is still active
     * @return True if auction is active, false if finalized
     */
    function isAuctionActive() external view returns (bool) {
        return !finalized;
    }
    
    /**
     * @notice Returns time remaining in current phase
     * @return Seconds remaining (0 if duration already met)
     */
    function getTimeRemaining() external view returns (uint256) {
        PhaseInfo storage info = phases[currentPhase];
        uint256 elapsed = block.timestamp - info.startTime;
        
        if (elapsed >= info.minDuration) {
            return 0;
        }
        
        return info.minDuration - elapsed;
    }
    
    // ============ Metadata Helper Functions ============
    
    /**
     * @notice Returns current leader and highest bid for metadata preparation
     * @dev Useful for admin to create next phase metadata with real auction data
     * @return leader Current highest bidder address
     * @return highBid Current highest bid amount
     */
    function getCurrentLeaderAndBid() external view returns (address leader, uint256 highBid) {
        return (currentLeader, currentHighBid);
    }
    
    /**
     * @notice Returns complete information for a specific phase
     * @dev Used by admin to gather historical phase data for metadata
     * @param phase The phase number (0-3)
     * @return minDuration Minimum duration configured for phase
     * @return startTime Timestamp when phase started
     * @return leader Winner of that phase
     * @return highBid Winning bid of that phase
     * @return revealed Whether phase has been completed
     */
    function getPhaseInfo(uint8 phase) external view returns (
        uint256 minDuration,
        uint256 startTime,
        address leader,
        uint256 highBid,
        bool revealed
    ) {
        require(phase <= 3, "Invalid phase");
        PhaseInfo storage info = phases[phase];
        return (info.minDuration, info.startTime, info.leader, info.highBid, info.revealed);
    }
    
    /**
     * @notice Returns auction state summary for metadata
     * @return _currentPhase Current phase number
     * @return _currentLeader Current highest bidder
     * @return _currentHighBid Current highest bid
     * @return _finalized Whether auction is finalized
     * @return _biddingOpen Whether bidding is currently allowed
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
