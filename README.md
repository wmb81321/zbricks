# ZBrick Auction System

A secure, factory-based multi-property auction system with USDC bidding. Deploy infrastructure once, create unlimited independent auctions for real estate tokenization. Built with Foundry and following best practices for smart contract security.

**Collection**: ZBRICKS (ZBR)  
**Architecture**: Factory-based multi-auction system

> 📖 **[Quick Deployment Guide →](DEPLOYMENT-GUIDE.md)** | **[API Reference →](CONTRACT-REFERENCE.md)** | **[Auction Flow →](AUCTION-FLOW.md)**

## 🎯 The 4 Essential Scripts

| # | Script | Purpose | When to Use |
|---|--------|---------|-------------|
| **1** | `./script/deploy-and-verify.sh` | Deploy infrastructure | Once per network |
| **2** | `forge script script/CreateAuction.s.sol` | Create auction | Per property |
| **3** | `./script/verify-contracts.sh` | Verify contracts | If auto-verify fails |
| **4** | `node script/extractDeployment.js` | Extract for frontend | After deployment |

**→ Full guide:** [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)

## Features

### 🏠 HouseNFT Contract (ZBRICKS)
- **ERC721 Standard**: Multi-token NFT collection for properties
- **Phase-Based Metadata**: Progressive reveal through 4 auction phases (0-3) per token
- **Factory Trust System**: Trusted factory can set controllers for atomic auction creation
- **Auto-Incrementing IDs**: Each property gets unique token ID (1, 2, 3...)
- **Independent Tokens**: Each token has own metadata URIs and phase progression

### 🔨 AuctionManager Contract
- **Independent Auctions**: Each property has isolated auction with own parameters
- **Configurable Phases**: Custom durations per auction (e.g., 7d/14d/30d)
- **Participation Fees**: Optional one-time fee per bidder (sent to treasury)
- **Treasury System**: Gnosis Safe integration for fee and proceeds collection
- **USDC Bidding**: Uses USDC token on Base/Base Sepolia/Arc networks
- **Pull-Based Refunds**: Secure withdrawal pattern for outbid participants
- **Checks-Effects-Interactions**: Prevents reentrancy attacks
- **Emergency Pause**: Admin can pause bidding while allowing withdrawals

### 🏭 AuctionFactory Contract
- **Deploy Once**: Shared infrastructure for all auctions
- **Immutable References**: NFT contract and payment token set at deployment
- **Atomic Creation**: Verifies ownership → deploys auction → sets controller → transfers NFT
- **Access Control**: Only factory owner can create auctions
- **Auction Registry**: Tracks all created auctions

## Architecture

### Security Features
✅ **Reentrancy Protection**: OpenZeppelin's `ReentrancyGuard` + CEI pattern  
✅ **Access Control**: Admin-only functions with transfer capability  
✅ **Pausable**: Emergency pause for bidding and phase advancement  
✅ **Pull Payments**: No push-based transfers, user-initiated withdrawals  
✅ **Input Validation**: Comprehensive require statements  
✅ **State Management**: Proper phase locking and progression  
✅ **Winner Validation**: Prevents finalization without valid winner  

### Phase System
- **Phase 0** (48 hours): Initial reveal and bidding
- **Phase 1** (24 hours): Second phase reveal and bidding
- **Phase 2** (24 hours): Third phase reveal and bidding  
- **Phase 3** (24 hours): Final reveal, no new bids accepted
- **Finalization**: After phase 3 duration, admin finalizes and transfers NFT

### Economics
- Only the final winner pays (their bid amount)
- All other bidders receive full refunds via `withdraw()`
- Admin withdraws proceeds once via `withdrawProceeds()` after finalization
- Refunds available even after auction finalization

## 🚀 Quick Start

> 📖 **[Complete Deployment Guide →](DEPLOYMENT-GUIDE.md)** - Step-by-step instructions for all 4 essential scripts

### Deploy Infrastructure (Step 1)

```bash
# 1. Setup
cp .env.example .env
# Add your PRIVATE_KEY to .env

# 2. Deploy to testnet
./script/deploy-and-verify.sh base-sepolia

# 3. Save addresses to .env
NFT_ADDRESS=<housenft_address>
FACTORY_ADDRESS=<factory_address>
```

### Create Auction (Step 2)

