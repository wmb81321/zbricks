# Contract Reference

Complete API documentation for the ZBrick Auction System contracts.

> 📖 **Last Updated**: February 9, 2026  
> 📦 **Contract Addresses**: See [deployments/addresses.json](deployments/addresses.json)
> 🏭 **Architecture**: Factory-based multi-auction system

## Table of Contents

- [HouseNFT](#housenft)
- [AuctionManager](#auctionmanager)
- [AuctionFactory](#auctionfactory)
- [Deployed Addresses](#deployed-addresses)

---

## HouseNFT

Multi-token ERC721 representing properties with phase-based metadata reveals. Each token has independent metadata URIs that update as auction phases progress.

**Collection Name**: ZBRICKS  
**Symbol**: ZBR  
**Inherits:** ERC721  
**Architecture**: Supports factory-based auction creation with trusted factory system

### Deployed Addresses

| Network | Address | Explorer |
|---------|---------|----------|
| **Base Sepolia** | `0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6` | [View](https://base-sepolia.blockscout.com/address/0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6) |
| **Base Mainnet** | `0x335845ef4f622145d963c9f39d6ff1b60757fee4` | [View](https://base.blockscout.com/address/0x335845ef4f622145d963c9f39d6ff1b60757fee4) |
| **Arc Testnet** | `0x335845ef4f622145d963c9f39d6ff1b60757fee4` | [View](https://testnet.arcscan.app/address/0x335845ef4f622145d963c9f39d6ff1b60757fee4) |

### Constructor

```solidity
constructor(
    string memory name,
    string memory symbol
) ERC721(name, symbol)
```

**Description**: Initializes the HouseNFT contract with name and symbol.

**Parameters:**
- `name`: Name of the NFT collection ("ZBRICKS")
- `symbol`: Symbol of the NFT collection ("ZBR")

**Example:**
```solidity
HouseNFT nft = new HouseNFT("ZBRICKS", "ZBR");
```

### State Variables

```solidity
address public admin;                                    // Admin with persistent control
address public trustedFactory;                          // Factory allowed to set controllers
mapping(uint256 => uint8) public tokenPhase;            // Current phase per token (0-3)
mapping(uint256 => address) public tokenController;     // Controller per token (AuctionManager)
mapping(uint256 => mapping(uint8 => string)) public tokenPhaseURIs;  // URIs per token per phase
uint256 private _tokenIdCounter;                        // Auto-incrementing token ID counter
```

**Description:**
- `admin`: Deployer address with control over metadata and admin functions
- `trustedFactory`: Factory contract that can set controllers (set once, immutable)
- `tokenPhase`: Current phase (0-3) for each token
- `tokenController`: AuctionManager address that can advance phases for specific token
- `tokenPhaseURIs`: Metadata URIs stored as `tokenPhaseURIs[tokenId][phase]`
- `_tokenIdCounter`: Internal counter for auto-incrementing token IDs (starts at 1)

### Functions

#### mintTo
```solidity
function mintTo(address recipient) external onlyAdmin returns (uint256)
```

**Description**: Mints a new house NFT with auto-incrementing token ID.

**Access**: Admin only  
**Parameters:**
- `recipient`: Address to receive the NFT

**Returns**: Token ID of the minted NFT (auto-increments: 1, 2, 3...)

**Example:**
```solidity
uint256 tokenId = nft.mintTo(auctionManagerAddress);
// Returns: 1 (first mint), 2 (second mint), etc.
```

```bash
cast send <NFT_ADDRESS> "mintTo(address)" <RECIPIENT_ADDRESS> \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### setController
```solidity
function setController(uint256 tokenId, address controller) external
```

**Description**: Sets the controller address for a specific token (typically the AuctionManager). Can be called by admin OR trusted factory.

**Access**: Admin or Trusted Factory  
**Parameters:**
- `tokenId`: Token ID to set controller for
- `controller`: Address of the controller (cannot be zero address)

**Requirements:**
- Caller must be admin OR trustedFactory
- Controller address must not be zero

**Example:**
```solidity
// Called by admin
nft.setController(1, auctionManagerAddress);

// Or called by factory during auction creation
factory.createAuction(...); // Factory calls setController internally
```

```bash
cast send <NFT_ADDRESS> "setController(uint256,address)" 1 <AUCTION_ADDRESS> \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### setFactory
```solidity
function setFactory(address _factory) external onlyAdmin
```

**Description**: Sets the trusted factory contract that can call setController(). Can only be called once when trustedFactory is address(0).

**Access**: Admin only  
**Parameters:**
- `_factory`: Factory contract address

**Requirements:**
- Can only be called once (when trustedFactory is zero address)
- Factory address must not be zero
- Only admin can call

**Security:**
- Factory address is immutable after first set
- Enables factory-based auction creation
- Factory can set controllers but not modify metadata

**Example:**
```solidity
// Set factory once during infrastructure deployment
nft.setFactory(factoryAddress);

// Cannot be called again - will revert with "Factory already set"
```

```bash
cast send <NFT_ADDRESS> "setFactory(address)" <FACTORY_ADDRESS> \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### setPhaseURIs
```solidity
function setPhaseURIs(uint256 tokenId, string[4] memory uris) external onlyAdmin
```

**Description**: Sets all 4 phase metadata URIs for a token at once.

**Access**: Admin only  
**Parameters:**
- `tokenId`: Token ID to set URIs for
- `uris`: Array of 4 metadata URIs for phases 0-3

**Example:**
```solidity
string[4] memory uris = [
    "ipfs://Qm.../phase0.json",
    "ipfs://Qm.../phase1.json",
    "ipfs://Qm.../phase2.json",
    "ipfs://Qm.../phase3.json"
];
nft.setPhaseURIs(1, uris);
```

---

#### updatePhaseURI
```solidity
function updatePhaseURI(uint256 tokenId, uint8 phase, string memory uri) external onlyAdmin
```

**Description**: Updates a single phase URI for a token.

**Access**: Admin only  
**Parameters:**
- `tokenId`: Token ID to update
- `phase`: Phase number (0-3)
- `uri`: New metadata URI

**Example:**
```solidity
nft.updatePhaseURI(1, 0, "ipfs://Qm.../new-phase0.json");
```

---

#### advancePhase
```solidity
function advancePhase(uint256 tokenId) external
```

**Description**: Advances to the next metadata phase for the token.

**Access**: Admin OR token controller  
**Parameters:**
- `tokenId`: Token ID to advance

**Phases:**
- 0 → 1 (Initial → Active Bidding)
- 1 → 2 (Active → Grace Period)  
- 2 → 3 (Grace → Finalized)

**Example:**
```solidity
nft.advancePhase(1); // Advance token 1 to next phase
```

---

#### tokenURI
```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory)
```

**Description**: Returns the current metadata URI based on the token's phase.

**Access**: Public (view)  
**Parameters:**
- `tokenId`: Token ID to query

**Returns**: Current metadata URI

**Example:**
```solidity
string memory uri = nft.tokenURI(1);
```

```bash
cast call <NFT_ADDRESS> "tokenURI(uint256)" 1 --rpc-url base_sepolia
```

### Events

```solidity
event FactorySet(address indexed factory);
event ControllerSet(uint256 indexed tokenId, address indexed controller);
event PhaseURIUpdated(uint256 indexed tokenId, uint8 indexed phase, string uri);
event PhaseAdvanced(uint256 indexed tokenId, uint8 indexed newPhase, address indexed caller);
```

**Event Descriptions:**
- `FactorySet`: Emitted when trusted factory is set (one-time only)
- `ControllerSet`: Emitted when controller is set for a token
- `PhaseURIUpdated`: Emitted when metadata URI is updated for a phase
- `PhaseAdvanced`: Emitted when token advances to next phase

---

## AuctionManager

Manages a Continuous Clearing Auction (CCA) with multiple bidding phases for a specific house NFT. Bidders can incrementally add to their bids, and only the final winner pays.

| Network | Address |
|---------|---------|
| Base Sepolia | [0x3347f6a853e04281daa0314f49a76964f010366f](https://sepolia.basescan.org/address/0x3347f6a853e04281daa0314f49a76964f010366f) |
| Base Mainnet | [0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca](https://basescan.org/address/0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca) |
| Arc Testnet | [0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca](https://testnet.arcscan.io/address/0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca) |

### Constructor

```solidity
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
) Ownable(_initialOwner)
```

**Description**: Initializes a Continuous Clearing Auction for a single NFT with participation fee and treasury.

**Parameters:**
- `_initialOwner`: Owner address with control privileges
- `_paymentToken`: Payment token contract address (e.g., USDC, DAI)
- `_nftContract`: NFT contract address being auctioned
- `_tokenId`: Token ID of the NFT (must already be owned by this contract)
- `_phaseDurations`: Array of 3 phase durations in seconds (each must be > 0)
- `_floorPrice`: Minimum first bid amount (e.g., 1000000000 = 1,000 USDC)
- `_minBidIncrementPercent`: Minimum bid increment percentage (1-100, e.g., 5 = 5%)
- `_enforceMinIncrement`: Whether to enforce the minimum increment
- `_participationFee`: One-time fee to participate (can be 0, sent to treasury)
- `_treasury`: Address that receives participation fees and winning bid (cannot be address(0))

**Requirements:** 
- NFT must be owned by this contract before deployment
- Each phase duration must be > 0 seconds (no minimum)
- Treasury address cannot be zero address
- Contract validates NFT ownership in constructor

**Example:**
```solidity
uint256[4] memory durations = [86400, 86400, 86400, 0]; // 3 phases of 1 day each
AuctionManager auction = new AuctionManager(
    ownerAddress,
    usdcAddress,
    nftAddress,
    1,                    // tokenId
    durations,
    1000000000,          // 1,000 USDC floor price
    5,                   // 5% increment
    true,                // Enforce increment
    10000000,            // 10 USDC participation fee
    treasuryAddress      // Treasury receives fees and winning bid
);
```    {
      "name": "123 Main Street - Complete Information",
      "description": "All property information revealed. Final bidding phase active.",
      "image": "ipfs://QmPhase2Image/complete.jpg",
      "external_url": "https://zbrick.io/auction/1",
      "animation_url": "ipfs://QmPhase2Video/walkthrough.mp4",
      "attributes": [
        {"trait_type": "Address", "value": "123 Main Street"},
        {"trait_type": "City", "value": "Springfield"},
        {"trait_type": "State", "value": "IL"},
        {"trait_type": "Square Feet", "value": "2000"},
        {"trait_type": "Year Built", "value": "2015"},
        {"trait_type": "Appraised Value", "value": "$350,000"},
        {"trait_type": "Monthly Rental Income", "value": "$2,500"},
        {"trait_type": "Property Tax", "value": "$4,200/year"},
        {"trait_type": "HOA Fees", "value": "$0"},
        {"trait_type": "Condition", "value": "Excellent"},
        {"trait_type": "Phase", "value": "Phase 2"},
        {"trait_type": "Status", "value": "Final Bidding"},
        {"trait_type": "Phase 1 Winner", "value": "0xabcd...ef01"},
        {"trait_type": "Phase 1 High Bid", "value": "7500 USDC"}
      ]
    }s,
    1000000000,          // 1,000 USDC floor price
    5,                   // 5% increment
    true                 // Enforce increment
);
```

### State Variables

```solidity
IERC20 public immutable paymentToken;
IERC721 public immutable nftContract;
uint256 public immutable tokenId;
uint256 public immutable floorPrice;
uint256 public immutable minBidIncrementPercent;
bool public immutable enforceMinIncrement;
uint256 public immutable participationFee;     // One-time fee to participate
address public immutable treasury;              // Receives fees and winning bid

uint8 public currentPhase;           // Current phase (0-2)
address public currentLeader;        // Current highest bidder
uint256 public currentHighBid;       // Current highest bid amount
address public winner;               // Winner (set upon finalization)
bool public finalized;               // Whether auction is finalized

mapping(address => uint256) public userBids;  // Total cumulative bid per user
mapping(address => bool) public hasPaid;      // Tracks who paid participation fee
uint256 public totalParticipationFees;        // Total fees collected
mapping(uint8 => PhaseInfo) public phases;    // Phase information

struct PhaseInfo {
    uint256 minDuration;  // Minimum duration in seconds
    uint256 startTime;    // Timestamp when phase started
    address leader;       // Leader at end of phase
    uint256 highBid;      // Highest bid at end of phase
    bool revealed;        // Whether phase has been revealed
}
```

### Functions

#### placeBid
```solidity
function placeBid(uint256 amount) external whenNotPaused nonReentrant
```

**Description**: Places an incremental bid - adds to your existing bid rather than replacing it. On your first bid, also charges a one-time participation fee (if configured).

**Access**: Public  
**Parameters:**
- `amount`: Incremental amount to add to your current bid (in payment token with proper decimals, e.g., 1000000 = 1 USDC)

**Requirements:**
- Auction not paused or finalized
- Currently in phase 0, 1, or 2 (bidding phases)
- Amount > 0
- Your new total bid (userBids[you] + amount) >= floor price
- If enforceMinIncrement is true and you're not current leader: new total bid >= currentHighBid * (1 + minBidIncrementPercent/100)
- User has approved payment token transfer for (amount + participationFee if first bid)

**How it works:**
1. **First bid only**: If participationFee > 0 and you haven't paid yet, transfers participation fee to treasury (non-refundable)
2. Your new total bid = existing userBids[you] + amount
3. Contract transfers `amount` tokens from you to contract
4. Leader is recalculated across all bidders
5. Emits ParticipationFeePaid event on first bid (if fee > 0)
6. Only the final winner pays - losers can withdraw their bid (not the fee)

**Example:**
```solidity
// Assuming participationFee = 10 USDC (10000000)
// First bid: Approve bid + fee
IERC20(paymentToken).approve(auctionAddress, 5010000000); // 5,010 USDC
auction.placeBid(5000000000); // 5,000 USDC bid
// Automatically charges 10 USDC fee to treasury
// userBids[you] = 5,000 USDC (fee not included in bid amount)
// hasPaid[you] = true

// Later, increase your bid (no additional fee)
IERC20(paymentToken).approve(auctionAddress, 2000000000); // 2,000 USDC
auction.placeBid(2000000000); // userBids[you] = 7,000 USDC total
```

```bash
# Approve payment token
cast send <PAYMENT_TOKEN_ADDRESS> "approve(address,uint256)" <AUCTION_ADDRESS> 5000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia

# Place incremental bid
cast send <AUCTION_ADDRESS> "placeBid(uint256)" 5000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### withdrawBid
```solidity
function withdrawBid() external whenNotPaused nonReentrant
```

**Description**: Allows you to withdraw your FULL bid before auction finalization. Useful for exiting to re-bid elsewhere or change strategy.

**Access**: Public  
**Requirements:**
- Auction not finalized
- You have a bid to withdraw (userBids[msg.sender] > 0)

**How it works:**
1. Retrieves your full userBids[you] amount
2. Sets userBids[you] = 0
3. Removes you from bidders set
4. Transfers full amount back to you
5. Recalculates leader

**Note:** After withdrawal, you can place new bids starting from 0.

**Example:**
```solidity
auction.withdrawBid(); // Get all your funds back
```

```bash
cast send <AUCTION_ADDRESS> "withdrawBid()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### advancePhase
```solidity
function advancePhase() external onlyOwner whenNotPaused
```

**Description**: Advances auction to the next phase (0→1, 1→2). Locks previous phase data and syncs NFT metadata.

**Access**: Owner only  
**Requirements:**
- Current phase < 2 (can advance from 0 or 1)
- Auction not finalized
- Minimum phase duration has elapsed

**How it works:**
1. Locks current phase: saves currentLeader and currentHighBid to phases[currentPhase]
2. Marks phase as revealed
3. Increments currentPhase
4. Sets new phase start time
5. Advances NFT metadata phase

**Example:**
```solidity
auction.advancePhase(); // Phase 0 → Phase 1
```

```bash
cast send <AUCTION_ADDRESS> "advancePhase()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### finalizeAuction
```solidity
function finalizeAuction() external onlyOwner whenNotPaused
```

**Description**: Finalizes the auction after all 3 phases complete. Transfers NFT to winner and advances NFT to final metadata phase.

**Access**: Owner only  
**Requirements:**
- Auction not already finalized
- All phases complete (phase 2 minimum duration elapsed)

**How it works:**
1. Validates all phase durations met
2. Sets winner = currentLeader
3. Transfers NFT to winner
4. Advances NFT to final phase (phase 3)
5. Marks auction as finalized

**Example:**
```solidity
auction.finalizeAuction();
```

```bash
cast send <AUCTION_ADDRESS> "finalizeAuction()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### withdrawProceeds
```solidity
function withdrawProceeds() external onlyOwner nonReentrant
```

**Description**: Allows owner to withdraw winning bid proceeds to treasury after finalization. Participation fees are sent immediately during bidding.

**Access**: Owner only  
**Requirements:**
- Auction finalized
- Winner's bid not yet withdrawn by owner

**Note**: The winning bid is sent to the treasury address configured during construction, not to the owner.

**Example:**
```solidity
auction.withdrawProceeds(); // Sends winning bid to treasury
```

```bash
cast send <AUCTION_ADDRESS> "withdrawProceeds()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### emergencyWithdrawFunds
```solidity
function emergencyWithdrawFunds() external onlyOwner nonReentrant
```

**Description**: Emergency function to withdraw all payment token funds to owner. Can be called anytime.

**Access**: Owner only  
**Requirements:**
- Contract has payment token balance > 0

**Use Cases**:
- Treasury address issues
- Contract problems requiring fund recovery
- Emergency situations

**Example:**
```solidity
auction.emergencyWithdrawFunds(); // Sends all funds to owner
```

```bash
cast send <AUCTION_ADDRESS> "emergencyWithdrawFunds()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

---

#### pause / unpause
```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```

**Description**: Emergency pause/unpause auction operations. When paused, bidding and withdrawals are blocked.

**Access**: Owner only

**Example:**
```solidity
auction.pause();   // Stop all operations
auction.unpause(); // Resume operations
```

```bash
cast send <AUCTION_ADDRESS> "pause()" --private-key $PRIVATE_KEY --rpc-url base_sepolia
cast send <AUCTION_ADDRESS> "unpause()" --private-key $PRIVATE_KEY --rpc-url base_sepolia
```

---

#### emergencyWithdrawNFT
```solidity
function emergencyWithdrawNFT(address to) external onlyOwner
```

**Description**: Emergency function to recover NFT if auction fails or needs cancellation.

**Access**: Owner only  
**Parameters:**
- `to`: Address to send the NFT to

**Example:**
```solidity
auction.emergencyWithdrawNFT(ownerAddress);
```

---

### View Functions

#### getBidders
```solidity
function getBidders() external view returns (address[] memory)
```

**Description**: Returns array of all unique bidders.

**Returns**: Array of bidder addresses

**Example:**
```solidity
address[] memory allBidders = auction.getBidders();
```

```bash
cast call <AUCTION_ADDRESS> "getBidders()" --rpc-url base_sepolia
```

---

#### getBidderCount
```solidity
function getBidderCount() external view returns (uint256)
```

**Description**: Returns total number of unique bidders.

**Returns**: Count of bidders

**Example:**
```solidity
uint256 count = auction.getBidderCount();
```

```bash
cast call <AUCTION_ADDRESS> "getBidderCount()" --rpc-url base_sepolia
```

---

#### getPhaseInfo
```solidity
function getPhaseInfo(uint8 phase) external view returns (
    uint256 minDuration,
    uint256 startTime,
    address leader,
    uint256 highBid,
    bool revealed
)
```

**Description**: Returns detailed information about a specific phase.

**Parameters:**
- `phase`: Phase number (0-2)

**Returns:** Phase information struct

**Example:**
```solidity
(uint256 duration, uint256 start, address leader, uint256 bid, bool revealed) = auction.getPhaseInfo(0);
```

```bash
cast call <AUCTION_ADDRESS> "getPhaseInfo(uint8)" 0 --rpc-url base_sepolia
```

### Events

```solidity
event BidPlaced(address indexed bidder, uint256 incrementalAmount, uint256 newTotalBid, uint8 indexed phase);
event BidWithdrawn(address indexed bidder, uint256 amount, uint8 indexed phase);
event ParticipationFeePaid(address indexed bidder, uint256 amount, uint8 indexed phase);
event PhaseAdvanced(uint8 indexed phase, uint256 timestamp);
event AuctionFinalized(address indexed winner, uint256 amount);
event ProceedsWithdrawn(uint256 amount);
event EmergencyNFTWithdrawal(uint256 indexed tokenId, address indexed to);
```

---

## AuctionFactory

Factory contract for deploying independent AuctionManager instances with shared infrastructure (NFT contract and payment token).

**Architecture**: Deploy once per network, create multiple auctions via `createAuction()`  
**Pattern**: Factory owns NFT temporarily → deploys auction → sets controller → transfers NFT atomically

| Network | Address |
|---------|---------|
| Base Sepolia | [0xd3390e5fec170d7577c850f5687a6542b66a4bbd](https://sepolia.basescan.org/address/0xd3390e5fec170d7577c850f5687a6542b66a4bbd) |
| Base Mainnet | [0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7](https://basescan.org/address/0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7) |
| Arc Testnet | [0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7](https://testnet.arcscan.io/address/0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7) |

### State Variables

```solidity
HouseNFT public immutable nftContract;      // Shared NFT contract for all auctions
IERC20 public immutable paymentToken;        // Shared payment token (e.g., USDC)
address[] public auctions;                   // Array of all created auctions
```

### Constructor

```solidity
constructor(
    address initialOwner,
    address _nftContract,
    address _paymentToken
) Ownable(initialOwner)
```

**Description**: Initializes the factory with shared infrastructure references.

**Parameters:**
- `initialOwner`: Owner address for factory (can deploy auctions)
- `_nftContract`: HouseNFT contract address (immutable)
- `_paymentToken`: Payment token address (immutable, e.g., USDC)

**Requirements:**
- Both addresses must be non-zero
- NFT contract must have factory set as trusted via `setFactory()`

**Example:**
```solidity
AuctionFactory factory = new AuctionFactory(
    ownerAddress,
    nftAddress,      // ZBRICKS NFT
    usdcAddress      // Payment token
);

// After deployment, set factory as trusted in NFT contract
nft.setFactory(address(factory));
```

### Functions

#### createAuction
```solidity
function createAuction(
    address _admin,
    uint256 _tokenId,
    uint256[4] memory _phaseDurations,
    uint256 _floorPrice,
    uint256 _minBidIncrementPercent,
    bool _enforceMinIncrement,
    uint256 _participationFee,
    address _treasury
) external onlyOwner returns (address)
```

**Description**: Deploys a new independent AuctionManager instance using the factory's immutable NFT and payment token. Performs atomic operations: verify ownership → deploy auction → set controller → transfer NFT.

**Access**: Owner only  
**Parameters:**
- `_admin`: Owner address for the new auction (controls phases/pausing)
- `_tokenId`: Token ID to auction (must be owned by factory)
- `_phaseDurations`: Array of 4 phase durations `[phase0, phase1, phase2, 0]` in seconds
- `_floorPrice`: Minimum first bid amount (in payment token decimals)
- `_minBidIncrementPercent`: Min increment percentage (1-100, e.g., 5 = 5%)
- `_enforceMinIncrement`: Whether to enforce minimum increment
- `_participationFee`: One-time fee to participate (can be 0, sent to treasury)
- `_treasury`: Address that receives participation fees and winning bid

**Returns**: Address of the newly deployed AuctionManager

**Requirements:**
- Factory must own the NFT (call `nft.mintTo(factory)` first)
- Factory must be set as trusted in NFT contract
- Treasury address cannot be zero address
- Phase durations must be valid

**Atomic Operations:**
1. ✅ Verify factory owns NFT
2. ✅ Deploy new AuctionManager
3. ✅ Set controller: `nftContract.setController(tokenId, auctionAddress)`
4. ✅ Transfer NFT: `nftContract.transferFrom(factory, auction, tokenId)`
5. ✅ Add to auctions array and emit event

**Note**: Uses immutable `nftContract` and `paymentToken` from factory state (no longer passed as parameters)

**Example:**
```solidity
// Prerequisites:
// 1. Mint NFT to factory
uint256 tokenId = nft.mintTo(address(factory));

// 2. Set phase URIs
string[4] memory uris = [...];
nft.setPhaseURIs(tokenId, uris);

// 3. Create auction
uint256[4] memory durations = [
    7 days,   // Phase 0: Open
    14 days,  // Phase 1: Bidding
    30 days,  // Phase 2: Execution
    0         // Phase 3: Completed
];

address auction = factory.createAuction(
    adminAddress,      // Auction admin
    tokenId,          // Token to auction
    durations,        // Phase durations
    10_000_000 * 10**6,  // $10M floor (USDC decimals)
    5,                // 5% min increment
    true,             // Enforce increment
    1000 * 10**6,     // $1000 participation fee
    treasuryAddress   // Treasury (Gnosis Safe)
);
```

```bash
# Example: Create auction with CreateAuction.s.sol script
forge script script/CreateAuction.s.sol:CreateAuction \
    --rpc-url base_sepolia \
    --broadcast
```

### View Functions

#### getAuctions
```solidity
function getAuctions() external view returns (address[] memory)
```

**Description**: Returns array of all deployed auction addresses.

**Returns**: Array of AuctionManager addresses

**Example:**
```solidity
address[] memory auctions = factory.getAuctions();
```

```bash
cast call <FACTORY_ADDRESS> "getAuctions()" --rpc-url base_sepolia
```

---

#### getAuctionCount
```solidity
function getAuctionCount() external view returns (uint256)
```

**Description**: Returns total number of auctions created.

**Returns**: Count of auctions

**Example:**
```solidity
uint256 count = factory.getAuctionCount();
```

```bash
cast call <FACTORY_ADDRESS> "getAuctionCount()" --rpc-url base_sepolia
```

### Events

```solidity
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
```

---

## Deployment Workflow

### Infrastructure Deployment (Once Per Network)

Deploy the shared infrastructure using `DeployFactory.s.sol`:

```bash
# Set environment variables
export PRIVATE_KEY=0x...
export USDC_ADDRESS=0x...  # See network-specific addresses below

# Deploy to network
forge script script/DeployFactory.s.sol:DeployFactory \
    --rpc-url <network_name> \
    --broadcast \
    --verify

# Save deployed addresses
export NFT_ADDRESS=<deployed_housenft_address>
export FACTORY_ADDRESS=<deployed_factory_address>
```

**What Gets Deployed:**
1. `HouseNFT` ("ZBRICKS", "ZBR")
2. `AuctionFactory` (with immutable NFT and payment token references)
3. Factory is automatically set as trusted in NFT contract

**Output:** Infrastructure ready for creating multiple auctions

---

### Per-Auction Deployment

Create individual auctions using `CreateAuction.s.sol`:

**Step 1: Update Configuration**

Edit [script/CreateAuction.s.sol](script/CreateAuction.s.sol):
```solidity
// Auction parameters
uint256 public constant FLOOR_PRICE = 10_000_000 * 10**6;  // $10M
uint256 public constant OPEN_DURATION = 7 days;
uint256 public constant BIDDING_DURATION = 14 days;
uint256 public constant EXECUTION_PERIOD = 30 days;
uint256 public constant PARTICIPATION_FEE = 1000 * 10**6;  // $1000
address public constant TREASURY = 0x...;  // Gnosis Safe
address public constant ADMIN = 0x...;     // Or use deployer

// Phase metadata URIs (IPFS)
string public constant PHASE_0_URI = "ipfs://Qm.../phase0.json";
string public constant PHASE_1_URI = "ipfs://Qm.../phase1.json";
string public constant PHASE_2_URI = "ipfs://Qm.../phase2.json";
string public constant PHASE_3_URI = "ipfs://Qm.../phase3.json";
```

**Step 2: Deploy Auction**

```bash
# Ensure NFT_ADDRESS and FACTORY_ADDRESS are set
forge script script/CreateAuction.s.sol:CreateAuction \
    --rpc-url <network_name> \
    --broadcast
```

**What Happens:**
1. Mints new NFT to factory (`tokenId` auto-increments)
2. Sets all 4 phase URIs for metadata reveals
3. Factory creates auction atomically:
   - Verifies ownership
   - Deploys AuctionManager
   - Sets controller
   - Transfers NFT to auction
4. Returns auction address

**Output:** Independent auction ready for bidding

---

### Example: Full Deployment

```bash
# 1. Deploy infrastructure on Base Sepolia
export PRIVATE_KEY=0xabc...
export USDC_ADDRESS=0x036CbD53842c5426634e7929541eC2318f3dCF7e

forge script script/DeployFactory.s.sol:DeployFactory \
    --rpc-url base_sepolia \
    --broadcast

# Save addresses
export NFT_ADDRESS=0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6
export FACTORY_ADDRESS=0xd3390e5fec170d7577c850f5687a6542b66a4bbd

# 2. Create first auction (Property #1)
# Update CreateAuction.s.sol with property details
forge script script/CreateAuction.s.sol:CreateAuction \
    --rpc-url base_sepolia \
    --broadcast

# Auction created at: 0x3347f6a853e04281daa0314f49a76964f010366f

# 3. Create second auction (Property #2)
# Update CreateAuction.s.sol with new property details
forge script script/CreateAuction.s.sol:CreateAuction \
    --rpc-url base_sepolia \
    --broadcast

# Each auction is independent with own parameters
```

---

## Additional Resources

### Network-Specific USDC Addresses

| Network | USDC Address |
|---------|--------------|
| Base Mainnet | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| Arc Testnet | `0x3600000000000000000000000000000000000000` |

### ABI Files

All contract ABIs are available in [`deployments/abi/`](./deployments/abi/):
- [`HouseNFT.json`](./deployments/abi/HouseNFT.json)
- [`AuctionManager.json`](./deployments/abi/AuctionManager.json)
- [`AuctionFactory.json`](./deployments/abi/AuctionFactory.json)

### Example Workflows

#### Full Deployment Flow

```bash
# 1. Deploy contracts (NFT + Factory + Auction)
cd script
./deploy-and-verify.sh base_sepolia

# 2. Extract deployment addresses
node extractDeployment.js

# 3. Check deployed addresses
cat ../deployments/addresses.json
```

#### Complete Auction Lifecycle

```bash
# Set variables
NFT_ADDRESS="<HouseNFT address from addresses.json>"
AUCTION_ADDRESS="<AuctionManager address from addresses.json>"
PAYMENT_TOKEN="<USDC address for network>"

# 1. Mint NFT to auction contract
cast send $NFT_ADDRESS "mintTo(address)" $AUCTION_ADDRESS \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia

# 2. Set phase URIs (as admin)
cast send $NFT_ADDRESS "setPhaseURIs(uint256,string[4])" 1 \
    "[\"ipfs://phase0\",\"ipfs://phase1\",\"ipfs://phase2\",\"ipfs://phase3\"]" \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia

# 3. Approve USDC for bidding
cast send $PAYMENT_TOKEN "approve(address,uint256)" $AUCTION_ADDRESS 10000000000 \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia

# 4. Place bid (10,000 USDC = 10000000000 with 6 decimals)
cast send $AUCTION_ADDRESS "placeBid(uint256)" 10000000000 \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia

# 5. Check your total bid
cast call $AUCTION_ADDRESS "userBids(address)" $YOUR_ADDRESS --rpc-url base_sepolia

# 6. Check current leader
cast call $AUCTION_ADDRESS "currentLeader()" --rpc-url base_sepolia
cast call $AUCTION_ADDRESS "currentHighBid()" --rpc-url base_sepolia

# 7. Advance phase (owner only, after minimum duration)
cast send $AUCTION_ADDRESS "advancePhase()" \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia

# 8. Finalize auction (owner only, after all phases)
cast send $AUCTION_ADDRESS "finalizeAuction()" \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia

# 9. Owner withdraws proceeds
cast send $AUCTION_ADDRESS "withdrawProceeds()" \
    --private-key $PRIVATE_KEY --rpc-url base_sepolia
```

---

## Integration Examples

### ethers.js v6

```javascript
import { ethers } from 'ethers';
import HouseNFTABI from './deployments/abi/HouseNFT.json';
import AuctionManagerABI from './deployments/abi/AuctionManager.json';
import addresses from './deployments/addresses.json';

// Setup
const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
const signer = new ethers.Wallet(privateKey, provider);

// Get addresses for network
const networkAddresses = addresses.networks.find(n => n.chainId === 84532);
const nftAddress = networkAddresses.contracts.HouseNFT.address;
const auctionAddress = networkAddresses.contracts.AuctionManager.address;

// Connect to contracts
const nft = new ethers.Contract(nftAddress, HouseNFTABI, signer);
const auction = new ethers.Contract(auctionAddress, AuctionManagerABI, signer);
const usdc = new ethers.Contract(USDC_ADDRESS, IERC20_ABI, signer);

// Place a bid (5,000 USDC)
const amount = ethers.parseUnits('5000', 6); // USDC has 6 decimals
await usdc.approve(auctionAddress, amount);
await auction.placeBid(amount);

// Increase your bid (add 2,000 more)
const moreAmount = ethers.parseUnits('2000', 6);
await usdc.approve(auctionAddress, moreAmount);
await auction.placeBid(moreAmount); // Now your total bid is 7,000 USDC

// Check your total bid
const myBid = await auction.userBids(signer.address);
console.log('My total bid:', ethers.formatUnits(myBid, 6), 'USDC');

// Get current leader
const leader = await auction.currentLeader();
const highBid = await auction.currentHighBid();
console.log('Current leader:', leader);
console.log('Current high bid:', ethers.formatUnits(highBid, 6), 'USDC');

// Listen for bid events
auction.on('BidPlaced', (bidder, incrementalAmount, newTotalBid, phase) => {
  console.log(`${bidder} bid ${ethers.formatUnits(incrementalAmount, 6)} more`);
  console.log(`Their total is now ${ethers.formatUnits(newTotalBid, 6)} USDC`);
});
```

### viem

```typescript
import { createPublicClient, createWalletClient, http, parseUnits } from 'viem';
import { baseSepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import HouseNFTABI from './deployments/abi/HouseNFT.json';
import AuctionManagerABI from './deployments/abi/AuctionManager.json';
import addresses from './deployments/addresses.json';

// Setup
const account = privateKeyToAccount('0x...');
const publicClient = createPublicClient({
  chain: baseSepolia,
  transport: http()
});
const walletClient = createWalletClient({
  account,
  chain: baseSepolia,
  transport: http()
});

// Get addresses
const networkAddresses = addresses.networks.find(n => n.chainId === 84532);
const auctionAddress = networkAddresses.contracts.AuctionManager.address;

// Approve USDC
await walletClient.writeContract({
  address: USDC_ADDRESS,
  abi: IERC20_ABI,
  functionName: 'approve',
  args: [auctionAddress, parseUnits('5000', 6)]
});

// Place a bid
const { request } = await publicClient.simulateContract({
  address: auctionAddress,
  abi: AuctionManagerABI,
  functionName: 'placeBid',
  args: [parseUnits('5000', 6)] // 5,000 USDC
});
await walletClient.writeContract(request);

// Read current bid
const myBid = await publicClient.readContract({
  address: auctionAddress,
  abi: AuctionManagerABI,
  functionName: 'userBids',
  args: [account.address]
});
console.log('My total bid:', myBid / 1_000_000, 'USDC');

// Watch for events
publicClient.watchContractEvent({
  address: auctionAddress,
  abi: AuctionManagerABI,
  eventName: 'BidPlaced',
  onLogs: (logs) => {
    logs.forEach(log => {
      console.log('New bid from', log.args.bidder);
      console.log('Total:', log.args.newTotalBid / 1_000_000n, 'USDC');
    });
  }
});
```

---

## Important Notes

### USDC Decimals

⚠️ **USDC uses 6 decimals (not 18 like ETH)**

```javascript
// Correct: 1,000 USDC = 1000 * 10^6
const amount = 1000000000; // 1,000.000000 USDC

// Wrong:
const wrong = ethers.parseEther('1000'); // This is 1000 * 10^18 ❌
```

### Bidding Mechanics

- **Incremental**: Each `placeBid()` call *adds* to your existing bid
- **Cumulative**: `userBids[you]` stores your *total* bid across all calls
- **Winner Pays Only**: Only the final winner pays - losers can withdraw
- **Flexible**: You can increase your bid multiple times during any phase

### Security Considerations

1. **Always approve payment token** before calling `placeBid()`
2. **Check auction phase** before interacting (phases 0-2 for bidding)
3. **Verify contract addresses** on block explorer before use
4. **Test with small amounts** first on testnet
5. **Monitor events** for auction state changes
6. **Withdraw bids** if you're not winning to free up capital

---

## Testing

Run the comprehensive test suite:

```bash
forge test -vvv
```

**63 tests** covering all contract functionality including:
- Bidding mechanics (incremental, cumulative)
- Phase transitions and timing
- Access control (admin, owner, controller)
- Withdrawal and refund logic
- Edge cases and failure scenarios
- Fuzz testing for parameter validation

Run specific test files:
```bash
forge test --match-contract HouseNFTTest -vvv
forge test --match-contract AuctionManagerTest -vvv
```

---

## Support

- **Documentation:** [README.md](./README.md)
- **Auction Flow:** [AUCTION-FLOW.md](./AUCTION-FLOW.md)
- **Deployment Guide:** See README.md deployment section
- **Explorer:** Check addresses on [Basescan](https://basescan.org), [Base Sepolia](https://sepolia.basescan.org), or [Arc Testnet](https://testnet.arcscan.io)