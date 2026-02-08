# House NFT Auction System

A secure, multi-phase continuous clearing auction (CCA) system for a single house NFT with USDC bidding on Base blockchain. Built with Foundry and following best practices for smart contract security.

> 📖 **[View Complete API Reference →](CONTRACT-REFERENCE.md)**

## Features

### 🏠 HouseNFT Contract
- **ERC721 Standard**: Single-token NFT representing a house
- **Phase-Based Metadata**: Progressive reveal through 4 auction phases (0-3)
- **Controller Pattern**: Auction manager controls phase advancement
- **Immutable Token**: Single tokenId (1) minted once to auction contract

### 🔨 AuctionManager Contract
- **Multi-Phase Auction**: 4 configurable phases (48h/24h/24h/24h default)
- **USDC Bidding**: Uses USDC token on Base/Base Sepolia
- **Pull-Based Refunds**: Secure withdrawal pattern for outbid participants
- **Checks-Effects-Interactions**: Prevents reentrancy attacks
- **Emergency Pause**: Admin can pause bidding while allowing withdrawals
- **Admin Transfer**: Key rotation capability for admin role

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

## 🚀 Deployment

### Quick Deploy

```bash
# 1. Setup environment
cp .env.example .env
# Add your PRIVATE_KEY to .env

# 2. Deploy to testnet
./script/deploy-and-verify.sh base-sepolia

# 3. Done! Contracts deployed and verified
```

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

**One-Command Deploy (Recommended):**
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

**Manual Deployment:**
```bash
# Deploy
forge script script/DeployFactory.s.sol \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvvv

# Verify
./script/verify-contracts.sh <network>
```

### Configuration Options

Default parameters in [DeployFactory.s.sol](script/DeployFactory.s.sol):

```solidity
Floor Price: $100,000 USDC
Min Bid Increment: 5%
Phase 0 Duration: 48 hours
Phase 1 Duration: 24 hours
Phase 2 Duration: 24 hours
```

To customize, edit the deployment script before running.

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
| **HouseNFT** | [`0x335845ef4f622145d963c9f39d6ff1b60757fee4`](https://testnet.arcscan.app/address/0x335845ef4f622145d963c9f39d6ff1b60757fee4) |
| **AuctionFactory** | [`0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7`](https://testnet.arcscan.app/address/0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7) |
| **AuctionManager** | [`0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca`](https://testnet.arcscan.app/address/0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca) |

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
│   ├── HouseNFT.sol           # ERC721 with phase-based metadata
│   └── AuctionManager.sol     # Main auction logic
├── test/
│   ├── HouseNFT.t.sol         # NFT contract tests (31 tests)
│   ├── AuctionManager.t.sol   # Auction tests (32 tests)
│   └── mocks/
│       └── MockUSDC.sol       # USDC mock for testing
├── script/
│   ├── DeployAuction.s.sol    # Deployment script
│   └── extractDeployment.js   # Extract ABIs and addresses
├── deployments/
│   ├── abi/                   # Contract ABIs (chain-agnostic)
│   │   ├── HouseNFT.json
│   │   └── AuctionManager.json
│   └── addresses.json         # All chain deployments
├── lib/
│   ├── forge-std/             # Foundry standard library
│   └── openzeppelin-contracts/ # OpenZeppelin v5.5.0
├── .env.example               # Environment template
├── foundry.toml               # Foundry configuration
└── README.md                  # This file
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

# Deploy to local node
forge script script/DeployAuction.s.sol:DeployAuction \
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

- **[README.md](README.md)** (this file) - Overview, quick start, deployment
- **[AUCTION-FLOW.md](AUCTION-FLOW.md)** - Visual guide for admin and user workflows
- **[CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md)** - Complete API documentation

## Development

```bash
forge build          # Compile contracts
forge test           # Run tests
forge fmt            # Format code
```
# zbricks
