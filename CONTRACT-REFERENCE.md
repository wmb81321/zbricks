# Smart Contract Reference

> 📖 **[← Back to README](README.md)** for quick start and deployment guide

Complete API documentation for HouseNFT and AuctionManager contracts with practical examples.

---

## Table of Contents

1. [HouseNFT Contract](#housenft-contract)
   - [Overview](#housenft-overview)
   - [State Variables](#housenft-state-variables)
   - [Functions](#housenft-functions)
   - [Events](#housenft-events)
   - [Usage Examples](#housenft-usage-examples)

2. [AuctionManager Contract](#auctionmanager-contract)
   - [Overview](#auctionmanager-overview)
   - [State Variables](#auctionmanager-state-variables)
   - [Structs](#auctionmanager-structs)
   - [Functions](#auctionmanager-functions)
   - [Events](#auctionmanager-events)
   - [Usage Examples](#auctionmanager-usage-examples)

3. [Integration Guide](#integration-guide)
4. [Common Patterns](#common-patterns)

---

# HouseNFT Contract

## HouseNFT Overview

**Contract Address**: Deployed at deployment (see deployments folder)  
**Type**: ERC721 Token  
**Solidity Version**: ^0.8.13  
**Inheritance**: OpenZeppelin ERC721  

### Purpose
Represents a single house as an NFT with progressive metadata reveals across 4 auction phases. The metadata URI changes automatically as the auction advances through phases, revealing more information about the house over time.

### Key Features
- Single token (ID: 1) minted at deployment
- 4 distinct metadata URIs for progressive reveals
- Admin control for metadata and phase management
- Controller pattern for auction integration
- Immutable after minting

---

## HouseNFT State Variables

### Public Variables

#### `admin`
```solidity
address public admin;
```
**Type**: `address`  
**Access**: Public (read), Admin only (write)  
**Description**: The admin address with control over metadata URIs and phase advancement. Initially set to deployer.

**Usage**:
```solidity
address currentAdmin = houseNFT.admin();
```

```bash
cast call <NFT_ADDRESS> "admin()" --rpc-url base_sepolia
```

---

#### `currentPhase`
```solidity
uint8 public currentPhase;
```
**Type**: `uint8`  
**Access**: Public (read), Admin/Controller only (write)  
**Range**: 0-3  
**Description**: Current phase of the NFT metadata reveal. Determines which metadata URI is returned by `tokenURI()`.

**Usage**:
```solidity
uint8 phase = houseNFT.currentPhase();
```

```bash
cast call <NFT_ADDRESS> "currentPhase()" --rpc-url base_sepolia
```

---

#### `controller`
```solidity
address public controller;
```
**Type**: `address`  
**Access**: Public (read), Admin only (set once)  
**Description**: Address of the AuctionManager contract authorized to advance phases. Can only be set once during initialization.

**Usage**:
```solidity
address auctionManager = houseNFT.controller();
```

```bash
cast call <NFT_ADDRESS> "controller()" --rpc-url base_sepolia
```

---

### Constants

#### `TOKEN_ID`
```solidity
uint256 private constant TOKEN_ID = 1;
```
**Value**: 1  
**Description**: The fixed token ID for the single house NFT.

---

## HouseNFT Functions

### Constructor

```solidity
constructor(
    string memory name,
    string memory symbol,
    string[4] memory _phaseURIs,
    address _initialOwner
)
```

**Description**: Initializes the HouseNFT contract with name, symbol, phase URIs, and mints the token to the initial owner (AuctionManager).

**Parameters**:
- `name`: Name of the NFT collection (e.g., "House NFT")
- `symbol`: Symbol of the NFT collection (e.g., "HOUSE")
- `_phaseURIs`: Array of 4 metadata URIs for phases 0-3
- `_initialOwner`: Address to receive the minted NFT (should be AuctionManager address)

**Requirements**:
- `_initialOwner` must not be zero address
- `_phaseURIs` must contain 4 valid URIs

**Example**:
```solidity
string[4] memory uris = [
    "ipfs://Qm.../phase0.json",
    "ipfs://Qm.../phase1.json",
    "ipfs://Qm.../phase2.json",
    "ipfs://Qm.../phase3.json"
];

HouseNFT nft = new HouseNFT(
    "House NFT",
    "HOUSE",
    uris,
    auctionManagerAddress
);
```

---

### Admin Functions

#### `transferAdmin`
```solidity
function transferAdmin(address newAdmin) external onlyAdmin
```

**Description**: Transfers admin role to a new address. Use for key rotation or transferring control.

**Access**: Admin only  
**Parameters**:
- `newAdmin`: Address of the new admin

**Requirements**:
- Caller must be current admin
- `newAdmin` must not be zero address

**Events Emitted**: `AdminTransferred(previousAdmin, newAdmin)`

**Practical Example**:
```solidity
// Transfer admin to multisig wallet
houseNFT.transferAdmin(0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb);
```

```bash
cast send <NFT_ADDRESS> \
    "transferAdmin(address)" \
    0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Rotating admin keys for security
- Transferring to multisig wallet
- Changing ownership after auction ends

---

#### `setController`
```solidity
function setController(address _controller) external onlyAdmin
```

**Description**: Sets the controller address (AuctionManager). Can only be called once during initialization.

**Access**: Admin only  
**Parameters**:
- `_controller`: Address of the AuctionManager contract

**Requirements**:
- Caller must be current admin
- Controller not already set
- `_controller` must not be zero address

**Events Emitted**: `ControllerSet(controller)`

**Practical Example**:
```solidity
// Set controller after deployment
houseNFT.setController(auctionManagerAddress);
```

```bash
cast send <NFT_ADDRESS> \
    "setController(address)" \
    <AUCTION_MANAGER_ADDRESS> \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Initial setup after deploying both contracts
- Linking NFT to auction system
- One-time configuration

---

#### `advancePhase`
```solidity
function advancePhase(uint8 newPhase) external onlyAdmin
```

**Description**: Advances the NFT metadata to the next phase. Admin manually calls this to reveal next phase metadata.

**Access**: Admin only  
**Parameters**:
- `newPhase`: The new phase number (must be `currentPhase + 1`)

**Requirements**:
- Caller must be current admin
- `newPhase` must equal `currentPhase + 1`
- `newPhase` must be <= 3

**Events Emitted**: `PhaseAdvanced(newPhase, msg.sender)`

**Practical Example**:
```solidity
// Advance from phase 0 to phase 1
houseNFT.advancePhase(1);

// Advance from phase 1 to phase 2
houseNFT.advancePhase(2);
```

```bash
# Advance to phase 1
cast send <NFT_ADDRESS> "advancePhase(uint8)" 1 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia

# Advance to phase 2
cast send <NFT_ADDRESS> "advancePhase(uint8)" 2 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia

# Advance to phase 3
cast send <NFT_ADDRESS> "advancePhase(uint8)" 3 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Coordinated with auction phase advancement
- Progressive metadata reveal
- Timing reveals with auction milestones

**Important Notes**:
- Must advance sequentially (0→1→2→3)
- Cannot skip phases
- Separate from auction phase advancement

---

#### `updatePhaseURI`
```solidity
function updatePhaseURI(uint8 phase, string memory uri) external onlyAdmin
```

**Description**: Updates the metadata URI for a specific phase. Use to fix incorrect URIs or update metadata.

**Access**: Admin only  
**Parameters**:
- `phase`: Phase number to update (0-3)
- `uri`: New metadata URI string

**Requirements**:
- Caller must be current admin
- `phase` must be <= 3

**Events Emitted**: `PhaseURIUpdated(phase, uri)`

**Practical Example**:
```solidity
// Update phase 0 metadata
houseNFT.updatePhaseURI(0, "ipfs://QmNewHash/phase0.json");

// Update phase 2 metadata
houseNFT.updatePhaseURI(2, "ipfs://QmUpdated/phase2.json");
```

```bash
cast send <NFT_ADDRESS> \
    "updatePhaseURI(uint8,string)" \
    0 \
    "ipfs://QmNewHash/phase0.json" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Correcting deployment mistakes
- Updating metadata with new information
- Fixing broken IPFS links
- Adding dynamic auction data to metadata

---

### View Functions

#### `tokenURI`
```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory)
```

**Description**: Returns the metadata URI for the specified token based on the current phase.

**Access**: Public (view)  
**Parameters**:
- `tokenId`: The token ID to query (must be 1)

**Returns**: `string` - Metadata URI for current phase

**Requirements**:
- Token must exist (tokenId must be 1)

**Practical Example**:
```solidity
// Get current metadata URI
string memory uri = houseNFT.tokenURI(1);
```

```bash
cast call <NFT_ADDRESS> "tokenURI(uint256)" 1 --rpc-url base_sepolia
```

**Use Cases**:
- Displaying NFT in wallet/marketplace
- Frontend integration
- Metadata verification

**Returns Example**:
```
"ipfs://QmXYZ.../phase0.json"  // When currentPhase = 0
"ipfs://QmABC.../phase1.json"  // When currentPhase = 1
```

---

#### `getPhaseURI`
```solidity
function getPhaseURI(uint8 phase) external view returns (string memory)
```

**Description**: Returns the metadata URI for a specific phase, regardless of current phase.

**Access**: Public (view)  
**Parameters**:
- `phase`: Phase number to query (0-3)

**Returns**: `string` - Metadata URI for specified phase

**Requirements**:
- `phase` must be <= 3

**Practical Example**:
```solidity
// Check all phase URIs
string memory uri0 = houseNFT.getPhaseURI(0);
string memory uri1 = houseNFT.getPhaseURI(1);
string memory uri2 = houseNFT.getPhaseURI(2);
string memory uri3 = houseNFT.getPhaseURI(3);
```

```bash
# Get phase 0 URI
cast call <NFT_ADDRESS> "getPhaseURI(uint8)" 0 --rpc-url base_sepolia

# Get phase 3 URI
cast call <NFT_ADDRESS> "getPhaseURI(uint8)" 3 --rpc-url base_sepolia
```

**Use Cases**:
- Previewing future phase metadata
- Verifying all URIs are set correctly
- Admin verification before deployment

---

### Standard ERC721 Functions

The contract inherits all standard ERC721 functions from OpenZeppelin:

- `balanceOf(address owner)`: Returns token balance of owner
- `ownerOf(uint256 tokenId)`: Returns owner of token
- `approve(address to, uint256 tokenId)`: Approves address to transfer token
- `getApproved(uint256 tokenId)`: Returns approved address for token
- `setApprovalForAll(address operator, bool approved)`: Approves operator for all tokens
- `isApprovedForAll(address owner, address operator)`: Checks operator approval
- `transferFrom(address from, address to, uint256 tokenId)`: Transfers token
- `safeTransferFrom(...)`: Safe transfer variants

---

## HouseNFT Events

### `AdminTransferred`
```solidity
event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
```

**Emitted When**: Admin role is transferred to new address  
**Parameters**:
- `previousAdmin`: Previous admin address (indexed)
- `newAdmin`: New admin address (indexed)

**Example Usage**:
```javascript
// Listen for admin transfers
nftContract.on("AdminTransferred", (previousAdmin, newAdmin) => {
    console.log(`Admin changed from ${previousAdmin} to ${newAdmin}`);
});
```

---

### `ControllerSet`
```solidity
event ControllerSet(address indexed controller);
```

**Emitted When**: Controller address is set for the first time  
**Parameters**:
- `controller`: AuctionManager address (indexed)

**Example Usage**:
```javascript
// Listen for controller setup
nftContract.on("ControllerSet", (controller) => {
    console.log(`Controller set to: ${controller}`);
});
```

---

### `PhaseAdvanced`
```solidity
event PhaseAdvanced(uint8 indexed newPhase, address indexed advancedBy);
```

**Emitted When**: NFT metadata advances to a new phase  
**Parameters**:
- `newPhase`: New phase number (0-3) (indexed)
- `advancedBy`: Address that called advancePhase (indexed)

**Example Usage**:
```javascript
// Listen for phase changes
nftContract.on("PhaseAdvanced", (newPhase, advancedBy) => {
    console.log(`Phase advanced to ${newPhase} by ${advancedBy}`);
    // Refresh metadata display
    updateNFTDisplay();
});
```

---

### `PhaseURIUpdated`
```solidity
event PhaseURIUpdated(uint8 indexed phase, string uri);
```

**Emitted When**: Metadata URI for a phase is updated  
**Parameters**:
- `phase`: Phase number that was updated (indexed)
- `uri`: New URI string

**Example Usage**:
```javascript
// Listen for metadata updates
nftContract.on("PhaseURIUpdated", (phase, uri) => {
    console.log(`Phase ${phase} URI updated to: ${uri}`);
    // Clear metadata cache if needed
    clearMetadataCache(phase);
});
```

---

## HouseNFT Usage Examples

### Complete Admin Workflow

```solidity
// 1. Deploy contracts
HouseNFT nft = new HouseNFT(/* ... */);
AuctionManager auction = new AuctionManager(/* ... */);

// 2. Set controller (one-time)
nft.setController(address(auction));

// 3. Coordinate phase advancement with auction
// After auction phase 0 completes
auction.advancePhase();  // Advance auction to phase 1
nft.advancePhase(1);      // Advance NFT metadata to phase 1

// After auction phase 1 completes
auction.advancePhase();  // Advance auction to phase 2
nft.advancePhase(2);      // Advance NFT metadata to phase 2

// After auction phase 2 completes
auction.finalizeAuction(); // Finalize and transfer NFT
nft.advancePhase(3);       // Advance to final phase metadata

// 4. Update metadata if needed
nft.updatePhaseURI(0, "ipfs://QmNewHash/phase0.json");

// 5. Transfer admin if needed
nft.transferAdmin(multisigAddress);
```

### Frontend Integration

```javascript
// Initialize contract
const nftContract = new ethers.Contract(nftAddress, nftABI, provider);

// Get current phase
const currentPhase = await nftContract.currentPhase();

// Get current metadata
const tokenURI = await nftContract.tokenURI(1);
const metadata = await fetch(tokenURI).then(r => r.json());

// Display NFT
console.log(`NFT Name: ${metadata.name}`);
console.log(`Description: ${metadata.description}`);
console.log(`Image: ${metadata.image}`);
console.log(`Current Phase: ${currentPhase}`);

// Listen for phase changes
nftContract.on("PhaseAdvanced", async (newPhase) => {
    console.log(`Phase changed to: ${newPhase}`);
    const newTokenURI = await nftContract.tokenURI(1);
    const newMetadata = await fetch(newTokenURI).then(r => r.json());
    // Update UI with new metadata
    updateDisplay(newMetadata);
});
```

---

# AuctionManager Contract

## AuctionManager Overview

**Contract Address**: Deployed at deployment (see deployments folder)  
**Type**: Auction Manager  
**Solidity Version**: ^0.8.13  
**Inheritance**: OpenZeppelin Pausable, ReentrancyGuard, IERC721Receiver  

### Purpose
Manages a multi-phase continuous clearing auction (CCA) for the house NFT using USDC as the bidding currency. Only the final winner pays, all other bidders receive full refunds.

### Key Features
- 4 configurable auction phases
- USDC-based bidding
- Pull-based refund system
- Emergency pause mechanism
- Reentrancy protection
- Admin controls with transfer capability

---

## AuctionManager State Variables

### Immutable Variables

#### `usdc`
```solidity
IERC20 public immutable usdc;
```
**Type**: `IERC20`  
**Access**: Public (read)  
**Description**: USDC token contract used for bidding. Set at deployment and cannot be changed.

**Usage**:
```solidity
address usdcAddress = address(auction.usdc());
```

```bash
cast call <AUCTION_ADDRESS> "usdc()" --rpc-url base_sepolia
```

---

#### `houseNFT`
```solidity
HouseNFT public immutable houseNFT;
```
**Type**: `HouseNFT`  
**Access**: Public (read)  
**Description**: HouseNFT contract being auctioned. Set at deployment and cannot be changed.

**Usage**:
```solidity
address nftAddress = address(auction.houseNFT());
```

```bash
cast call <AUCTION_ADDRESS> "houseNFT()" --rpc-url base_sepolia
```

---

### Mutable Variables

#### `admin`
```solidity
address public admin;
```
**Type**: `address`  
**Access**: Public (read), Admin only (write via transferAdmin)  
**Description**: Admin address with control over phase advancement, finalization, and emergency pause.

**Usage**:
```solidity
address currentAdmin = auction.admin();
```

```bash
cast call <AUCTION_ADDRESS> "admin()" --rpc-url base_sepolia
```

---

#### `currentPhase`
```solidity
uint8 public currentPhase;
```
**Type**: `uint8`  
**Access**: Public (read), Admin only (write)  
**Range**: 0-2 during bidding, 3 is implied after phase 2  
**Description**: Current auction phase. Bidding allowed only in phases 0, 1, and 2.

**Usage**:
```solidity
uint8 phase = auction.currentPhase();
```

```bash
cast call <AUCTION_ADDRESS> "currentPhase()" --rpc-url base_sepolia
```

---

#### `currentLeader`
```solidity
address public currentLeader;
```
**Type**: `address`  
**Access**: Public (read)  
**Description**: Address of current highest bidder. Will receive NFT if no higher bid is placed.

**Usage**:
```solidity
address leader = auction.currentLeader();
```

```bash
cast call <AUCTION_ADDRESS> "currentLeader()" --rpc-url base_sepolia
```

---

#### `currentHighBid`
```solidity
uint256 public currentHighBid;
```
**Type**: `uint256`  
**Access**: Public (read)  
**Description**: Current highest bid amount in USDC (6 decimals). Next bid must exceed this.

**Usage**:
```solidity
uint256 highBid = auction.currentHighBid();
```

```bash
cast call <AUCTION_ADDRESS> "currentHighBid()" --rpc-url base_sepolia
```

**Example Output**: `1000000000` (1,000 USDC in 6 decimal format)

---

#### `finalized`
```solidity
bool public finalized;
```
**Type**: `bool`  
**Access**: Public (read)  
**Description**: Whether auction has been finalized. Once true, NFT is transferred and no more bidding.

**Usage**:
```solidity
bool isFinalized = auction.finalized();
```

```bash
cast call <AUCTION_ADDRESS> "finalized()" --rpc-url base_sepolia
```

---

#### `paused`
```solidity
bool public paused;
```
**Type**: `bool`  
**Access**: Public (read via `paused()`)  
**Description**: Whether bidding and phase advancement are paused. Withdrawals still allowed.

**Usage**:
```solidity
bool isPaused = auction.paused();
```

```bash
cast call <AUCTION_ADDRESS> "paused()" --rpc-url base_sepolia
```

---

#### `refundBalance`
```solidity
mapping(address => uint256) public refundBalance;
```
**Type**: `mapping(address => uint256)`  
**Access**: Public (read)  
**Description**: Mapping of bidder addresses to their refund balance in USDC. Populated when outbid.

**Usage**:
```solidity
uint256 myRefund = auction.refundBalance(myAddress);
```

```bash
cast call <AUCTION_ADDRESS> "refundBalance(address)" <YOUR_ADDRESS> --rpc-url base_sepolia
```

---

#### `phases`
```solidity
mapping(uint8 => PhaseInfo) public phases;
```
**Type**: `mapping(uint8 => PhaseInfo)`  
**Access**: Public (read)  
**Description**: Stores information for each phase (0-3).

**Usage**:
```solidity
(uint256 minDuration, uint256 startTime, address leader, uint256 highBid, bool revealed) 
    = auction.phases(0);
```

```bash
cast call <AUCTION_ADDRESS> "phases(uint8)" 0 --rpc-url base_sepolia
```

---

## AuctionManager Structs

### `PhaseInfo`
```solidity
struct PhaseInfo {
    uint256 minDuration;  // Minimum duration in seconds
    uint256 startTime;    // Timestamp when phase started
    address leader;       // Leader at end of phase
    uint256 highBid;      // Highest bid at end of phase
    bool revealed;        // Whether phase has been revealed
}
```

**Description**: Contains information about each auction phase.

**Fields**:
- `minDuration`: Minimum time (seconds) phase must last before advancing
- `startTime`: Unix timestamp when phase started
- `leader`: Winning bidder when phase completed (locked)
- `highBid`: Winning bid amount when phase completed (locked)
- `revealed`: Whether phase has been completed and data locked

**Example**:
```solidity
PhaseInfo memory phase0 = auction.getPhaseInfo(0);
console.log("Phase 0 duration:", phase0.minDuration);
console.log("Phase 0 started:", phase0.startTime);
console.log("Phase 0 leader:", phase0.leader);
console.log("Phase 0 high bid:", phase0.highBid);
console.log("Phase 0 revealed:", phase0.revealed);
```

---

## AuctionManager Functions

### Constructor

```solidity
constructor(
    address _usdc,
    address _houseNFT,
    address _admin,
    uint256[4] memory _phaseDurations
)
```

**Description**: Initializes the auction with USDC token, NFT, admin, and phase durations.

**Parameters**:
- `_usdc`: USDC token contract address
- `_houseNFT`: HouseNFT contract address
- `_admin`: Admin address for control functions
- `_phaseDurations`: Array of 4 phase durations in seconds (must each be >= 24 hours)

**Requirements**:
- All addresses must not be zero
- Each phase duration must be >= 24 hours (86400 seconds)

**Example**:
```solidity
uint256[4] memory durations = [
    48 hours,  // Phase 0: 48 hours
    24 hours,  // Phase 1: 24 hours
    24 hours,  // Phase 2: 24 hours
    24 hours   // Phase 3: 24 hours
];

AuctionManager auction = new AuctionManager(
    usdcAddress,
    nftAddress,
    adminAddress,
    durations
);
```

**Effects**:
- Sets immutable USDC and NFT addresses
- Sets admin
- Initializes phase durations
- Starts phase 0 immediately

---

### Bidding Functions

#### `placeBid`
```solidity
function placeBid(uint256 amount) external whenNotPaused nonReentrant
```

**Description**: Places a bid in the current auction phase. New bid must exceed current highest bid.

**Access**: Public (any address)  
**Parameters**:
- `amount`: Bid amount in USDC (must be > currentHighBid)

**Requirements**:
- Auction not paused
- Auction not finalized
- Current phase <= 2 (bidding closed in phase 3)
- Amount > currentHighBid
- Caller has approved auction for USDC transfer
- Caller has sufficient USDC balance

**Effects**:
- Previous leader's bid moved to refundBalance
- Caller becomes new currentLeader
- Amount becomes new currentHighBid
- Transfers USDC from caller to contract

**Events Emitted**: `BidPlaced(currentPhase, msg.sender, amount)`

**Practical Example**:
```solidity
// 1. Approve USDC
IERC20(usdcAddress).approve(auctionAddress, bidAmount);

// 2. Place bid
auction.placeBid(bidAmount);
```

```bash
# 1. Approve USDC (1000 USDC = 1000000000 in 6 decimals)
cast send <USDC_ADDRESS> \
    "approve(address,uint256)" \
    <AUCTION_ADDRESS> \
    1000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia

# 2. Place bid
cast send <AUCTION_ADDRESS> \
    "placeBid(uint256)" \
    1000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Participating in auction
- Outbidding current leader
- Securing position in current phase

**Important Notes**:
- Must approve USDC first
- Previous bid automatically refunded to your balance
- Can withdraw refund at any time
- Bid in USDC with 6 decimals (1 USDC = 1000000)

---

#### `withdraw`
```solidity
function withdraw() external nonReentrant
```

**Description**: Withdraws refund balance for caller using pull-payment pattern.

**Access**: Public (any address with refund balance)  
**Parameters**: None

**Requirements**:
- Caller has refund balance > 0

**Effects**:
- Clears caller's refundBalance
- Transfers USDC to caller

**Events Emitted**: `RefundWithdrawn(msg.sender, amount)`

**Practical Example**:
```solidity
// Check refund balance first
uint256 refund = auction.getBidderRefund(msg.sender);
if (refund > 0) {
    auction.withdraw();
}
```

```bash
# Check refund balance
cast call <AUCTION_ADDRESS> \
    "getBidderRefund(address)" \
    <YOUR_ADDRESS> \
    --rpc-url base_sepolia

# Withdraw refund
cast send <AUCTION_ADDRESS> "withdraw()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Withdrawing after being outbid
- Recovering funds after auction ends
- Emergency withdrawal if paused

**Important Notes**:
- Can be called even when paused (for user safety)
- Can be called after finalization
- Uses pull pattern (safer than push)
- No gas optimization needed for reentrancy

---

### Phase Management Functions

#### `advancePhase`
```solidity
function advancePhase() external onlyAdmin whenNotPaused
```

**Description**: Advances auction to next phase, locking current phase data.

**Access**: Admin only  
**Parameters**: None

**Requirements**:
- Caller is admin
- Auction not paused
- Current phase < 2 (can only advance from 0→1, 1→2)
- Auction not finalized
- Minimum duration for current phase has elapsed

**Effects**:
- Locks current phase leader and highBid
- Marks current phase as revealed
- Increments currentPhase
- Sets new phase startTime

**Events Emitted**: `PhaseAdvanced(newPhase, block.timestamp)`

**Practical Example**:
```solidity
// Check if ready to advance
uint256 timeRemaining = auction.getTimeRemaining();
require(timeRemaining == 0, "Duration not met");

// Advance phase
auction.advancePhase();
```

```bash
# Check time remaining
cast call <AUCTION_ADDRESS> "getTimeRemaining()" --rpc-url base_sepolia

# Advance phase (if time remaining is 0)
cast send <AUCTION_ADDRESS> "advancePhase()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Moving from phase 0 to phase 1 after 48 hours
- Moving from phase 1 to phase 2 after 24 hours
- Progressing auction through reveals

**Important Notes**:
- Must wait for minimum duration
- Cannot skip phases
- Does NOT advance NFT metadata (separate call needed)
- Cannot advance from phase 2 (use finalizeAuction instead)

---

#### `finalizeAuction`
```solidity
function finalizeAuction() external onlyAdmin
```

**Description**: Finalizes the auction and transfers NFT to winner.

**Access**: Admin only  
**Parameters**: None

**Requirements**:
- Caller is admin
- Current phase == 2
- Auction not already finalized
- Has a valid winner (currentLeader != address(0))
- Phase 2 minimum duration has elapsed

**Effects**:
- Locks phase 2 data
- Sets finalized = true
- Transfers NFT (tokenId 1) to winner

**Events Emitted**: `AuctionFinalized(currentLeader, currentHighBid)`

**Practical Example**:
```solidity
// Check if ready to finalize
require(auction.currentPhase() == 2, "Must be phase 2");
require(auction.getTimeRemaining() == 0, "Duration not met");
require(auction.currentLeader() != address(0), "No winner");

// Finalize
auction.finalizeAuction();
```

```bash
# Check current state
cast call <AUCTION_ADDRESS> "currentPhase()" --rpc-url base_sepolia
cast call <AUCTION_ADDRESS> "getTimeRemaining()" --rpc-url base_sepolia
cast call <AUCTION_ADDRESS> "currentLeader()" --rpc-url base_sepolia

# Finalize auction
cast send <AUCTION_ADDRESS> "finalizeAuction()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Completing auction after all phases
- Transferring NFT to winner
- Enabling proceeds withdrawal

**Important Notes**:
- NFT automatically transferred to winner
- Winner can no longer withdraw (they won)
- Admin can now withdraw proceeds
- Other bidders can still withdraw refunds

---

### Admin Functions

#### `withdrawProceeds`
```solidity
function withdrawProceeds() external onlyAdmin nonReentrant
```

**Description**: Withdraws auction proceeds (winning bid) to admin. Can only be called once.

**Access**: Admin only  
**Parameters**: None

**Requirements**:
- Caller is admin
- Auction finalized
- Proceeds not already withdrawn

**Effects**:
- Marks proceeds as withdrawn
- Transfers winning bid amount to admin

**Events Emitted**: `ProceedsWithdrawn(amount)`

**Practical Example**:
```solidity
// After finalization
require(auction.finalized(), "Not finalized");

// Withdraw proceeds
auction.withdrawProceeds();
```

```bash
# Check if finalized
cast call <AUCTION_ADDRESS> "finalized()" --rpc-url base_sepolia

# Withdraw proceeds
cast send <AUCTION_ADDRESS> "withdrawProceeds()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Collecting winning bid after auction
- Transferring funds to project treasury
- One-time proceeds claim

**Important Notes**:
- Can only be called once
- Only transfers winning bid (all others refunded)
- Must be called after finalization

---

#### `transferAdmin`
```solidity
function transferAdmin(address newAdmin) external onlyAdmin
```

**Description**: Transfers admin role to new address.

**Access**: Admin only  
**Parameters**:
- `newAdmin`: Address of new admin

**Requirements**:
- Caller is admin
- `newAdmin` must not be zero address

**Events Emitted**: `AdminTransferred(oldAdmin, newAdmin)`

**Practical Example**:
```solidity
// Transfer to multisig
auction.transferAdmin(multisigAddress);
```

```bash
cast send <AUCTION_ADDRESS> \
    "transferAdmin(address)" \
    <NEW_ADMIN_ADDRESS> \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Key rotation for security
- Transferring to multisig wallet
- Changing project ownership

---

#### `pause`
```solidity
function pause() external onlyAdmin
```

**Description**: Pauses bidding and phase advancement. Does NOT pause withdrawals.

**Access**: Admin only  
**Parameters**: None

**Effects**:
- Sets paused = true
- Blocks placeBid()
- Blocks advancePhase()
- Withdrawals still allowed

**Events Emitted**: `Paused(msg.sender)`

**Practical Example**:
```solidity
// Emergency pause
auction.pause();
```

```bash
cast send <AUCTION_ADDRESS> "pause()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Emergency situations
- Suspicious activity detected
- Smart contract bug discovered
- Temporary halt for maintenance

**Important Notes**:
- Users can still withdraw refunds (safety feature)
- Cannot finalize while paused
- Should be used sparingly

---

#### `unpause`
```solidity
function unpause() external onlyAdmin
```

**Description**: Unpauses the auction, resuming normal operations.

**Access**: Admin only  
**Parameters**: None

**Effects**:
- Sets paused = false
- Re-enables bidding
- Re-enables phase advancement

**Events Emitted**: `Unpaused(msg.sender)`

**Practical Example**:
```solidity
// Resume operations
auction.unpause();
```

```bash
cast send <AUCTION_ADDRESS> "unpause()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

**Use Cases**:
- Resuming after emergency
- Continuing after issue resolved

---

### View Functions

#### `isAuctionActive`
```solidity
function isAuctionActive() external view returns (bool)
```

**Description**: Checks if auction is still active (not finalized).

**Access**: Public (view)  
**Returns**: `bool` - true if active, false if finalized

**Practical Example**:
```solidity
bool active = auction.isAuctionActive();
if (active) {
    // Can still place bids
}
```

```bash
cast call <AUCTION_ADDRESS> "isAuctionActive()" --rpc-url base_sepolia
```

---

#### `getTimeRemaining`
```solidity
function getTimeRemaining() external view returns (uint256)
```

**Description**: Returns seconds remaining in current phase. Returns 0 if ready to advance.

**Access**: Public (view)  
**Returns**: `uint256` - Seconds remaining (0 if duration met)

**Practical Example**:
```solidity
uint256 timeLeft = auction.getTimeRemaining();
if (timeLeft == 0) {
    // Ready to advance phase
}
```

```bash
cast call <AUCTION_ADDRESS> "getTimeRemaining()" --rpc-url base_sepolia
```

**Example Output**: `3600` (1 hour remaining)

---

#### `getBidderRefund`
```solidity
function getBidderRefund(address bidder) external view returns (uint256)
```

**Description**: Returns refund balance for specific bidder.

**Access**: Public (view)  
**Parameters**:
- `bidder`: Address to check

**Returns**: `uint256` - Refund balance in USDC

**Practical Example**:
```solidity
uint256 refund = auction.getBidderRefund(msg.sender);
```

```bash
cast call <AUCTION_ADDRESS> \
    "getBidderRefund(address)" \
    <BIDDER_ADDRESS> \
    --rpc-url base_sepolia
```

---

#### `getCurrentLeaderAndBid`
```solidity
function getCurrentLeaderAndBid() external view returns (address leader, uint256 highBid)
```

**Description**: Returns current leader and highest bid.

**Access**: Public (view)  
**Returns**:
- `leader`: Address of current highest bidder
- `highBid`: Current highest bid amount

**Practical Example**:
```solidity
(address leader, uint256 highBid) = auction.getCurrentLeaderAndBid();
console.log("Current leader:", leader);
console.log("Current high bid:", highBid);
```

```bash
cast call <AUCTION_ADDRESS> "getCurrentLeaderAndBid()" --rpc-url base_sepolia
```

---

#### `getCurrentPhaseInfo`
```solidity
function getCurrentPhaseInfo() external view returns (
    uint256 minDuration,
    uint256 startTime,
    address leader,
    uint256 highBid,
    bool revealed
)
```

**Description**: Returns complete information about the current phase.

**Access**: Public (view)  
**Returns**:
- `minDuration`: Minimum phase duration in seconds
- `startTime`: Unix timestamp when phase started
- `leader`: Leader at end of phase (if revealed)
- `highBid`: High bid at end of phase (if revealed)
- `revealed`: Whether phase has been completed

**Practical Example**:
```solidity
(uint256 minDuration, uint256 startTime, address leader, uint256 highBid, bool revealed) 
    = auction.getCurrentPhaseInfo();
```

```bash
cast call <AUCTION_ADDRESS> "getCurrentPhaseInfo()" --rpc-url base_sepolia
```

---

#### `getPhaseInfo`
```solidity
function getPhaseInfo(uint8 phase) external view returns (
    uint256 minDuration,
    uint256 startTime,
    address leader,
    uint256 highBid,
    bool revealed
)
```

**Description**: Returns information for a specific phase (0-3).

**Access**: Public (view)  
**Parameters**:
- `phase`: Phase number (0-3)

**Returns**: Same as getCurrentPhaseInfo

**Practical Example**:
```solidity
// Get phase 0 results
(, , address phase0Leader, uint256 phase0HighBid, bool revealed) 
    = auction.getPhaseInfo(0);
```

```bash
cast call <AUCTION_ADDRESS> "getPhaseInfo(uint8)" 0 --rpc-url base_sepolia
```

---

#### `getAuctionState`
```solidity
function getAuctionState() external view returns (
    uint8 _currentPhase,
    address _currentLeader,
    uint256 _currentHighBid,
    bool _finalized,
    bool _biddingOpen
)
```

**Description**: Returns complete auction state summary.

**Access**: Public (view)  
**Returns**:
- `_currentPhase`: Current phase number
- `_currentLeader`: Current highest bidder
- `_currentHighBid`: Current highest bid
- `_finalized`: Whether auction is finalized
- `_biddingOpen`: Whether bidding is currently allowed

**Practical Example**:
```solidity
(uint8 phase, address leader, uint256 highBid, bool finalized, bool biddingOpen) 
    = auction.getAuctionState();
```

```bash
cast call <AUCTION_ADDRESS> "getAuctionState()" --rpc-url base_sepolia
```

---

### ERC721 Receiver

#### `onERC721Received`
```solidity
function onERC721Received(address, address, address, uint256, bytes calldata) 
    external pure override returns (bytes4)
```

**Description**: Handles receipt of ERC721 tokens. Required to receive the NFT mint.

**Access**: Public (pure)  
**Returns**: `bytes4` - ERC721 receiver selector

**Note**: Automatically called by HouseNFT during minting to AuctionManager.

---

## AuctionManager Events

### `BidPlaced`
```solidity
event BidPlaced(uint8 indexed phase, address indexed bidder, uint256 amount);
```

**Emitted When**: A new bid is placed  
**Parameters**:
- `phase`: Phase number when bid was placed (indexed)
- `bidder`: Address that placed the bid (indexed)
- `amount`: Bid amount in USDC

**Example Usage**:
```javascript
auctionContract.on("BidPlaced", (phase, bidder, amount) => {
    console.log(`New bid in phase ${phase}`);
    console.log(`Bidder: ${bidder}`);
    console.log(`Amount: ${ethers.utils.formatUnits(amount, 6)} USDC`);
    // Update UI with new leader
});
```

---

### `PhaseAdvanced`
```solidity
event PhaseAdvanced(uint8 indexed phase, uint256 timestamp);
```

**Emitted When**: Auction advances to a new phase  
**Parameters**:
- `phase`: New phase number (indexed)
- `timestamp`: Unix timestamp of advancement

**Example Usage**:
```javascript
auctionContract.on("PhaseAdvanced", (phase, timestamp) => {
    console.log(`Auction advanced to phase ${phase}`);
    console.log(`Time: ${new Date(timestamp * 1000)}`);
    // Refresh phase info
});
```

---

### `AuctionFinalized`
```solidity
event AuctionFinalized(address indexed winner, uint256 amount);
```

**Emitted When**: Auction is finalized and NFT transferred  
**Parameters**:
- `winner`: Address that won the auction (indexed)
- `amount`: Winning bid amount

**Example Usage**:
```javascript
auctionContract.on("AuctionFinalized", (winner, amount) => {
    console.log(`Auction won by: ${winner}`);
    console.log(`Winning bid: ${ethers.utils.formatUnits(amount, 6)} USDC`);
    // Show congratulations message
});
```

---

### `RefundWithdrawn`
```solidity
event RefundWithdrawn(address indexed bidder, uint256 amount);
```

**Emitted When**: A bidder withdraws their refund  
**Parameters**:
- `bidder`: Address withdrawing refund (indexed)
- `amount`: Refund amount in USDC

**Example Usage**:
```javascript
auctionContract.on("RefundWithdrawn", (bidder, amount) => {
    if (bidder === userAddress) {
        console.log(`You withdrew ${ethers.utils.formatUnits(amount, 6)} USDC`);
    }
});
```

---

### `ProceedsWithdrawn`
```solidity
event ProceedsWithdrawn(uint256 amount);
```

**Emitted When**: Admin withdraws auction proceeds  
**Parameters**:
- `amount`: Proceeds amount in USDC

---

### `AdminTransferred`
```solidity
event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
```

**Emitted When**: Admin role is transferred  
**Parameters**:
- `oldAdmin`: Previous admin address (indexed)
- `newAdmin`: New admin address (indexed)

---

### `Paused` / `Unpaused`
```solidity
event Paused(address account);
event Unpaused(address account);
```

**Emitted When**: Auction is paused or unpaused  
**Parameters**:
- `account`: Address that paused/unpaused

---

## AuctionManager Usage Examples

### Complete Bidder Workflow

```solidity
// 1. Check current auction state
(uint8 phase, address leader, uint256 highBid, bool finalized, bool biddingOpen) 
    = auction.getAuctionState();

require(!finalized, "Auction ended");
require(biddingOpen, "Bidding closed");

// 2. Check current high bid
uint256 currentBid = auction.currentHighBid();
uint256 myBid = currentBid + 100 * 10**6; // Bid 100 USDC more

// 3. Approve USDC
IERC20(usdcAddress).approve(auctionAddress, myBid);

// 4. Place bid
auction.placeBid(myBid);

// 5. Later, if outbid, check refund
uint256 refund = auction.getBidderRefund(msg.sender);

// 6. Withdraw refund
if (refund > 0) {
    auction.withdraw();
}
```

### Complete Admin Workflow

```solidity
// 1. Deploy and setup
AuctionManager auction = new AuctionManager(/* ... */);
// Phase 0 starts automatically

// 2. Monitor phase 0 (48 hours)
// Wait for duration...

// 3. Advance to phase 1
uint256 timeLeft = auction.getTimeRemaining();
require(timeLeft == 0, "Not ready");
auction.advancePhase(); // Now in phase 1
nft.advancePhase(1);     // Update NFT metadata

// 4. Monitor phase 1 (24 hours)
// Wait for duration...

// 5. Advance to phase 2
auction.advancePhase(); // Now in phase 2
nft.advancePhase(2);     // Update NFT metadata

// 6. Monitor phase 2 (24 hours)
// Wait for duration...

// 7. Finalize auction
auction.finalizeAuction(); // NFT transferred to winner
nft.advancePhase(3);       // Final metadata reveal

// 8. Withdraw proceeds
auction.withdrawProceeds();

// 9. Optional: Transfer admin
auction.transferAdmin(newAdminAddress);
```

### Frontend Integration

```javascript
// Initialize
const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();
const auctionContract = new ethers.Contract(auctionAddress, auctionABI, signer);
const usdcContract = new ethers.Contract(usdcAddress, usdcABI, signer);

// Display current state
async function displayAuctionState() {
    const state = await auctionContract.getAuctionState();
    const [phase, leader, highBid, finalized, biddingOpen] = state;
    
    document.getElementById('phase').textContent = phase;
    document.getElementById('leader').textContent = leader;
    document.getElementById('highBid').textContent = 
        ethers.utils.formatUnits(highBid, 6) + ' USDC';
    document.getElementById('status').textContent = 
        finalized ? 'Finalized' : (biddingOpen ? 'Active' : 'Bidding Closed');
        
    // Show time remaining
    const timeRemaining = await auctionContract.getTimeRemaining();
    const hours = Math.floor(timeRemaining / 3600);
    const minutes = Math.floor((timeRemaining % 3600) / 60);
    document.getElementById('timeLeft').textContent = 
        `${hours}h ${minutes}m`;
}

// Place bid
async function placeBid(bidAmount) {
    const userAddress = await signer.getAddress();
    
    // Convert to 6 decimals
    const amount = ethers.utils.parseUnits(bidAmount, 6);
    
    // Check current high bid
    const currentHighBid = await auctionContract.currentHighBid();
    if (amount.lte(currentHighBid)) {
        alert('Bid must be higher than current bid');
        return;
    }
    
    // Approve USDC
    const approveTx = await usdcContract.approve(auctionAddress, amount);
    await approveTx.wait();
    
    // Place bid
    const bidTx = await auctionContract.placeBid(amount);
    await bidTx.wait();
    
    alert('Bid placed successfully!');
    displayAuctionState();
}

// Check and withdraw refund
async function withdrawRefund() {
    const userAddress = await signer.getAddress();
    const refund = await auctionContract.getBidderRefund(userAddress);
    
    if (refund.isZero()) {
        alert('No refund available');
        return;
    }
    
    const tx = await auctionContract.withdraw();
    await tx.wait();
    
    alert(`Withdrew ${ethers.utils.formatUnits(refund, 6)} USDC`);
}

// Listen for events
auctionContract.on("BidPlaced", (phase, bidder, amount) => {
    console.log('New bid:', ethers.utils.formatUnits(amount, 6), 'USDC');
    displayAuctionState();
});

auctionContract.on("PhaseAdvanced", (phase) => {
    console.log('Phase advanced to:', phase);
    displayAuctionState();
});

auctionContract.on("AuctionFinalized", (winner, amount) => {
    console.log('Winner:', winner);
    console.log('Amount:', ethers.utils.formatUnits(amount, 6), 'USDC');
    displayAuctionState();
});

// Initialize display
displayAuctionState();
setInterval(displayAuctionState, 30000); // Update every 30 seconds
```

---

# Integration Guide

## Frontend Integration Checklist

### Setup
- [ ] Add contract addresses to config
- [ ] Add ABIs to project
- [ ] Initialize ethers.js or web3.js
- [ ] Connect to Base network

### Display Current State
- [ ] Show current phase
- [ ] Show current leader
- [ ] Show current high bid
- [ ] Show time remaining
- [ ] Show NFT metadata for current phase

### User Actions
- [ ] Connect wallet button
- [ ] Approve USDC button
- [ ] Place bid form with validation
- [ ] Display user's refund balance
- [ ] Withdraw refund button

### Real-time Updates
- [ ] Listen to BidPlaced events
- [ ] Listen to PhaseAdvanced events
- [ ] Listen to AuctionFinalized event
- [ ] Auto-refresh auction state
- [ ] Update NFT display on phase change

### Error Handling
- [ ] Handle "Bid too low" error
- [ ] Handle insufficient USDC
- [ ] Handle insufficient approval
- [ ] Handle network errors
- [ ] Display user-friendly messages

---

## Backend Integration Checklist

### Monitoring
- [ ] Monitor BidPlaced events
- [ ] Monitor PhaseAdvanced events
- [ ] Monitor AuctionFinalized event
- [ ] Track all bidders and amounts
- [ ] Store historical data

### Admin Automation
- [ ] Check getTimeRemaining() regularly
- [ ] Auto-advance phases when ready
- [ ] Auto-advance NFT metadata
- [ ] Alert admin before finalization
- [ ] Backup all deployment data

### Analytics
- [ ] Track total bids placed
- [ ] Track unique bidders
- [ ] Track bid progression over time
- [ ] Calculate average bid increase
- [ ] Generate phase reports

---

# Common Patterns

## Check Before Action Pattern

```solidity
// Always check state before taking action
uint256 timeLeft = auction.getTimeRemaining();
require(timeLeft == 0, "Not ready to advance");

bool active = auction.isAuctionActive();
require(active, "Auction ended");

uint256 currentBid = auction.currentHighBid();
require(myBid > currentBid, "Bid too low");
```

## Safe Approval Pattern

```solidity
// Reset approval to 0 first (some tokens require this)
IERC20(usdc).approve(auction, 0);
IERC20(usdc).approve(auction, amount);

// Or use safer pattern
IERC20(usdc).approve(auction, type(uint256).max); // Infinite approval (use carefully)
```

## Pull Payment Pattern

```solidity
// Users withdraw their own refunds
uint256 refund = auction.getBidderRefund(msg.sender);
if (refund > 0) {
    auction.withdraw();
}

// Never rely on contract pushing funds to you
```

## Event Listening Pattern

```javascript
// Listen for specific events
auction.on("BidPlaced", handleNewBid);
auction.on("PhaseAdvanced", handlePhaseChange);

// Clean up listeners
auction.off("BidPlaced", handleNewBid);

// Or use .once() for one-time listeners
auction.once("AuctionFinalized", handleFinalization);
```

## Error Handling Pattern

```javascript
try {
    const tx = await auction.placeBid(amount);
    await tx.wait();
    console.log('Success!');
} catch (error) {
    if (error.message.includes('Bid too low')) {
        alert('Your bid must be higher');
    } else if (error.message.includes('USDC transfer failed')) {
        alert('Please approve USDC first');
    } else {
        console.error('Unknown error:', error);
    }
}
```

---

## USDC Decimal Handling

USDC uses 6 decimals (not 18 like ETH):

```javascript
// JavaScript/Frontend
const bidInUSDC = 1000; // 1000 USDC
const bidInWei = ethers.utils.parseUnits(bidInUSDC.toString(), 6);
// Result: 1000000000 (1000 * 10^6)

// Display USDC
const displayAmount = ethers.utils.formatUnits(amount, 6);
// "1000.0"
```

```solidity
// Solidity
uint256 oneThousandUSDC = 1000 * 10**6; // 1000000000
uint256 oneHundredUSDC = 100 * 10**6;   // 100000000
```

---

**For main documentation, see [DOCUMENTATION.md](./DOCUMENTATION.md)**
