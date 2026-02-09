# ZBrick Deployment Guide

Quick reference for deploying and managing the ZBrick auction system.

## 📋 The 4 Essential Scripts

### 1️⃣ Deploy Infrastructure (Once Per Network)

**Script:** `deploy-and-verify.sh`  
**What it does:** Deploys HouseNFT + AuctionFactory with automatic verification  
**When to use:** First time on a new network

```bash
# Deploy to testnet
./script/deploy-and-verify.sh base-sepolia

# Deploy to mainnet
./script/deploy-and-verify.sh base

# Other networks
./script/deploy-and-verify.sh arc-testnet
```

**What you get:**
- ✅ HouseNFT contract deployed
- ✅ AuctionFactory contract deployed  
- ✅ Both verified on Blockscout
- ✅ Factory set as trusted in NFT

**Save the addresses:**
```bash
# Check deployment file after completion:
cat broadcast/DeployFactory.s.sol/<CHAIN_ID>/run-latest.json

# Add to .env for Step 2:
NFT_ADDRESS=0x...
FACTORY_ADDRESS=0x...
```

---

### 2️⃣ Create Auction (Per Property)

**Script:** `CreateAuction.s.sol`  
**What it does:** Mints NFT and creates auction for a property  
**When to use:** For each property you want to auction

**Setup `.env`:**
```bash
# Required
AUCTION_TREASURY=0xYourGnosisSafeAddress
AUCTION_PHASE_0_URI=ipfs://QmYourPhase0Hash
AUCTION_PHASE_1_URI=ipfs://QmYourPhase1Hash
AUCTION_PHASE_2_URI=ipfs://QmYourPhase2Hash
AUCTION_PHASE_3_URI=ipfs://QmYourPhase3Hash

# Optional (has defaults)
AUCTION_FLOOR_PRICE=10000000000000  # $10M
AUCTION_PARTICIPATION_FEE=1000000000  # $1,000
AUCTION_MIN_BID_INCREMENT=5  # 5%
AUCTION_OPEN_DURATION=604800  # 7 days
AUCTION_BIDDING_DURATION=1209600  # 14 days
AUCTION_EXECUTION_PERIOD=2592000  # 30 days
```

**Run:**
```bash
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  -vvvv
```

**What you get:**
- ✅ New NFT minted (auto-incrementing token ID)
- ✅ Phase metadata URIs set
- ✅ AuctionManager deployed for this property
- ✅ NFT transferred to auction contract

---

### 3️⃣ Verify Contracts (If Auto-Verification Failed)

**Script:** `verify-contracts.sh`  
**What it does:** Re-verifies contracts on Blockscout  
**When to use:** If deployment verification failed or timed out

```bash
# Verify infrastructure contracts
./script/verify-contracts.sh base-sepolia

# Verify on mainnet
./script/verify-contracts.sh base
```

**Supports:**
- ✅ Blockscout (Base, Base Sepolia)
- ✅ ArcScan (Arc Testnet, Arc Mainnet)
- ✅ Sourcify (automatically via Blockscout)

**Note:** This uses the deployment artifacts from `broadcast/` folder.

---

### 4️⃣ Extract Frontend Data

**Script:** `extractDeployment.js`  
**What it does:** Generates JSON files with addresses and ABIs for frontend  
**When to use:** After deploying to integrate with your dApp

```bash
# Extract all networks
node script/extractDeployment.js all

# Extract specific network
node script/extractDeployment.js 84532  # Base Sepolia
node script/extractDeployment.js 8453   # Base Mainnet
```

**Generates:**
- `deployments/addresses.json` - All contract addresses by chain
- `deployments/abi/HouseNFT.json` - NFT contract ABI
- `deployments/abi/AuctionFactory.json` - Factory contract ABI
- `deployments/abi/AuctionManager.json` - Auction contract ABI
- `deployments/README.md` - Integration guide

**Frontend usage:**
```javascript
const addresses = require('./deployments/addresses.json');
const auctionAbi = require('./deployments/abi/AuctionManager.json');

// Get contract for Base Sepolia
const chainId = '84532';
const auctionAddress = addresses[chainId].contracts.AuctionManager;
```

---

## 🔄 Typical Workflow

### First Deployment (Testnet)

