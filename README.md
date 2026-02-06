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

## Deployment

> 📝 **Quick Setup**: Configure `.env` with `PRIVATE_KEY` and deploy to Base Sepolia for testing

### Networks Supported
- **Base Mainnet** (Chain ID: 8453)
  - USDC: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **Base Sepolia** (Chain ID: 84532)
  - USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **Local/Other**: Deploys MockUSDC for testing

### Quick Deploy

```bash
# 1. Setup environment
cp .env.example .env
# Edit .env with your PRIVATE_KEY and BASESCAN_API_KEY

# 2. Deploy to Base Sepolia (testnet)
forge script script/DeployAuction.s.sol:DeployAuction \
  --rpc-url base_sepolia \
  --broadcast \
  --verify

# 3. Extract deployment info
node script/extractDeployment.js 84532
```

**Before deploying**, update metadata URIs in [script/DeployAuction.s.sol](script/DeployAuction.s.sol):
```solidity
string[4] phaseURIs = [
    "ipfs://YOUR_PHASE_0_CID/metadata.json",
    "ipfs://YOUR_PHASE_1_CID/metadata.json",
    "ipfs://YOUR_PHASE_2_CID/metadata.json",
    "ipfs://YOUR_PHASE_3_CID/metadata.json"
];
```

### Deployment Output
The extraction script generates:
```
deployments/
├── abi/
│   ├── HouseNFT.json          # Contract ABI
│   └── AuctionManager.json    # Contract ABI
└── addresses.json              # All chain addresses
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
- **[CONTRACT-REFERENCE.md](CONTRACT-REFERENCE.md)** - Complete API documentation

## Development

```bash
forge build          # Compile contracts
forge test           # Run tests
forge fmt            # Format code
```
# zbricks
