# House NFT Auction Flow

> Complete workflow guide for Admin and Users in the multi-phase auction system

---

## 🎯 Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AUCTION LIFECYCLE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   DEPLOYMENT        PHASE 0        PHASE 1        PHASE 2        FINALIZE  │
│   ─────────►       ─────────►     ─────────►     ─────────►     ─────────► │
│   [Admin]          [48 hours]     [24 hours]     [24 hours]     [Admin]    │
│                                                                             │
│   NFT Minted       Bidding ✓      Bidding ✓      Bidding ✓      NFT → Winner│
│   to Auction       Reveal P0      Reveal P1      Reveal P2      Proceeds   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 👨‍💼 Admin Flow

### 1. Pre-Deployment Setup

#### Step 1A: Prepare NFT Metadata Files

The project includes example metadata templates in `metadatarevelation/`:

```
metadatarevelation/
├── phase0.json    # Initial reveal: Location and lot details
├── phase1.json    # Interior layout: Bedrooms, bathrooms, living areas  
├── phase2.json    # Complete reveal: Amenities, legal docs
└── phase3.json    # Finalized: Sold status with winner info
```

**Metadata Structure (ERC721 Standard):**

```json
{
  "name": "Luxury Villa #1 - Location Revealed",
  "description": "Progressive auction: Phase 0 reveals location...",
  "image": "ipfs://QmPhase0/aerial-lot.jpg",
  "external_url": "https://yourauction.com/villa-1",
  "animation_url": "ipfs://QmPhase0/drone-footage.mp4",
  
  "attributes": [
    { "trait_type": "Reveal Phase", "value": 0, "display_type": "number" },
    { "trait_type": "Revealed", "value": "30%" },
    { "trait_type": "Status", "value": "Bidding Active" },
    { "trait_type": "Country", "value": "Colombia" },
    { "trait_type": "City", "value": "Cali" },
    { "trait_type": "Lot Size", "value": "1,000 m²", "display_type": "number" }
    // ... more attributes
  ],
  
  "media": {
    "lot_plan": "ipfs://QmPhase0/lot-plan.pdf",
    "drone_video": "ipfs://QmPhase0/drone.mp4"
  },
  
  "properties": {
    "auction": {
      "phase": 0,
      "bidding_open": true,
      "phase_ends": "2026-02-08T12:00:00Z"
    },
    "revealed": {
      "location": true,
      "interior_layout": false,
      "amenities": false
    }
  }
}
```

**Progressive Reveal Strategy:**

| Phase | Revealed Information | % Complete |
|-------|---------------------|-----------|
| **Phase 0** (48h) | Location, lot size, orientation, topography, views | 30% |
| **Phase 1** (24h) | + Interior layout, bedrooms, bathrooms, living areas | 60% |
| **Phase 2** (24h) | + All amenities, legal docs, property ID, taxes | 100% |
| **Phase 3** (Final) | Sold status, final price, winner (if desired) | 100% |

#### Step 1B: Upload Media Assets to IPFS

```bash
# Option 1: Using Pinata (https://pinata.cloud)
# 1. Create account and get API keys
# 2. Upload media folder for each phase

# Option 2: Using IPFS Desktop
# 1. Install IPFS Desktop
# 2. Add each phase folder:
#    - Phase 0: aerial photos, drone footage, lot plans
#    - Phase 1: + interior photos, floor plans, walkthroughs
#    - Phase 2: + all amenities photos, legal PDFs

# Option 3: Using CLI
ipfs add -r phase0_media/
# Note the hash: QmPhase0Hash...

ipfs add -r phase1_media/
# Note the hash: QmPhase1Hash...

ipfs add -r phase2_media/
# Note the hash: QmPhase2Hash...
```

#### Step 1C: Upload JSON Metadata to IPFS

```bash
# Upload each phase metadata file
ipfs add metadatarevelation/phase0.json
# Returns: QmPhase0MetadataHash...

ipfs add metadatarevelation/phase1.json
# Returns: QmPhase1MetadataHash...

ipfs add metadatarevelation/phase2.json
# Returns: QmPhase2MetadataHash...

ipfs add metadatarevelation/phase3.json
# Returns: QmPhase3MetadataHash...
```

**Your URI structure:**
```
Phase 0: ipfs://QmPhase0MetadataHash/
Phase 1: ipfs://QmPhase1MetadataHash/
Phase 2: ipfs://QmPhase2MetadataHash/
Phase 3: ipfs://QmPhase3MetadataHash/
```

#### Step 1D: Configure Deployment Script

Edit `script/DeployAuction.s.sol` with your IPFS URIs:

```solidity
function run() external returns (address, address) {
    // Update with your actual IPFS CIDs
    string[4] memory phaseURIs = [
        "ipfs://QmYourPhase0Hash/phase0.json",
        "ipfs://QmYourPhase1Hash/phase1.json", 
        "ipfs://QmYourPhase2Hash/phase2.json",
        "ipfs://QmYourPhase3Hash/phase3.json"
    ];
    
    // Configure phase durations (in seconds)
    uint256[4] memory phaseDurations = [
        48 hours,  // Phase 0
        24 hours,  // Phase 1
        24 hours,  // Phase 2
        24 hours   // Phase 3 (no bidding, just reveal)
    ];
    
    // ... rest of deployment
}
```

### 2. Deployment

```bash
# Configure environment
cp .env.example .env
# Add: PRIVATE_KEY, BASESCAN_API_KEY

# Deploy contracts
forge script script/DeployAuction.s.sol:DeployAuction \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

**Deployment creates:**
- `HouseNFT` → NFT automatically minted to AuctionManager
- `AuctionManager` → Starts in Phase 0 immediately

### 3. Phase Management Timeline

```
                    ADMIN ACTIONS TIMELINE
    ─────────────────────────────────────────────────────────────
    
    Deploy          Phase 0 ends      Phase 1 ends      Phase 2 ends
       │               │                  │                  │
       ▼               ▼                  ▼                  ▼
    ┌─────┐         ┌─────┐           ┌─────┐           ┌─────┐
    │Start│         │Adv. │           │Adv. │           │Final│
    │ P0  │  48h+   │to P1│   24h+    │to P2│   24h+    │ize  │
    └─────┘         └─────┘           └─────┘           └─────┘
       │               │                  │                  │
       │               │                  │                  │
       ▼               ▼                  ▼                  ▼
    Bidding         Bidding           Bidding           NFT Transfer
    Opens           Continues         Continues         to Winner
```

### 4. Admin Actions by Phase

#### Phase 0 → Phase 1 Transition

```solidity
// Wait for 48 hours minimum, then:
auctionManager.advancePhase();
houseNFT.advancePhase();        // Update NFT metadata
```

#### Phase 1 → Phase 2 Transition

```solidity
// Wait for 24 hours minimum, then:
auctionManager.advancePhase();
houseNFT.advancePhase();        // Update NFT metadata
```

#### Phase 2 → Finalization

```solidity
// Wait for 24 hours minimum, then:
auctionManager.finalizeAuction();  // Transfers NFT to winner
houseNFT.advancePhase();           // Final metadata reveal (Phase 3)
```

#### Withdraw Proceeds

```solidity
// After finalization:
auctionManager.withdrawProceeds(); // Receive winner's USDC payment
```

### 5. Admin Emergency Controls

```
┌────────────────────────────────────────────────────────────┐
│  EMERGENCY ACTIONS                                          │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  auctionManager.pause()     → Stops bidding & advances     │
│  auctionManager.unpause()   → Resumes auction              │
│                                                            │
│  ⚠️  Withdrawals ALWAYS work (even when paused)            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 👥 User (Bidder) Flow

### 1. Before Bidding

```
┌────────────────────────────────────────────────────────────┐
│  CHECK AUCTION STATUS                                       │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  currentPhase()      → Must be 0, 1, or 2 to bid           │
│  currentHighBid()    → Your bid must be HIGHER             │
│  currentLeader()     → Current winning address             │
│  getTimeRemaining()  → Time left in current phase          │
│  isAuctionActive()   → Must be true                        │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 2. Placing a Bid

```
┌────────────────────────────────────────────────────────────────────────┐
│                         BIDDING FLOW                                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐           │
│   │   APPROVE   │      │  PLACE BID  │      │   RESULT    │           │
│   │    USDC     │ ───► │             │ ───► │             │           │
│   └─────────────┘      └─────────────┘      └─────────────┘           │
│                                                                        │
│   USDC.approve(        placeBid(amount)     ✅ You're the leader      │
│     auctionManager,                         OR                         │
│     bidAmount          amount >             ❌ "Bid too low"           │
│   )                    currentHighBid                                  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

```solidity
// Step 1: Approve USDC spending
USDC.approve(auctionManagerAddress, bidAmount);

// Step 2: Place bid (must be > currentHighBid)
auctionManager.placeBid(bidAmount);
```

### 3. Getting Outbid

```
┌────────────────────────────────────────────────────────────────────────┐
│                       OUTBID SCENARIO                                   │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   You bid 1000 USDC                                                    │
│        │                                                               │
│        ▼                                                               │
│   Someone bids 1500 USDC                                               │
│        │                                                               │
│        ▼                                                               │
│   Your 1000 USDC → refundBalance[yourAddress]                          │
│        │                                                               │
│        ▼                                                               │
│   Call withdraw() to reclaim your USDC                                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

```solidity
// Check your refund balance
uint256 refund = auctionManager.getBidderRefund(yourAddress);