```bash
# 1. Setup
cp .env.example .env
# Edit .env and add PRIVATE_KEY

# 2. Deploy infrastructure
./script/deploy-and-verify.sh base-sepolia

# 3. Save addresses to .env
NFT_ADDRESS=0x... (from output)
FACTORY_ADDRESS=0x... (from output)

# 4. Configure first auction in .env
# Set AUCTION_TREASURY, AUCTION_PHASE_*_URI, etc.

# 5. Create first auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url https://sepolia.base.org \
  --broadcast

# 6. Extract for frontend
node script/extractDeployment.js all
```

### Adding More Properties

```bash
# 1. Update .env with new property metadata
AUCTION_PHASE_0_URI=ipfs://QmNewProperty...
AUCTION_PHASE_1_URI=ipfs://QmNewProperty...
# ... etc

# 2. Create auction (reuses same infrastructure)
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url https://sepolia.base.org \
  --broadcast

# 3. Update frontend data
node script/extractDeployment.js all
```

### Production Deployment

```bash
# 1. Deploy infrastructure to mainnet
./script/deploy-and-verify.sh base

# 2. Update .env with mainnet addresses
NFT_ADDRESS=0x...
FACTORY_ADDRESS=0x...

# 3. Configure production auction
AUCTION_TREASURY=0xYourProductionGnosisSafe
# ... configure other parameters

# 4. Create auction
forge script script/CreateAuction.s.sol:CreateAuction \
  --rpc-url https://mainnet.base.org \
  --broadcast

# 5. Extract for production frontend
node script/extractDeployment.js 8453
```

---

## ⚙️ Configuration Reference

### USDC Amounts (6 decimals)
```bash
$1,000     = 1000000000      (1,000 × 10^6)
$100,000   = 100000000000    (100,000 × 10^6)
$1,000,000 = 1000000000000   (1,000,000 × 10^6)
$10,000,000 = 10000000000000 (10,000,000 × 10^6)
```

### Time Durations (seconds)
```bash
1 day   = 86400
7 days  = 604800
14 days = 1209600
30 days = 2592000
```

### Supported Networks
```bash
base-sepolia  # Base Sepolia Testnet (Chain ID: 84532)
base          # Base Mainnet (Chain ID: 8453)
arc-testnet   # Arc Testnet (Chain ID: 5042002)
arc           # Arc Mainnet (Chain ID: 5042000)
```

---

## 🛠️ Admin Operations (Manual)

After deployment, manage auctions via contract interactions:

```solidity
// Advance phase (call from admin address)
auctionManager.advancePhase();

// Finalize auction (after phase 3)
auctionManager.finalizeAuction();

// Withdraw proceeds (admin)
auctionManager.withdrawProceeds();

// Emergency pause (admin only)
auctionManager.pause();
auctionManager.unpause();
```

Use tools like:
- Etherscan/Blockscout Write Contract interface
- Foundry's `cast send` command
- Your frontend admin panel
- Gnosis Safe (recommended for production)

---

## 📚 Additional Resources

- **[README.md](README.md)** - Complete project overview
- **[CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md)** - Full API documentation
- **[AUCTION-FLOW.md](AUCTION-FLOW.md)** - Auction mechanics guide
- **[.env.example](.env.example)** - Configuration template

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "PRIVATE_KEY not set" | Add to `.env`: `PRIVATE_KEY=0x...` |
| "NFT_ADDRESS not set" | Run Step 1 first, then add addresses to `.env` |
| "Verification failed" | Run `./script/verify-contracts.sh <network>` |
| "Treasury address must be set" | Add to `.env`: `AUCTION_TREASURY=0x...` |
| "Phase URI must be set" | Add all 4 IPFS URIs to `.env` |
| "Insufficient funds" | Fund your wallet with ETH for gas |
| "export: not a valid identifier" | `.env` has invalid format - copy from `.env.example` |

**Tips:**
- ✅ Use `.env.example` as template - inline comments are supported
- ✅ No quotes needed around values: `PRIVATE_KEY=0xabc123`
- ✅ Comments must be on their own line or after a space and `#`
- ❌ Avoid special shell characters in values (`, $, !, etc.)

---

**Need help?** Check the main [README.md](README.md) for detailed documentation.