```bash
# 1. Configure in .env (see DEPLOYMENT-GUIDE.md for all options)
AUCTION_TREASURY=0xYourGnosisSafe
AUCTION_PHASE_0_URI=ipfs://Qm...
AUCTION_PHASE_1_URI=ipfs://Qm...
AUCTION_PHASE_2_URI=ipfs://Qm...
AUCTION_PHASE_3_URI=ipfs://Qm...

# 2. Create auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

### Extract for Frontend (Step 3)

```bash
node script/extractDeployment.js all
```

---

## 🚀 Deployment

### Two-Step Deployment Process

The new factory-based system uses a **two-step deployment**:

#### Step 1: Infrastructure (Once Per Network)

Deploy shared contracts (HouseNFT + AuctionFactory):

```bash
# 1. Setup environment
cp .env.example .env
# Add your PRIVATE_KEY to .env

# 2. Deploy infrastructure to network
./script/deploy-and-verify.sh base-sepolia
./script/deploy-and-verify.sh base

# 3. Save deployed addresses
export NFT_ADDRESS=<housenft_address>
export FACTORY_ADDRESS=<factory_address>
```

**What gets deployed:**
- ✅ HouseNFT ("ZBRICKS", "ZBR") - Multi-token NFT contract
- ✅ AuctionFactory - Auction creation factory
- ✅ Factory automatically set as trusted in NFT

**Result:** Infrastructure ready for creating unlimited auctions

#### Step 2: Per-Auction Creation (Per Property)

Create individual auction for each property:

```bash
# 1. Configure auction in .env file:
#    Required:
#      - AUCTION_TREASURY (Gnosis Safe)
#      - AUCTION_PHASE_*_URI (4 IPFS URIs - upload metadata first!)
#    Optional (has defaults):
#      - AUCTION_ADMIN (defaults to deployer)
#      - AUCTION_FLOOR_PRICE (default: $10M)
#      - AUCTION_PARTICIPATION_FEE (default: $1,000)
#      - Phase durations (defaults: 7d/14d/30d)

# 2. Create auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url base_sepolia \
  --broadcast

# 3. Repeat for each property!
```

**What happens:**
- ✅ Mints new NFT to factory (auto-incrementing token ID)
- ✅ Sets 4 phase URIs for metadata reveals
- ✅ Factory creates auction atomically
- ✅ NFT transferred to auction contract

**Result:** Independent auction ready for bidding

### Prerequisites

1. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env and add your PRIVATE_KEY
   ```

