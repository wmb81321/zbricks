# Auction Flow Documentation

> 📖 **[← Back to README](README.md)** | **[View Contract Reference](CONTRACT-REFERENCE.md)**

Complete guide to the multi-phase Continuous Clearing Auction (CCA) mechanism used in the ZBrick real estate tokenization system.

**Collection**: ZBRICKS (ZBR)  
**Architecture**: Factory-based multi-auction system  
**Last Updated**: February 9, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Deployment Architecture](#deployment-architecture)
3. [Auction Phases](#auction-phases)
   - [Phase 0: Initial Reveal](#phase-0-initial-reveal-48-hours)
   - [Phase 1: Second Reveal](#phase-1-second-reveal-24-hours)
   - [Phase 2: Final Reveal](#phase-2-final-reveal-24-hours)
   - [Phase 3: Post-Auction](#phase-3-post-auction)
3. [Bidding Mechanics](#bidding-mechanics)
4. [Refund System](#refund-system)
5. [NFT Metadata Evolution](#nft-metadata-evolution)
6. [State Transitions](#state-transitions)
7. [Example Scenarios](#example-scenarios)
8. [Security Considerations](#security-considerations)

---

## Overview

The ZBrick auction system implements a **4-phase Continuous Clearing Auction (CCA)** designed for progressive reveal of real estate tokenization:

### Auction Type: Continuous Clearing Auction (CCA)

**Key Principle**: Only the winner pays. All other bidders receive full refunds.

### Phase Structure

| Phase | Duration | Bidding | Metadata Reveal | Description |
|-------|----------|---------|-----------------|-------------|
| **Phase 0** | Configurable | ✅ Active | Initial | Basic property information |
| **Phase 1** | Configurable | ✅ Active | Second | Additional details revealed |
| **Phase 2** | Configurable | ✅ Active | Final | Complete information |
| **Phase 3** | Indefinite | ❌ Closed | Winner | Post-finalization |

**Total Duration**: Configurable (each phase must be > 0 seconds)

### Core Features

- 💰 **Winner-Takes-All**: Only final winner pays, all others refunded
- 🎫 **Participation Fee**: Optional one-time fee to participate (non-refundable)
- 🏦 **Treasury System**: All fees and winning bid go to designated treasury
- 🔄 **Incremental Bidding**: Users can add to their own bids multiple times
- 📊 **Cumulative Tracking**: userBids[address] stores total bid per user
- 📈 **Progressive Reveal**: More property info revealed each phase
- 🔒 **Phase Locking**: Each phase's winner locked when advancing
- 💸 **Pull Withdrawals**: Users can withdraw anytime before finalization
- ⏸️ **Emergency Pause**: Owner can pause for safety
- 🚨 **Emergency Withdrawal**: Owner can withdraw funds anytime for emergencies

---

## Deployment Architecture

### Factory-Based System

The ZBrick auction system uses a **factory pattern** for efficient multi-property deployment:

#### One-Time Infrastructure (Per Network)

```bash
# Deploy HouseNFT (ZBRICKS) and AuctionFactory once
forge script script/DeployFactory.s.sol:DeployFactory \
    --rpc-url <network> --broadcast --verify
```

**Deploys:**
1. `HouseNFT` ("ZBRICKS", "ZBR") - Multi-token NFT contract
2. `AuctionFactory` - Auction deployment factory with immutable references
3. Automatically sets factory as trusted in NFT contract via `setFactory()`

**Result:** Shared infrastructure ready for multiple independent auctions

#### Per-Property Auction Creation

```bash
# Update CreateAuction.s.sol with property parameters, then:
forge script script/CreateAuction.s.sol:CreateAuction \
    --rpc-url <network> --broadcast
```

**Configuration (in script):**
- Floor price (e.g., $10M)
- Phase durations (e.g., 7/14/30 days)
- Participation fee (e.g., $1000)
- Treasury address (Gnosis Safe)
- Admin address (controls phases)
- Phase URIs (IPFS metadata)

**Atomic Process:**
1. ✅ Mint NFT to factory (`nft.mintTo(factory)`)
2. ✅ Set 4 phase URIs for metadata reveals
3. ✅ Call `factory.createAuction()`:
   - Verifies factory owns NFT
   - Deploys new AuctionManager
   - Sets controller via trusted factory
   - Transfers NFT to auction
4. ✅ Auction ready for bidding

**Result:** Independent auction with own parameters and treasury

### Key Architecture Benefits

- ⚙️ **Deploy Once, Create Many**: Infrastructure deployed once per network
- 🛡️ **Security**: Atomic operations prevent partial states
- 💸 **Cost Efficient**: Reuse shared contracts (NFT + payment token)
- 🔐 **Access Control**: Factory trusted for controller setup, admin manages metadata
- 🏠 **Independent Auctions**: Each property has isolated auction with own parameters
- 🔄 **Scalable**: Easy to create multiple auctions without redeploying infrastructure

### Trust Model

```
┌─────────────────────────────────────────────────┐
│              Admin (from .env)                   │
│  - Controls NFT metadata (phase URIs)           │
│  - Sets factory (one-time only)                 │
│  - Can transfer admin role to multisig          │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│           Trusted Factory (immutable)            │
│  - Can set controllers on NFTs                  │
│  - Immutable NFT & payment token refs           │
│  - Atomic auction creation                      │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│        Per-Auction Admin (configurable)         │
│  - Controls auction phases                      │
│  - Manages pause/unpause                        │
│  - Independent per property                     │
└─────────────────────────────────────────────────┘
```

---

## Auction Phases

### Phase 0: Initial Reveal (Configurable, min 1 day)

**Duration**: Configurable (default 1 day minimum)  
**Status**: Bidding Active  
**NFT Metadata**: Basic information (Phase 0 URI)

#### What Happens

- Auction starts immediately upon deployment with Phase 0
- Initial property metadata revealed via Phase 0 URI
- Bidders can start placing INCREMENTAL bids
- Users can bid multiple times, each bid ADDS to their total
- Leader recalculated after every bid/withdrawal

#### Bidding Mechanics

```solidity
// Note: If participation fee is set, it's charged on first bid only
// Example: 10 USDC participation fee + 5,000 USDC bid

// First bid: Pay participation fee (10 USDC) + bid (5,000 USDC)
IERC20(paymentToken).approve(auctionAddress, 5010000000);
auction.placeBid(5000000000);  
// Participation fee (10 USDC) → treasury (non-refundable)
// Bid (5,000 USDC) → contract
// userBids[you] = 5,000 USDC
// hasPaid[you] = true

// Later, add 2,000 more USDC (no additional fee)
IERC20(paymentToken).approve(auctionAddress, 2000000000);
auction.placeBid(2000000000);  // userBids[you] = 7,000 USDC total!
// No fee charged - already paid on first bid

// Can withdraw bid amount (fee is non-refundable)
auction.withdrawBid();  // Get 7,000 USDC back (not the 10 USDC fee)
```

#### Bidding Requirements

- **Participation Fee** (if configured): One-time non-refundable fee charged on first bid only
- **Minimum Total**: New total bid (userBids[you] + newAmount) >= floorPrice
- **Increment Rule** (if enforced): If not current leader, new total >= currentHighBid * (1 + minBidIncrementPercent/100)
- **Payment Token**: USDC or configured payment token (6 decimals)
- **Approval**: Must approve payment token for (incremental amount + participation fee on first bid)

#### State Variables During Phase 0

```solidity
currentPhase = 0
currentLeader = <address with highest userBids[address]>
currentHighBid = <highest userBids value across all bidders>
userBids[Alice] = <Alice's cumulative bid>
userBids[Bob] = <Bob's cumulative bid>
phases[0].revealed = false  // Not locked yet
phases[0].startTime = <deployment timestamp>
phases[0].minDuration = 1 day (or configured value)
```

#### Example Timeline

```
Day 0, 00:00 - Auction starts, Phase 0 begins
Day 0, 02:00 - Alice bids 1000 USDC
               userBids[Alice] = 1000
               currentLeader = Alice, currentHighBid = 1000

Day 0, 06:00 - Bob bids 1200 USDC  
               userBids[Bob] = 1200
               currentLeader = Bob, currentHighBid = 1200
               Alice still has her 1000 USDC in contract

Day 0, 08:00 - Alice adds 500 USDC more
               userBids[Alice] = 1500
               currentLeader = Alice, currentHighBid = 1500
               Bob still has his 1200 USDC in contract

Day 0, 10:00 - Carol bids 2000 USDC
               userBids[Carol] = 2000
               currentLeader = Carol, currentHighBid = 2000

Day 1, 00:01 - Phase 0 duration complete, owner can advance
```

#### Phase 0 End Conditions

- ✅ Minimum duration elapsed (1+ day)
- ✅ Owner calls `advancePhase()` after duration met

---

### Phase 1: Second Reveal (Configurable, min 1 day)

**Duration**: Configurable (default 1 day minimum)  
**Status**: Bidding Active  
**NFT Metadata**: Second reveal (Phase 1 URI)

#### What Happens

- Owner calls `advancePhase()` to start Phase 1
- Phase 0 winner and bid locked in `phases[0]`
- Phase 0 marked as `revealed = true`
- NFT metadata automatically advances to Phase 1 URI
- Bidding continues - all previous bidders keep their funds in contract
- Users can still add to their bids or withdraw

#### Phase Advancement Process

```solidity
// Owner checks readiness
uint256 elapsed = block.timestamp - phases[0].startTime;
require(elapsed >= phases[0].minDuration, "Phase 0 not complete");

// Advance auction phase (owner only)
auction.advancePhase();  // Locks Phase 0 data, starts Phase 1, advances NFT metadata

// Phase 0 data now locked:
phases[0].leader = <Phase 0 leader address>
phases[0].highBid = <Phase 0 high bid>
phases[0].revealed = true
```

#### State Variables During Phase 1

```solidity
currentPhase = 1
phases[0].revealed = true           // Phase 0 locked
phases[0].leader = Carol            // Locked leader from Phase 0
phases[0].highBid = 2000            // Locked high bid
phases[1].startTime = <now>
phases[1].minDuration = 1 day
phases[1].revealed = false

// All user bids still active:
userBids[Alice] = 1500
userBids[Bob] = 1200  
userBids[Carol] = 2000
currentLeader = Carol  // May change as more bids come in
currentHighBid = 2000
```

#### Bidding Continues

- ALL previous bidders' funds remain in contract
- Anyone can add to their bid or withdraw
- New bidders can join
- Leader recalculated after every change
- No automatic refunds - users must withdraw manually

#### Example Timeline

```
Day 1, 00:01 - Owner advances to Phase 1
               Phase 0 locked: Carol leads with 2000 USDC
               Phase 1 starts, NFT shows Phase 1 metadata

Day 1, 02:00 - Dave joins, bids 2500 USDC
               userBids[Dave] = 2500
               currentLeader = Dave, currentHighBid = 2500

Day 1, 08:00 - Carol adds 1000 USDC more
               userBids[Carol] = 3000 total
               currentLeader = Carol, currentHighBid = 3000

Day 1, 10:00 - Bob withdraws his 1200 USDC (decides not to compete)
               userBids[Bob] = 0

Day 2, 00:01 - Phase 1 duration complete, owner can advance
```

---

### Phase 2: Final Reveal (Configurable, min 1 day)

**Duration**: Configurable (default 1 day minimum)  
**Status**: Bidding Active (Last Chance)  
**NFT Metadata**: Complete information (Phase 2 URI)

#### What Happens

- Owner calls `advancePhase()` to start Phase 2
- Phase 1 winner and bid locked in `phases[1]`
- Phase 1 marked as `revealed = true`
- NFT metadata automatically advances to Phase 2 URI
- Final opportunity for bidding - same mechanics as Phase 0 and 1

#### Phase Advancement Process

```solidity
// Owner checks readiness
uint256 elapsed = block.timestamp - phases[1].startTime;
require(elapsed >= phases[1].minDuration, "Phase 1 not complete");

// Advance auction phase (owner only)
auction.advancePhase();  // Locks Phase 1, starts Phase 2, advances NFT metadata

// Phase 1 data now locked:
phases[1].leader = <Phase 1 leader>
phases[1].highBid = <Phase 1 high bid>
phases[1].revealed = true
```

```solidity
currentPhase = 2
phases[1].revealed = true           // Phase 1 locked
phases[1].leader = <Phase 1 leader>
phases[1].highBid = <Phase 1 high bid>
phases[2].startTime = <now>
phases[2].minDuration = 1 day
phases[2].revealed = false

// All user bids still active:
userBids[Alice] = 1500 (or 0 if withdrew)
userBids[Carol] = 3000
userBids[Dave] = 2500
currentLeader = Carol
currentHighBid = 3000
```

#### Final Bidding Round

- All property information revealed (Phase 2 URI)
- Bidders make informed final decisions  
- Most competitive phase typically
- Last chance to bid or increase existing bids
- Can still withdraw before finalization

#### Example Timeline

```
Day 2, 00:01 - Owner advances to Phase 2
               Phase 1 locked: Carol led with 3000 USDC
               Phase 2 starts, NFT shows complete info

Day 2, 04:00 - Eve joins, bids 3500 USDC
               userBids[Eve] = 3500
               currentLeader = Eve, currentHighBid = 3500

Day 2, 12:00 - Carol adds 1000 USDC more
               userBids[Carol] = 4000 total
               currentLeader = Carol, currentHighBid = 4000

Day 2, 20:00 - Eve adds 1000 USDC more
               userBids[Eve] = 4500 total
               currentLeader = Eve, currentHighBid = 4500

Day 3, 00:01 - Phase 2 duration complete, owner can finalize
```

---

### Phase 3: Post-Auction

**Duration**: Indefinite  
**Status**: Bidding Closed  
**NFT Metadata**: Winner reveal (Phase 3 URI)

#### What Happens

- Owner calls `finalizeAuction()` to complete auction
- Phase 2 winner and bid locked in `phases[2]`
- `finalized = true`
- NFT automatically transferred to winner (currentLeader)
- NFT automatically advanced to Phase 3 metadata
- Winner's payment held in contract for owner withdrawal
- All losing bidders keep their funds in contract until they withdraw

#### Finalization Process

```solidity
// Owner checks readiness
require(currentPhase == 2, "Must be in Phase 2");
uint256 elapsed = block.timestamp - phases[2].startTime;
require(elapsed >= phases[2].minDuration, "Phase 2 not complete");

// Finalize auction (owner only)
auction.finalizeAuction();

// What happens automatically:
// 1. Locks Phase 2 data
// 2. Sets winner = currentLeader
// 3. Transfers NFT to winner
// 4. Advances NFT to Phase 3 metadata
// 5. Sets finalized = true
```

#### State Variables After Finalization

```solidity
currentPhase = 2  // Stays at 2
finalized = true
winner = Eve  // Current leader at finalization
phases[2].revealed = true
phases[2].leader = Eve
phases[2].highBid = 4500

// User bids remain:
userBids[Eve] = 4500      // Winner - CANNOT withdraw
userBids[Carol] = 4000    // Can withdraw
userBids[Dave] = 2500     // Can withdraw
userBids[Alice] = 1500    // Can withdraw (if didn't withdraw earlier)
```

#### Post-Finalization Actions

**Winner** (Eve in example):
- ✅ Owns NFT (automatically transferred)
- ✅ Can view winner metadata (NFT shows Phase 3 URI)
- ❌ **CANNOT withdraw** (they won, their payment stays for owner)

**Losing Bidders** (Carol, Dave, Alice):
- ✅ Can withdraw FULL bid at any time via `withdrawBid()`
- ✅ No fees, no penalties, no deadline
- ✅ Pull refunds when convenient (gas efficient)
- ⚠️ Must manually call `withdrawBid()` - no automatic refunds

**Owner**:
- ✅ Can withdraw proceeds (winning bid amount) via `withdrawProceeds()`
- ✅ Can only withdraw winning bid once
- ✅ Receives: userBids[winner] amount

#### Example Timeline

```
Day 3, 00:01 - Owner finalizes auction
               Phase 2 locked: Eve won with 4500 USDC
               NFT automatically transferred to Eve
               NFT metadata automatically advances to Phase 3

Day 3, 01:00 - Carol withdraws her bid (4000 USDC back to Carol)
               userBids[Carol] = 0

Day 3, 02:00 - Dave withdraws his bid (2500 USDC back to Dave)
               userBids[Dave] = 0

Day 3, 03:00 - Owner withdraws proceeds (4500 USDC from Eve's bid)

Day 5, 10:00 - Alice finally withdraws (1500 USDC back to Alice)
               userBids[Alice] = 0
```

---

## Bidding Mechanics

### How Incremental Bidding Works

The auction uses **cumulative incremental bidding** where each `placeBid()` call **adds** to your existing total bid.

**Key Concept**: `userBids[address]` stores your total cumulative bid, not individual bids.

### Complete Bidding Flow

#### 1. Check Current Auction State

```solidity
// Check if bidding is open
uint8 phase = auction.currentPhase();
bool finalized = auction.finalized();
address leader = auction.currentLeader();
uint256 highBid = auction.currentHighBid();

require(phase <= 2, "Bidding closed");
require(!finalized, "Auction ended");
```

```bash
# Check auction status
cast call <AUCTION_ADDRESS> "currentPhase()" --rpc-url base_sepolia
cast call <AUCTION_ADDRESS> "currentLeader()" --rpc-url base_sepolia
cast call <AUCTION_ADDRESS> "currentHighBid()" --rpc-url base_sepolia
cast call <AUCTION_ADDRESS> "finalized()" --rpc-url base_sepolia
```

#### 2. Check Your Current Bid

```solidity
uint256 myCurrentBid = auction.userBids(msg.sender);
// Returns your total cumulative bid
```

```bash
cast call <AUCTION_ADDRESS> "userBids(address)" <YOUR_ADDRESS> --rpc-url base_sepolia
```

```javascript
// Frontend
const myBid = await auction.userBids(myAddress);
console.log('My current total bid:', ethers.formatUnits(myBid, 6), 'USDC');
```

#### 3. Calculate Incremental Amount Needed

```javascript
// Example: You have 1000 USDC bid, want to reach 1500 USDC total
const myCurrentBid = await auction.userBids(myAddress);
const desiredTotal = ethers.parseUnits('1500', 6);
const incrementalAmount = desiredTotal - myCurrentBid;

// Result: incrementalAmount = 500 USDC worth of tokens
```

#### 4. Approve Payment Token (Incremental Amount)

```solidity
// Approve only the incremental amount you're adding
IERC20(paymentToken).approve(auctionAddress, incrementalAmount);
```

```bash
cast send <PAYMENT_TOKEN_ADDRESS> \
    "approve(address,uint256)" \
    <AUCTION_ADDRESS> \
    500000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

```javascript
// Frontend
const paymentToken = new ethers.Contract(paymentTokenAddress, IERC20_ABI, signer);
const approveTx = await paymentToken.approve(auctionAddress, incrementalAmount);
await approveTx.wait();
```

#### 5. Place Incremental Bid

```solidity
// Add 500 USDC to your existing 1000 USDC bid
auction.placeBid(500000000);  // Your total becomes 1500 USDC
```

```bash
cast send <AUCTION_ADDRESS> \
    "placeBid(uint256)" \
    500000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

```javascript
// Frontend
const bidTx = await auction.placeBid(incrementalAmount);
await bidTx.wait();

// Verify new total
const newTotal = await auction.userBids(myAddress);
console.log('New total bid:', ethers.formatUnits(newTotal, 6), 'USDC');
```

### What Happens When You Call placeBid()

```solidity
// Internal contract logic:

function placeBid(uint256 amount) external whenNotPaused nonReentrant {
    // 1. Validate auction state
    require(!finalized, "Auction ended");
    require(currentPhase <= 2, "Bidding closed");
    require(amount > 0, "Amount must be > 0");
    
    // 2. Calculate new total
    uint256 newTotalBid = userBids[msg.sender] + amount;
    
    // 3. Validate minimum requirements
    require(newTotalBid >= floorPrice, "Below floor price");
    
    // 4. Validate increment (if enforced and not current leader)
    if (enforceMinIncrement && msg.sender != currentLeader && currentHighBid > 0) {
        uint256 minRequired = currentHighBid + (currentHighBid * minBidIncrementPercent / 100);
        require(newTotalBid >= minRequired, "Increment too low");
    }
    
    // 5. Transfer incremental tokens from you
    paymentToken.transferFrom(msg.sender, address(this), amount);
    
    // 6. Update your total bid
    userBids[msg.sender] = newTotalBid;
    
    // 7. Add to bidders set (if new)
    bidders.add(msg.sender);
    
    // 8. Recalculate leader (checks ALL bidders)
    _updateLeader();  // Iterates through all userBids to find highest
    
    // 9. Emit event
    emit BidPlaced(msg.sender, amount, newTotalBid, currentPhase);
}
```

### Bid Requirements

| Requirement | Description | Example |
|-------------|-------------|---------|
| **Minimum Total Bid** | Your new total must be >= floorPrice | If floor is 1000 USDC, userBids[you] must reach 1000+ |
| **Minimum Increment** (if enforced) | If not current leader, new total must be >= currentHighBid * (1 + minBidIncrementPercent/100) | If high bid is 2000 USDC and increment is 5%, you need 2100+ USDC total |
| **Phase Check** | Must be in phase 0, 1, or 2 | Phase 3 or finalized = no bidding |
| **Approval** | Must approve payment token for incremental amount | Approve exact amount you're adding |
| **Not Paused** | Auction must not be paused | Owner can pause for emergencies |

### Bidding Scenarios

#### Scenario A: First-Time Bidder

```javascript
// Alice has never bid before
const aliceBid = await auction.userBids(aliceAddress);
// Returns: 0

// Alice wants to bid 1500 USDC
await paymentToken.approve(auction, ethers.parseUnits('1500', 6));
await auction.placeBid(ethers.parseUnits('1500', 6));

// Result:
// userBids[Alice] = 1500 USDC
// If highest, currentLeader = Alice, currentHighBid = 1500
```

#### Scenario B: Increasing Your Own Bid

```javascript
// Bob already bid 2000 USDC
const bobBid = await auction.userBids(bobAddress);
// Returns: 2000000000 (2000 USDC)

// Bob wants to increase to 3000 USDC total
const increment = ethers.parseUnits('1000', 6);
await paymentToken.approve(auction, increment);
await auction.placeBid(increment);

// Result:
// userBids[Bob] = 3000 USDC total
// Bob paid: 2000 + 1000 = 3000 USDC cumulative
```

#### Scenario C: Multiple Bidders Competing

```javascript
// State: Carol leads with 2500 USDC
// userBids[Carol] = 2500

// Dave bids 3000 USDC (new)
await auction.placeBid(ethers.parseUnits('3000', 6));
// userBids[Dave] = 3000
// currentLeader = Dave, currentHighBid = 3000
// Carol's 2500 USDC still in contract

// Carol adds 1000 more (2500 + 1000 = 3500 total)
await auction.placeBid(ethers.parseUnits('1000', 6));
// userBids[Carol] = 3500
// currentLeader = Carol, currentHighBid = 3500
// Dave's 3000 USDC still in contract

// Dave can withdraw his 3000 USDC or add more to compete
```

#### Scenario D: Strategic Withdrawal and Re-entry

```javascript
// Eve bid 1800 USDC but sees she's losing
const eveBid = await auction.userBids(eveAddress);
// Returns: 1800000000

// Eve withdraws to free up capital
await auction.withdrawBid();
// userBids[Eve] = 0
// Eve receives 1800 USDC back

// Eve can bid again later with different strategy
await auction.placeBid(ethers.parseUnits('4000', 6));
// userBids[Eve] = 4000 (starts fresh from 0)
```
|-------------|-------------|
| **Amount** | Must exceed `currentHighBid` |
| **Phase** | Must be Phase 0, 1, or 2 |
| **Status** | Auction not paused, not finalized |
| **Balance** | Bidder has sufficient USDC |
| **Approval** | Auction approved to spend USDC |

---

## Refund System

### Pull Payment Pattern

The auction uses a **pull payment pattern** for refunds, which is safer than push payments.

#### Why Pull Pattern?

- ✅ **Gas Efficient**: No loops pushing to multiple addresses
- ✅ **Safer**: No reentrancy attacks via refund recipients
- ✅ **User Control**: Users withdraw when convenient
- ✅ **Always Available**: Can withdraw even if auction paused

### How Refunds Work

```solidity
// When you're outbid:
// 1. Your previous bid moved to refundBalance mapping
refundBalance[yourAddress] += yourPreviousBid;

// 2. You can withdraw anytime
uint256 refund = refundBalance[yourAddress];
auction.withdraw();

// 3. Refund transferred to you
usdc.transfer(msg.sender, refund);
refundBalance[yourAddress] = 0;
```

### Checking Your Refund

```solidity
// Contract call
uint256 myRefund = auction.getBidderRefund(myAddress);
```

```bash
cast call <AUCTION_ADDRESS> \
    "getBidderRefund(address)" \
    <YOUR_ADDRESS> \
    --rpc-url base_sepolia
```

```javascript
// Frontend
const refund = await auctionContract.getBidderRefund(userAddress);
const refundUSDC = ethers.utils.formatUnits(refund, 6);
console.log(`Your refund: ${refundUSDC} USDC`);
```

### Withdrawing Refunds

```solidity
// Contract call
auction.withdraw();
```

```bash
cast send <AUCTION_ADDRESS> "withdraw()" \
    --private-key $PRIVATE_KEY \
    --rpc-url base_sepolia
```

```javascript
// Frontend
async function withdrawRefund() {
    const refund = await auctionContract.getBidderRefund(userAddress);
    
    if (refund.isZero()) {
        alert('No refund available');
        return;
    }
    
    const tx = await auctionContract.withdraw();
    await tx.wait();
    
    alert(`Withdrew ${ethers.utils.formatUnits(refund, 6)} USDC`);
}
```

### Refund Timeline Example

```
Timeline:
--------
Day 0, 02:00 - Alice bids 1000 USDC
               currentLeader: Alice (1000 USDC held)
               
Day 0, 06:00 - Bob bids 1200 USDC
               refundBalance[Alice] = 1000 USDC  ← Refund available
               currentLeader: Bob (1200 USDC held)
               
Day 0, 08:00 - Alice withdraws refund
               Alice receives 1000 USDC back
               
Day 1, 12:00 - Carol bids 1500 USDC
               refundBalance[Bob] = 1200 USDC  ← Refund available
               currentLeader: Carol (1500 USDC held)
               
Day 4, 00:00 - Auction finalized, Carol wins
               Carol's 1500 USDC held by admin
               Bob can withdraw 1200 USDC anytime
```

### Important Notes

- ✅ Can withdraw refunds even if auction paused
- ✅ Can withdraw refunds even after auction finalized
- ✅ No time limit to withdraw
- ✅ No penalties or fees
- ❌ Current leader cannot withdraw (they're winning!)
- ❌ Winner cannot withdraw after finalization (they won, payment held)

---

## NFT Metadata Evolution

The HouseNFT contract returns different metadata URIs based on the current phase.

### Metadata Structure

```json
{
  "name": "123 Main Street, City, State",
  "description": "Description varies by phase",
  "image": "ipfs://QmXYZ.../image.png",
  "external_url": "https://zbrick.io/property/1",
  "attributes": [
    {"trait_type": "Address", "value": "123 Main Street"},
    {"trait_type": "City", "value": "City Name"},
    {"trait_type": "State", "value": "State"},
    {"trait_type": "Square Feet", "value": "2000"},
    {"trait_type": "Bedrooms", "value": "3"},
    {"trait_type": "Bathrooms", "value": "2"},
    {"trait_type": "Phase", "value": "Phase 0"}
  ]
}
```

### Phase 0 Metadata (Initial Reveal)

**URI**: `phaseURIs[0]`  
**Information Level**: Basic

```json
{
  "name": "Residential Property - Phase 0",
  "description": "A tokenized residential property. Bidding is active in Phase 0.",
  "image": "ipfs://Qm.../phase0-exterior.png",
  "attributes": [
    {"trait_type": "Property Type", "value": "Residential"},
    {"trait_type": "Location", "value": "General Area"},
    {"trait_type": "Phase", "value": "Phase 0"},
    {"trait_type": "Status", "value": "Bidding Active"}
  ]
}
```

**What's Revealed**:
- Property type (residential, commercial, etc.)
- General location (city/area)
- Basic features
- Exterior photos

**What's Hidden**:
- Exact address
- Interior photos
- Detailed floor plans
- Property history
- Current tenants (if any)

---

### Phase 1 Metadata (Second Reveal)

**URI**: `phaseURIs[1]`  
**Information Level**: Detailed

```json
{
  "name": "123 Main Street - Phase 1",
  "description": "Additional property details revealed. Bidding continues in Phase 1.",
  "image": "ipfs://Qm.../phase1-interior.png",
  "attributes": [
    {"trait_type": "Address", "value": "123 Main Street"},
    {"trait_type": "City", "value": "Springfield"},
    {"trait_type": "State", "value": "IL"},
    {"trait_type": "Square Feet", "value": "2000"},
    {"trait_type": "Bedrooms", "value": "3"},
    {"trait_type": "Bathrooms", "value": "2"},
    {"trait_type": "Year Built", "value": "2015"},
    {"trait_type": "Phase", "value": "Phase 1"},
    {"trait_type": "Status", "value": "Bidding Active"},
    {"trait_type": "Phase 0 Winner", "value": "0x123..."}
  ]
}
```

**What's Revealed**:
- Exact address
- Property specifications
- Interior photos
- Floor plans
- Phase 0 auction results

**What's Hidden**:
- Detailed inspection reports
- Financial documents
- Tenant agreements
- Complete property history

---

### Phase 2 Metadata (Final Reveal)

**URI**: `phaseURIs[2]`  
**Information Level**: Complete

```json
{
  "name": "123 Main Street - Complete Information",
  "description": "All property information revealed. Final bidding phase.",
  "image": "ipfs://Qm.../phase2-complete.png",
  "attributes": [
    {"trait_type": "Address", "value": "123 Main Street"},
    {"trait_type": "City", "value": "Springfield"},
    {"trait_type": "State", "value": "IL"},
    {"trait_type": "Square Feet", "value": "2000"},
    {"trait_type": "Bedrooms", "value": "3"},
    {"trait_type": "Bathrooms", "value": "2"},
    {"trait_type": "Year Built", "value": "2015"},
    {"trait_type": "Last Appraised Value", "value": "$350,000"},
    {"trait_type": "Monthly Rental Income", "value": "$2,500"},
    {"trait_type": "Property Tax", "value": "$4,200/year"},
    {"trait_type": "Phase", "value": "Phase 2"},
    {"trait_type": "Status", "value": "Final Bidding"},
    {"trait_type": "Phase 0 Winner", "value": "0x123..."},
    {"trait_type": "Phase 1 Winner", "value": "0x456..."}
  ]
}
```

**What's Revealed**:
- Complete property documentation
- Inspection reports
- Financial details
- Tenant information
- Property history
- Phase 1 auction results
- All previous winners

---

### Phase 3 Metadata (Winner Reveal)

**URI**: `phaseURIs[3]`  
**Information Level**: Post-Auction

```json
{
  "name": "123 Main Street - SOLD",
  "description": "Property sold to winning bidder.",
  "image": "ipfs://Qm.../phase3-sold.png",
  "attributes": [
    {"trait_type": "Address", "value": "123 Main Street"},
    {"trait_type": "Status", "value": "Sold"},
    {"trait_type": "Sale Price", "value": "2500 USDC"},
    {"trait_type": "Winner", "value": "0x789..."},
    {"trait_type": "Finalized", "value": "2024-01-15"},
    {"trait_type": "Phase 0 Winner", "value": "0x123..."},
    {"trait_type": "Phase 1 Winner", "value": "0x456..."},
    {"trait_type": "Phase 2 Winner", "value": "0x789..."}
  ]
}
```

**What's Revealed**:
- Final sale information
- Winner address
- All phase winners
- Complete auction history

---

### How Metadata Updates

```solidity
// Admin advances auction phase
auction.advancePhase();  // Phase 0 → Phase 1

// Admin advances NFT metadata
houseNFT.advancePhase(1);  // Metadata Phase 0 → Phase 1

// NFT now returns Phase 1 URI
string memory uri = houseNFT.tokenURI(1);
// Returns: phaseURIs[1]
```

### Frontend Display

```javascript
// Fetch current metadata
async function displayNFT() {
    const currentPhase = await nftContract.currentPhase();
    const tokenURI = await nftContract.tokenURI(1);
    
    // Fetch metadata from IPFS/storage
    const response = await fetch(tokenURI);
    const metadata = await response.json();
    
    // Display
    document.getElementById('nft-name').textContent = metadata.name;
    document.getElementById('nft-description').textContent = metadata.description;
    document.getElementById('nft-image').src = metadata.image;
    document.getElementById('current-phase').textContent = currentPhase;
    
    // Display attributes
    metadata.attributes.forEach(attr => {
        console.log(`${attr.trait_type}: ${attr.value}`);
    });
}

// Listen for phase changes
nftContract.on("PhaseAdvanced", async (newPhase) => {
    console.log(`NFT advanced to phase ${newPhase}`);
    await displayNFT(); // Refresh display
});
```

---

## State Transitions

### State Diagram

```
┌─────────────┐
│   Deploy    │
│  Contracts  │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│    Phase 0          │  48 hours minimum
│  Initial Reveal     │  Bidding: ✅ Active
│  Bidding Active     │  Metadata: Basic Info
└──────┬──────────────┘
       │ advancePhase()
       │ (after 48h)
       ▼
┌─────────────────────┐
│    Phase 1          │  24 hours minimum
│  Second Reveal      │  Bidding: ✅ Active
│  Bidding Active     │  Metadata: Detailed Info
│  Phase 0 Locked     │  Phase 0: ✅ Revealed
└──────┬──────────────┘
       │ advancePhase()
       │ (after 24h)
       ▼
┌─────────────────────┐
│    Phase 2          │  24 hours minimum
│  Final Reveal       │  Bidding: ✅ Active
│  Bidding Active     │  Metadata: Complete Info
│  Phase 1 Locked     │  Phase 0-1: ✅ Revealed
└──────┬──────────────┘
       │ finalizeAuction()
       │ (after 24h)
       ▼
┌─────────────────────┐
│  Post-Auction       │  Indefinite
│  Finalized          │  Bidding: ❌ Closed
│  NFT Transferred    │  Metadata: Winner Info
│  Phase 2 Locked     │  All Phases: ✅ Revealed
└─────────────────────┘
```

### Transition Requirements

#### Phase 0 → Phase 1

```solidity
// Requirements
require(currentPhase == 0, "Must be Phase 0");
require(block.timestamp >= phases[0].startTime + phases[0].minDuration, "Duration not met");
require(!paused, "Auction paused");
require(!finalized, "Already finalized");

// Actions
1. Lock Phase 0 data (leader, highBid)
2. Mark phases[0].revealed = true
3. Set currentPhase = 1
4. Set phases[1].startTime = block.timestamp
5. Emit PhaseAdvanced(1)

// Separate NFT update (admin)
houseNFT.advancePhase(1);
```

#### Phase 1 → Phase 2

```solidity
// Requirements
require(currentPhase == 1, "Must be Phase 1");
require(block.timestamp >= phases[1].startTime + phases[1].minDuration, "Duration not met");
require(!paused, "Auction paused");
require(!finalized, "Already finalized");

// Actions
1. Lock Phase 1 data (leader, highBid)
2. Mark phases[1].revealed = true
3. Set currentPhase = 2
4. Set phases[2].startTime = block.timestamp
5. Emit PhaseAdvanced(2)

// Separate NFT update (admin)
houseNFT.advancePhase(2);
```

#### Phase 2 → Finalized

```solidity
// Requirements
require(currentPhase == 2, "Must be Phase 2");
require(block.timestamp >= phases[2].startTime + phases[2].minDuration, "Duration not met");
require(currentLeader != address(0), "No winner");
require(!finalized, "Already finalized");

// Actions
1. Lock Phase 2 data (leader, highBid)
2. Mark phases[2].revealed = true
3. Set finalized = true
4. Transfer NFT to winner: houseNFT.transferFrom(address(this), currentLeader, 1)
5. Emit AuctionFinalized(currentLeader, currentHighBid)

// Separate NFT update (admin)
houseNFT.advancePhase(3);
```

---

## Example Scenarios

### Scenario 1: Single Bidder Throughout

```
Timeline:
--------
Day 0, 00:00 - Auction starts (Phase 0)
Day 0, 02:00 - Alice bids 1000 USDC
               currentLeader: Alice (1000 USDC)

Day 2, 00:00 - Phase 0 complete (48h)
               Admin advances to Phase 1
               Phase 0 locked: Alice won with 1000 USDC

Day 3, 00:00 - Phase 1 complete (24h)
               No new bids
               Admin advances to Phase 2
               Phase 1 locked: Alice won with 1000 USDC

Day 4, 00:00 - Phase 2 complete (24h)
               No new bids
               Admin finalizes auction
               Phase 2 locked: Alice won with 1000 USDC
               NFT transferred to Alice
               Alice pays 1000 USDC total

Result: Alice wins all phases with 1000 USDC
```

---

### Scenario 2: Competitive Bidding War

```
Timeline:
--------
Day 0, 00:00 - Auction starts (Phase 0)

Day 0, 02:00 - Alice bids 1000 USDC
               currentLeader: Alice (1000 USDC)

Day 0, 06:00 - Bob bids 1200 USDC
               refundBalance[Alice] = 1000 USDC
               currentLeader: Bob (1200 USDC)

Day 1, 12:00 - Carol bids 1500 USDC
               refundBalance[Bob] = 1200 USDC
               currentLeader: Carol (1500 USDC)

Day 2, 00:00 - Phase 0 complete
               Admin advances to Phase 1
               Phase 0 locked: Carol won with 1500 USDC

Day 2, 04:00 - Dave sees detailed info, bids 1600 USDC
               refundBalance[Carol] = 1500 USDC
               currentLeader: Dave (1600 USDC)

Day 2, 08:00 - Carol withdraws 1500 USDC refund

Day 2, 12:00 - Carol bids 1800 USDC (new info convinced her)
               refundBalance[Dave] = 1600 USDC
               currentLeader: Carol (1800 USDC)

Day 3, 00:00 - Phase 1 complete
               Admin advances to Phase 2
               Phase 1 locked: Carol won with 1800 USDC

Day 3, 04:00 - Eve sees complete info, bids 2000 USDC
               refundBalance[Carol] = 1800 USDC
               currentLeader: Eve (2000 USDC)

Day 3, 12:00 - Carol withdraws 1800 USDC refund

Day 3, 20:00 - Carol makes final bid: 2200 USDC
               refundBalance[Eve] = 2000 USDC
               currentLeader: Carol (2200 USDC)

Day 4, 00:00 - Phase 2 complete
               Admin finalizes auction
               Phase 2 locked: Carol won with 2200 USDC
               NFT transferred to Carol
               Carol pays 2200 USDC total

Post-Auction:
Day 4, 01:00 - Alice already withdrew (1000 USDC)
Day 4, 02:00 - Bob withdraws refund (1200 USDC)
Day 4, 03:00 - Dave withdraws refund (1600 USDC)
Day 4, 04:00 - Eve withdraws refund (2000 USDC)
Day 5, 00:00 - Admin withdraws proceeds (2200 USDC)

Result: 
- Carol wins with 2200 USDC final bid
- All other bidders fully refunded
- Total refunds paid: 5800 USDC
- Only Carol pays (net: 2200 USDC)
```

---

### Scenario 3: Emergency Pause

```
Timeline:
--------
Day 0, 00:00 - Auction starts (Phase 0)
Day 0, 02:00 - Alice bids 1000 USDC
Day 0, 06:00 - Bob bids 1200 USDC

Day 1, 00:00 - Admin discovers suspicious activity
               Admin calls pause()
               paused = true

Day 1, 02:00 - Alice tries to withdraw refund
               ✅ Success! (withdrawals not blocked)
               Alice receives 1000 USDC

Day 1, 04:00 - Carol tries to bid
               ❌ Rejected: "Auction paused"

Day 1, 06:00 - Admin calls advancePhase()
               ❌ Rejected: "Auction paused"

Day 1, 12:00 - Admin resolves issue
               Admin calls unpause()
               paused = false

Day 1, 14:00 - Carol bids 1500 USDC
               ✅ Success! Bidding resumed
               refundBalance[Bob] = 1200 USDC
               currentLeader: Carol (1500 USDC)

Auction continues normally...
```

---

### Scenario 4: Late Stage Dramatic Increase

```
Timeline:
--------
Phase 0 (48 hours):
  Day 0 - Only small bids: max 1000 USDC
  Phase 0 locked: Alice won with 1000 USDC

Phase 1 (24 hours):
  Day 2 - Address revealed, bids up to 1500 USDC
  Phase 1 locked: Bob won with 1500 USDC

Phase 2 (24 hours):
  Day 3, 00:01 - Complete info revealed
  Day 3, 00:30 - Investor Carol analyzes financials
  Day 3, 02:00 - Carol bids 5000 USDC! (3.3x previous)
                 refundBalance[Bob] = 1500 USDC
                 currentLeader: Carol (5000 USDC)
  
  Day 3, 04:00 - Dave counters: 5500 USDC
                 refundBalance[Carol] = 5000 USDC
  
  Day 3, 08:00 - Carol withdraws 5000 USDC
  Day 3, 10:00 - Carol final bid: 6000 USDC
                 refundBalance[Dave] = 5500 USDC
                 currentLeader: Carol (6000 USDC)

Day 4, 00:00 - Finalized
               Carol wins with 6000 USDC
               40% of bids happened in last 24 hours

Result: Complete information triggered aggressive bidding
```

---

## Security Considerations

### For Bidders

#### Before Bidding

```javascript
// 1. Verify contract addresses on block explorer
const expectedNFT = "0xcd142fccc9685ba2eaeb2b17bf7adcd25cc4beb5";
const expectedAuction = "0x1d5854ef9b5fd15e1f477a7d15c94ea0e795d9a5";

// 2. Check auction state
const state = await auction.getAuctionState();
console.log("Phase:", state._currentPhase);
console.log("Bidding open:", state._biddingOpen);
console.log("Finalized:", state._finalized);

// 3. Verify USDC approval
const allowance = await usdc.allowance(myAddress, auctionAddress);
console.log("Current allowance:", ethers.utils.formatUnits(allowance, 6));

// 4. Check your USDC balance
const balance = await usdc.balanceOf(myAddress);
console.log("USDC balance:", ethers.utils.formatUnits(balance, 6));
```

#### During Bidding

```javascript
// 1. Use exact USDC amounts (6 decimals)
const bidAmount = ethers.utils.parseUnits("1000", 6); // Correct
// NOT: ethers.utils.parseEther("1000") // Wrong! (18 decimals)

// 2. Check current high bid before bidding
const currentHighBid = await auction.currentHighBid();
if (bidAmount.lte(currentHighBid)) {
    alert("Bid must be higher than current bid");
    return;
}

// 3. Monitor for outbids
auction.on("BidPlaced", (phase, bidder, amount) => {
    if (bidder !== myAddress && amount.gt(myBid)) {
        alert("You've been outbid!");
    }
});

// 4. Withdraw refunds promptly
const refund = await auction.getBidderRefund(myAddress);
if (refund.gt(0)) {
    await auction.withdraw();
}
```

#### Common Mistakes to Avoid

```javascript
// ❌ WRONG: Using 18 decimals for USDC
const wrongAmount = ethers.utils.parseEther("1000"); // 1000 * 10^18

// ✅ CORRECT: Using 6 decimals for USDC
const correctAmount = ethers.utils.parseUnits("1000", 6); // 1000 * 10^6

// ❌ WRONG: Bidding without approval
await auction.placeBid(amount); // Will fail

// ✅ CORRECT: Approve first
await usdc.approve(auctionAddress, amount);
await auction.placeBid(amount);

// ❌ WRONG: Assuming you can withdraw as current leader
if (await auction.currentLeader() === myAddress) {
    await auction.withdraw(); // Will fail
}

// ✅ CORRECT: Only withdraw if you have refund
const refund = await auction.getBidderRefund(myAddress);
if (refund.gt(0)) {
    await auction.withdraw();
}
```

---

### For Admin

#### Phase Management

```javascript
// 1. Check time remaining before advancing
const timeLeft = await auction.getTimeRemaining();
if (timeLeft > 0) {
    console.log(`Wait ${timeLeft} seconds before advancing`);
    return;
}

// 2. Advance auction and NFT together
await auction.advancePhase(); // Auction phase
await houseNFT.advancePhase(newPhase); // NFT metadata

// 3. Monitor for errors
try {
    await auction.advancePhase();
} catch (error) {
    if (error.message.includes("Duration not met")) {
        console.log("Wait longer before advancing");
    } else if (error.message.includes("Already revealed")) {
        console.log("Phase already advanced");
    }
}
```

#### Emergency Procedures

```javascript
// 1. Pause if suspicious activity detected
await auction.pause();
console.log("Auction paused, investigating...");

// 2. Users can still withdraw (safe)
// ... investigate issue ...

// 3. Resume when safe
await auction.unpause();
console.log("Auction resumed");

// 4. If critical issue, do NOT finalize
// Allow all users to withdraw refunds
// Consider redeployment with fixes
```

---

### For Developers

#### Integration Checklist

```javascript
// 1. Event listeners with error handling
auction.on("BidPlaced", async (phase, bidder, amount) => {
    try {
        await updateUI(phase, bidder, amount);
    } catch (error) {
        console.error("UI update failed:", error);
    }
});

// 2. Regular state polling
setInterval(async () => {
    try {
        const state = await auction.getAuctionState();
        updateDisplay(state);
    } catch (error) {
        console.error("State fetch failed:", error);
    }
}, 30000); // Every 30 seconds

// 3. Transaction monitoring
const tx = await auction.placeBid(amount);
console.log("Transaction sent:", tx.hash);
const receipt = await tx.wait();
console.log("Transaction confirmed:", receipt.blockNumber);

// 4. Graceful error handling
async function safeBid(amount) {
    try {
        // Check allowance
        const allowance = await usdc.allowance(user, auction.address);
        if (allowance.lt(amount)) {
            await usdc.approve(auction.address, amount);
        }
        
        // Place bid
        const tx = await auction.placeBid(amount);
        await tx.wait();
        return { success: true };
    } catch (error) {
        return { 
            success: false, 
            error: error.message 
        };
    }
}
```

---

## Summary

### Key Takeaways

1. **Auction Type**: Continuous Clearing Auction (CCA) - only winner pays
2. **Duration**: 96 hours (4 days) minimum across 3 bidding phases
3. **Progressive Reveal**: More property info revealed each phase
4. **Refund System**: Pull-based, safe, always available
5. **Phase Locking**: Each phase's winner recorded when advancing
6. **NFT Evolution**: Metadata changes with each phase
7. **Emergency Controls**: Admin can pause if needed
8. **User Safety**: Withdrawals never blocked, even when paused

### Best Practices

**For Bidders**:
- ✅ Verify contract addresses
- ✅ Use 6 decimals for USDC
- ✅ Approve USDC before bidding
- ✅ Monitor for outbids
- ✅ Withdraw refunds promptly

**For Admin**:
- ✅ Coordinate phase advancement (auction + NFT)
- ✅ Monitor for suspicious activity
- ✅ Use pause sparingly
- ✅ Withdraw proceeds after finalization

**For Developers**:
- ✅ Listen to events for real-time updates
- ✅ Poll state regularly
- ✅ Handle errors gracefully
- ✅ Test thoroughly on testnet

---

**For detailed API reference, see [CONTRACT-REFERENCE.md](./CONTRACT-REFERENCE.md)**  
**For quick deployment, see [README.md](./README.md)**