// Withdraw your refund
auctionManager.withdraw();
```

### 4. Bidding Rules

| Rule | Description |
|------|-------------|
| **Bid Amount** | Must be strictly greater than `currentHighBid` |
| **Phases** | Can only bid in phases 0, 1, and 2 |
| **Phase 3** | No bidding allowed (final reveal only) |
| **Paused** | Cannot bid when auction is paused |
| **Finalized** | Cannot bid after auction ends |

### 5. Winning the Auction

```
┌────────────────────────────────────────────────────────────────────────┐
│                        WINNER FLOW                                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   Phase 2 Ends                                                         │
│        │                                                               │
│        ▼                                                               │
│   Admin calls finalizeAuction()                                        │
│        │                                                               │
│        ├──────────────────────────────────────┐                        │
│        │                                      │                        │
│        ▼                                      ▼                        │
│   NFT transferred to                    Winning bid stays              │
│   your wallet automatically             in contract                    │
│                                              │                        │
│                                              ▼                        │
│                                         Admin withdraws                │
│                                         via withdrawProceeds()         │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

**As a winner, you:**
- ✅ Automatically receive the HouseNFT (Token ID: 1)
- ✅ Pay only your final bid amount
- ❌ Cannot withdraw your winning bid (it's the payment)

---

## 📊 Complete Auction State Diagram

```
                              ┌─────────────────┐
                              │    DEPLOYED     │
                              │   Phase 0 Auto  │
                              └────────┬────────┘
                                       │
        ┌──────────────────────────────┴──────────────────────────────┐
        │                        PHASE 0 (48h)                         │
        │  • Bidding OPEN                                              │
        │  • Metadata: Initial reveal                                  │
        │  • Users: placeBid(), withdraw()                             │
        └──────────────────────────────┬──────────────────────────────┘
                                       │ Admin: advancePhase()
        ┌──────────────────────────────┴──────────────────────────────┐
        │                        PHASE 1 (24h)                         │
        │  • Bidding OPEN                                              │
        │  • Metadata: More details revealed                           │
        │  • Users: placeBid(), withdraw()                             │
        └──────────────────────────────┬──────────────────────────────┘
                                       │ Admin: advancePhase()
        ┌──────────────────────────────┴──────────────────────────────┐
        │                        PHASE 2 (24h)                         │
        │  • Bidding OPEN (LAST CHANCE!)                               │
        │  • Metadata: Even more details                               │
        │  • Users: placeBid(), withdraw()                             │
        └──────────────────────────────┬──────────────────────────────┘
                                       │ Admin: finalizeAuction()
        ┌──────────────────────────────┴──────────────────────────────┐
        │                        FINALIZED                             │
        │  • Bidding CLOSED                                            │
        │  • NFT transferred to winner                                 │
        │  • Losers: withdraw() for refunds                            │
        │  • Admin: withdrawProceeds()                                 │
        └─────────────────────────────────────────────────────────────┘
```

---

## 🔗 Quick Reference

### Admin Functions

| Function | When to Use | Gas Cost |
|----------|-------------|----------|
| `advancePhase()` | After min duration of phase 0 or 1 | ~50k |
| `finalizeAuction()` | After phase 2 duration, has winner | ~100k |
| `withdrawProceeds()` | After finalization | ~50k |
| `pause()` | Emergency only | ~30k |
| `unpause()` | Resume from pause | ~30k |
| `transferAdmin()` | Key rotation | ~30k |

### User Functions

| Function | When to Use | Gas Cost |
|----------|-------------|----------|
| `placeBid(amount)` | Phases 0-2, amount > highBid | ~80k |
| `withdraw()` | When outbid or after losing | ~50k |

### View Functions (Free)

| Function | Returns |
|----------|---------|
| `currentPhase()` | Current phase (0-3) |
| `currentLeader()` | Highest bidder address |
| `currentHighBid()` | Highest bid in USDC |
| `getTimeRemaining()` | Seconds until phase can advance |
| `isAuctionActive()` | True if not finalized |
| `getBidderRefund(addr)` | Refund balance for address |
| `getAuctionState()` | Complete state summary |

---

## ⚠️ Important Notes

1. **Only the winner pays** - All other bidders get full refunds
2. **Pull-based refunds** - Users must call `withdraw()` to get refunds
3. **Withdrawals always work** - Even when paused or finalized
4. **Phase 3 = No bidding** - Final reveal phase, auction settled
5. **Admin trust** - Admin controls phase timing (consider multisig for production)

---

## 📖 Related Documentation

- [README.md](README.md) - Project overview and quick start
- [CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md) - Complete API documentation