3. **Fund Your Wallet**
   
   | Network | You Need | Where to Get |
   |---------|----------|--------------|
   | **Base Sepolia** | Sepolia ETH | [Coinbase Faucet](https://coinbase.com/faucets/base-ethereum-goerli-faucet) |
   | **Base Mainnet** | ETH | Bridge from Ethereum mainnet |
   | **Arc Testnet** | Testnet currency + USDC | [Arc Testnet Faucet](https://testnet.arcscan.app) |

### Supported Networks

| Network | Chain ID | RPC | Explorer | USDC Address |
|---------|----------|-----|----------|--------------|
| **Base Sepolia** | 84532 | https://sepolia.base.org | [Blockscout](https://base-sepolia.blockscout.com) | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| **Base Mainnet** | 8453 | https://mainnet.base.org | [Blockscout](https://base.blockscout.com) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| **Arc Testnet** | 5042002 | https://rpc.testnet.arc.network | [ArcScan](https://testnet.arcscan.app) | `0x3600000000000000000000000000000000000000` |
| **Arc Mainnet** | 5042000 | TBA | TBA | TBA |

### Deployment Commands

**🎯 Recommended: One-Command Deploy (Use This!)**
```bash
# Base Sepolia (testnet)
./script/deploy-and-verify.sh base-sepolia

# Base Mainnet (production)
./script/deploy-and-verify.sh base

# Arc Testnet
./script/deploy-and-verify.sh arc-testnet

# Arc Mainnet
./script/deploy-and-verify.sh arc
```

> **What this does:** Runs `DeployFactory.s.sol` with automatic network detection, RPC configuration, and Blockscout verification. Deploys **infrastructure only** (HouseNFT + AuctionFactory).

**Advanced: Manual Deployment (Same Result)**

If you prefer calling Foundry directly instead of the bash wrapper:

```bash
# Base Sepolia example
forge script script/DeployFactory.s.sol:DeployFactory \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url https://base-sepolia.blockscout.com/api/ \
  -vvvv

# Save addresses to .env for Step 2
export NFT_ADDRESS=<deployed_nft_address>
export FACTORY_ADDRESS=<deployed_factory_address>
```

> **Note:** `deploy-and-verify.sh` internally calls `DeployFactory.s.sol` - they deploy the exact same contracts. The bash script just handles network config for you.

**Per-Auction Deployment (Step 2):**
```bash
# 1. Configure auction parameters in .env (see Configuration Options below)
# 2. Deploy auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url <RPC_URL> \
  --broadcast \
  -vvvv
```

### Configuration Options

**Infrastructure ([DeployFactory.s.sol](script/DeployFactory.s.sol)):**
- Collection name: "ZBRICKS"
- Collection symbol: "ZBR"
- NFT contract and payment token (set once)

**Per-Auction ([.env file](/.env.example)):**

All auction parameters are configured in your `.env` file. Copy `.env.example` to `.env` and update:

```bash
# Required Parameters
AUCTION_TREASURY=0x...              # Gnosis Safe or multisig address
AUCTION_PHASE_0_URI=ipfs://Qm...    # Phase 0 metadata (upload to IPFS first)
AUCTION_PHASE_1_URI=ipfs://Qm...    # Phase 1 metadata
AUCTION_PHASE_2_URI=ipfs://Qm...    # Phase 2 metadata
AUCTION_PHASE_3_URI=ipfs://Qm...    # Phase 3 metadata

# Optional Parameters (defaults shown)
AUCTION_ADMIN=0x...                           # Admin address (defaults to deployer if not set)
AUCTION_FLOOR_PRICE=10000000000000            # $10M USDC (10,000,000 * 10^6)
AUCTION_PARTICIPATION_FEE=1000000000          # $1,000 USDC (1,000 * 10^6)
AUCTION_MIN_BID_INCREMENT=5                   # 5% minimum bid increase
AUCTION_OPEN_DURATION=604800                  # 7 days in seconds
AUCTION_BIDDING_DURATION=1209600              # 14 days in seconds
AUCTION_EXECUTION_PERIOD=2592000              # 30 days in seconds
```

**USDC Amount Examples** (6 decimals):
- `$1,000` = `1000000000` (1,000 × 10⁶)
- `$100,000` = `100000000000` (100,000 × 10⁶)
- `$1M` = `1000000000000` (1,000,000 × 10⁶)
- `$10M` = `10000000000000` (10,000,000 × 10⁶)

**Time Examples:**
- `1 day` = `86400` seconds
- `7 days` = `604800` seconds
- `14 days` = `1209600` seconds
- `30 days` = `2592000` seconds

See [.env.example](.env.example) for the complete template with all options.

### After Deployment

**Extract contract addresses and ABIs:**
```bash
node script/extractDeployment.js all
```

This generates:
- `deployments/addresses.json` - All addresses by chain
- `deployments/abi/*.json` - Contract ABIs
- `deployments/README.md` - Integration guide

**Verify on explorer:**
- All contracts are automatically verified on Blockscout
- If verification fails, retry: `./script/verify-contracts.sh <network>`

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Insufficient funds for gas" | Fund your wallet with network's native currency |
| "USDC address not configured" | Deploy to a supported network |
| "Verification failed" | Wait 30s and run `./script/verify-contracts.sh <network>` |
| "Network not supported" | Use: `base-sepolia`, `base`, `arc-testnet`, or `arc` |

## 🌐 Deployed Contracts

The system is deployed on multiple networks. All contracts are verified on Blockscout.

### Networks

| Network | Chain ID | Status | Explorer |
|---------|----------|--------|----------|
| **Base Sepolia** | 84532 | ✅ Deployed | [Blockscout](https://base-sepolia.blockscout.com) |
| **Base Mainnet** | 8453 | ✅ Deployed | [Blockscout](https://base.blockscout.com) |
| **Arc Testnet** | 5042002 | ✅ Deployed | [ArcScan](https://testnet.arcscan.app) |
| **Arc Mainnet** | 5042000 | 🔜 Coming Soon | TBA |

### Contract Addresses

<details>
<summary><b>Base Sepolia (Testnet)</b></summary>

| Contract | Address |
|----------|---------|
| **HouseNFT** | [`0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6`](https://base-sepolia.blockscout.com/address/0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6) |
| **AuctionFactory** | [`0xd3390e5fec170d7577c850f5687a6542b66a4bbd`](https://base-sepolia.blockscout.com/address/0xd3390e5fec170d7577c850f5687a6542b66a4bbd) |
| **AuctionManager** | [`0x3347f6a853e04281daa0314f49a76964f010366f`](https://base-sepolia.blockscout.com/address/0x3347f6a853e04281daa0314f49a76964f010366f) |

</details>

<details>
<summary><b>Base Mainnet (Production)</b></summary>

| Contract | Address |
|----------|---------|
| **HouseNFT** | [`0x335845ef4f622145d963c9f39d6ff1b60757fee4`](https://base.blockscout.com/address/0x335845ef4f622145d963c9f39d6ff1b60757fee4) |
| **AuctionFactory** | [`0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7`](https://base.blockscout.com/address/0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7) |
| **AuctionManager** | [`0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca`](https://base.blockscout.com/address/0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca) |

</details>

<details>
<summary><b>Arc Testnet</b></summary>

| Contract | Address |
|----------|---------|
| **HouseNFT** | [`0x6bb77d0b235d4d27f75ae0e3a4f465bf8ac91c0b`](https://testnet.arcscan.app/address/0x6bb77d0b235d4d27f75ae0e3a4f465bf8ac91c0b) |
| **AuctionFactory** | [`0x88cc60b8a6161758b176563c78abeb7495d664d1`](https://testnet.arcscan.app/address/0x88cc60b8a6161758b176563c78abeb7495d664d1) |
| **AuctionManager** | [`0x2fbaed3a30a53bd61676d9c5f46db5a73f710f53`](https://testnet.arcscan.app/address/0x2fbaed3a30a53bd61676d9c5f46db5a73f710f53) |

</details>

### Integration Resources

```bash
# Extract latest deployment info and ABIs
node script/extractDeployment.js all
```

**Deployment artifacts available:**
- [`deployments/addresses.json`](deployments/addresses.json) - All contract addresses by chain
- [`deployments/abi/`](deployments/abi/) - Contract ABIs for integration
- [`deployments/README.md`](deployments/README.md) - Detailed deployment documentation

**Example usage:**
```javascript
const addresses = require('./deployments/addresses.json');
const auctionAbi = require('./deployments/abi/AuctionManager.json');

// Get contract for Base Sepolia
const chainId = '84532';
const auctionAddress = addresses[chainId].contracts.AuctionManager;
```

## Testing

### Run All Tests
```bash
forge test
```

### Run with Verbosity
```bash
forge test -vv  # Show test names and results
forge test -vvv # Show stack traces for failures
forge test -vvvv # Show stack traces and setup
```

### Run Specific Test
```bash
forge test --match-test testBidPlacement
forge test --match-contract AuctionManagerTest
```

### Gas Report
```bash
forge test --gas-report
```

### Coverage
```bash
forge coverage
```

## Contract Interaction

> 📚 **Detailed API**: See [CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md) for complete function documentation

### Quick Reference

**Bidders:**
```solidity
// 1. Approve USDC
USDC.approve(auctionManagerAddress, amount);

// 2. Place bid (phases 0-2 only)
auctionManager.placeBid(amount);

// 3. Withdraw refund if outbid
auctionManager.withdraw();
```

**Admin:**
```solidity
// Advance to next phase (after minimum duration)
auctionManager.advancePhase();

// Finalize auction (after phase 3)
auctionManager.finalizeAuction();

// Withdraw winning bid
auctionManager.withdrawProceeds();
```

**View Functions:**
```solidity
auctionManager.currentPhase();        // Current phase (0-3)
auctionManager.currentLeader();       // Current highest bidder
auctionManager.currentHighBid();      // Current highest bid amount
auctionManager.getTimeRemaining();    // Time left in phase
```

## Project Structure

```
zbrick/
├── src/
│   ├── HouseNFT.sol              # ERC721 ZBRICKS collection with factory trust
│   ├── AuctionFactory.sol        # Factory for creating multiple auctions
│   └── AuctionManager.sol        # Per-auction logic
├── test/
│   ├── HouseNFT.t.sol            # NFT contract tests (37 tests)
│   ├── AuctionManager.t.sol      # Auction tests (38 tests)
│   └── mocks/
│       └── MockUSDC.sol          # USDC mock for testing
├── script/
│   ├── DeployFactory.s.sol       # 🔑 Infrastructure deployment (use once)
│   ├── CreateAuction.s.sol       # 🔑 Per-auction deployment (use per property)
│   ├── deploy-and-verify.sh      # Wrapper for infrastructure with auto-verify
│   ├── verify-contracts.sh       # Manual verification helper
│   └── extractDeployment.js      # Extract ABIs and addresses
├── deployments/
│   ├── abi/                      # Contract ABIs (chain-agnostic)
│   │   ├── HouseNFT.json
│   │   ├── AuctionFactory.json
│   │   └── AuctionManager.json
│   └── addresses.json            # All chain deployments
├── lib/
│   ├── forge-std/                # Foundry standard library
│   └── openzeppelin-contracts/  # OpenZeppelin v5.5.0
├── .env.example                  # Environment template
├── foundry.toml                  # Foundry configuration
└── README.md                     # This file
```

## Security Considerations

### Auditing Checklist
- [x] Reentrancy protection (ReentrancyGuard + CEI pattern)
- [x] Integer overflow/underflow (Solidity ^0.8.13)
- [x] Access control (admin-only functions)
- [x] Pull payment pattern (no push-based transfers)
- [x] Input validation (comprehensive require statements)
- [x] Emergency pause mechanism
- [x] Phase progression validation
- [x] Winner validation before finalization
- [x] Single NFT transfer atomicity

### Known Design Choices
- **No frontrunning protection**: CCA design accepts frontrunning as part of auction dynamics
- **Admin trust required**: Admin controls phase advancement and finalization
- **Phase duration enforcement**: Minimum durations enforced, but admin must manually advance
- **Single admin key**: Admin transfer available, but recommend multisig for production

### Recommendations for Production
1. Use multisig wallet (e.g., Gnosis Safe) as admin
2. Upload metadata to IPFS/Arweave before deployment
3. Test phase durations on testnet first
4. Consider professional security audit
5. Set up monitoring for auction events
6. Document emergency procedures for pause/unpause

## Development

### Build
```bash
forge build
```

### Format Code
```bash
forge fmt
```

### Update Dependencies
```bash
forge update
```

### Local Development
```bash
# Start local node
anvil

# Deploy infrastructure to local node
forge script script/DeployFactory.s.sol:DeployFactory \
  --rpc-url http://localhost:8545 \
  --broadcast

# Create auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url http://localhost:8545 \
  --broadcast
```

## Events

```solidity
// HouseNFT
event PhaseAdvanced(uint8 indexed newPhase);
event PhaseURIUpdated(uint8 indexed phase, string uri);

// AuctionManager
event BidPlaced(uint8 indexed phase, address indexed bidder, uint256 amount);
event PhaseAdvanced(uint8 indexed phase, uint256 timestamp);
event AuctionFinalized(address indexed winner, uint256 amount);
event RefundWithdrawn(address indexed bidder, uint256 amount);
```

## Documentation Structure

- **[README.md](README.md)** (this file) - Project overview and features
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - 🔑 **Quick reference for the 4 essential deployment scripts**
- **[CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md)** - Complete API documentation for all contracts
- **[AUCTION-FLOW.md](AUCTION-FLOW.md)** - Multi-phase auction mechanics
- **[IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md)** - Factory system implementation details

## Essential Scripts

**Use these 4 scripts only:**

1. ✅ **`./script/deploy-and-verify.sh`** - Deploy infrastructure (HouseNFT + AuctionFactory)
2. ✅ **`forge script script/CreateAuction.s.sol`** - Create individual auctions (configured via `.env`)
3. ✅ **`./script/verify-contracts.sh`** - Re-verify on Blockscout if needed
4. ✅ **`node script/extractDeployment.js`** - Extract addresses/ABIs for frontend

See **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** for complete usage instructions.
- **[AUCTION-FLOW.md](AUCTION-FLOW.md)** - Multi-phase auction mechanics and deployment architecture
- **[CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md)** - Complete API documentation for all contracts
- **[IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md)** - Factory system implementation details

## Development

```bash
forge build          # Compile contracts
forge test           # Run tests
forge fmt            # Format code
```
# zbricks
