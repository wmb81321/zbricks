# Factory-Based Multi-Auction System - Implementation Summary

## Overview
Successfully refactored the auction system from single deployment to factory-based multi-auction infrastructure. This enables deploying infrastructure once and creating multiple independent auctions for different properties.

## Key Changes

### 1. Collection Name Update
- **Name**: Changed from "Luxury House NFT" to **"ZBRICKS"**
- **Symbol**: Changed from "HOUSE" to **"ZBR"**
- **Location**: [src/HouseNFT.sol](src/HouseNFT.sol), [script/DeployFactory.s.sol](script/DeployFactory.s.sol)

### 2. HouseNFT.sol - Factory Trust System
Added factory trust mechanism to allow factory to set NFT controllers:

**New State Variables:**
```solidity
address public trustedFactory;  // Factory allowed to call setController()
```

**New Functions:**
- `setFactory(address _factory)` - One-time setup by admin to trust factory
  - Can only be called when `trustedFactory == address(0)`
  - Cannot be set to zero address
  - Emits `FactorySet` event

**Modified Functions:**
- `setController(uint256 tokenId, address _controller)` 
  - Now allows both admin AND trusted factory to call
  - Error message: "Only admin or factory"

**Security Features:**
- Factory can only be set once (immutable after first set)
- Admin retains full control over metadata
- Factory can only set controllers, not modify other NFT properties

### 3. AuctionFactory.sol - Immutable Infrastructure
Refactored factory to use immutable references and atomic operations:

**New Immutable State:**
```solidity
HouseNFT public immutable nftContract;
IERC20 public immutable paymentToken;
```

**Updated Constructor:**
```solidity
constructor(address initialOwner, address _nftContract, address _paymentToken)
```
- Validates both addresses are non-zero
- Sets immutable references to shared infrastructure

**Simplified createAuction():**
- Removed redundant `_nftContract` and `_paymentToken` parameters
- Uses immutable references instead
- Atomic operation sequence:
  1. Verify factory owns NFT: `require(nftContract.ownerOf(_tokenId) == address(this))`
  2. Deploy new AuctionManager
  3. Set controller: `nftContract.setController(_tokenId, auctionAddress)`
  4. Transfer NFT: `nftContract.transferFrom(address(this), auctionAddress, _tokenId)`
- Emits `AuctionCreated` event

### 4. DeployFactory.s.sol - Infrastructure Only
Simplified deployment script to deploy infrastructure only:

**Removed:**
- All auction creation logic (~150 lines)
- NFT minting to factory
- Phase URI setting
- Auction deployment
- Controller setup
- Unused `computeCreateAddress()` helper function

**Added:**
- Call to `houseNFT.setFactory(address(factory))` after factory deployment
- Clear next steps pointing to CreateAuction.s.sol

**New Deployment Flow:**
1. Deploy HouseNFT (ZBRICKS/ZBR)
2. Deploy AuctionFactory with NFT and USDC addresses
3. Set factory as trusted in HouseNFT
4. Output instructions for creating auctions

### 5. CreateAuction.s.sol - Per-Auction Script (NEW)
Created new script for creating individual auctions:

**Configuration Section:**
```solidity
uint256 public constant FLOOR_PRICE = 10_000_000 * 10**6;  // $10M
uint256 public constant OPEN_DURATION = 7 days;
uint256 public constant BIDDING_DURATION = 14 days;
uint256 public constant EXECUTION_PERIOD = 30 days;
uint256 public constant MIN_BID_INCREMENT_PERCENT = 5;
bool public constant ENFORCE_MIN_INCREMENT = true;
uint256 public constant PARTICIPATION_FEE = 1000 * 10**6;   // $1000
address public constant TREASURY = 0x...;  // UPDATE
address public constant ADMIN = 0x...;     // UPDATE (or use deployer)

string public constant PHASE_0_URI = "ipfs://...";  // UPDATE
string public constant PHASE_1_URI = "ipfs://...";  // UPDATE
string public constant PHASE_2_URI = "ipfs://...";  // UPDATE
string public constant PHASE_3_URI = "ipfs://...";  // UPDATE
```

**Execution Flow:**
1. Load deployed contract addresses from environment variables
2. Mint NFT to factory using `mintTo(address(factory))`
3. Set all 4 phase URIs using `setPhaseURIs(tokenId, [uri0, uri1, uri2, uri3])`
4. Create auction via factory with all parameters
5. Output auction address and verification steps

**Environment Variables Required:**
- `PRIVATE_KEY` - Admin private key
- `NFT_ADDRESS` - Deployed HouseNFT address
- `FACTORY_ADDRESS` - Deployed AuctionFactory address

**Usage:**
```bash
forge script script/CreateAuction.s.sol:CreateAuction --rpc-url <network> --broadcast
```

### 6. Test Updates
Updated and expanded test suite:

**test/HouseNFT.t.sol:**
- Fixed `testNonAdminCannotSetController()` - Updated error message to "Only admin or factory"
- Fixed `testCannotSetFactoryToZero()` - Updated error message to "Invalid factory address"

**New Tests Added:**
- `testSetFactory()` - Admin can set factory once
- `testCannotSetFactoryTwice()` - Factory cannot be changed after initial setup
- `testCannotSetFactoryToZero()` - Factory cannot be zero address
- `testOnlyAdminCanSetFactory()` - Only admin can set factory
- `testFactoryCanSetController()` - Factory can set controller after being trusted
- `testFactoryCannotSetControllerBeforeSetup()` - Factory cannot set controller before being set

**Test Results:**
- ✅ 75 total tests (37 HouseNFT + 38 AuctionManager)
- ✅ All tests passing
- ✅ 6 new factory trust system tests
- ✅ All existing tests still pass

## Security Architecture

### Trust Model
1. **Admin** (from .env)
   - Controls NFT metadata (phase URIs)
   - Can set factory (one time)
   - Can transfer admin role
   - Manages per-auction admin assignments

2. **Trusted Factory** (set by admin)
   - Can set controllers on NFTs
   - Immutable after first set
   - Must own NFT to create auction
   - Atomic operations prevent partial states

3. **Per-Auction Admin**
   - Specified when creating auction
   - Controls auction phases
   - Manages pause/unpause
   - Can be different from NFT admin

### Immutable Values
- Factory's NFT contract reference
- Factory's payment token reference
- Trusted factory address (after first set)
- Per-auction critical parameters (floor price, durations, etc.)

### Atomic Operations
Factory.createAuction() performs atomic sequence:
1. Verify ownership ✓
2. Deploy auction ✓
3. Set controller ✓
4. Transfer NFT ✓

No partial states possible - either all succeed or all revert.

### Pull Payment Pattern
- Participation fees go to treasury immediately
- Auction proceeds withdrawn by treasury (pull pattern)
- Refunds withdrawn by bidders (pull pattern)
- No push payments to prevent reentrancy

## Deployment Workflow

### One-Time Infrastructure Setup
```bash
# 1. Set environment variables
export PRIVATE_KEY=0x...
export USDC_ADDRESS=0x...

# 2. Deploy infrastructure
forge script script/DeployFactory.s.sol:DeployFactory --rpc-url <network> --broadcast --verify

# 3. Save deployed addresses to .env
export NFT_ADDRESS=0x...
export FACTORY_ADDRESS=0x...
```

### Per-Property Auction Creation
```bash
# 1. Update CreateAuction.s.sol configuration:
#    - FLOOR_PRICE, durations, fee, etc.
#    - TREASURY address (Gnosis Safe)
#    - ADMIN address (or use deployer)
#    - All 4 phase URIs (IPFS links)

# 2. Run creation script
forge script script/CreateAuction.s.sol:CreateAuction --rpc-url <network> --broadcast

# 3. Verify auction contract
forge verify-contract <auction-address> src/AuctionManager.sol:AuctionManager --watch

# 4. Add auction address to deployments/addresses.json
```

## Files Modified

### Core Contracts
- ✅ [src/HouseNFT.sol](src/HouseNFT.sol) - Added factory trust system
- ✅ [src/AuctionFactory.sol](src/AuctionFactory.sol) - Immutable infrastructure, atomic operations

### Scripts
- ✅ [script/DeployFactory.s.sol](script/DeployFactory.s.sol) - Infrastructure only, collection renamed
- ✅ [script/CreateAuction.s.sol](script/CreateAuction.s.sol) - **NEW** per-auction deployment

### Tests
- ✅ [test/HouseNFT.t.sol](test/HouseNFT.t.sol) - Updated error messages, added 6 factory tests
- ✅ [test/AuctionManager.t.sol](test/AuctionManager.t.sol) - All 38 tests still passing

## Next Steps

### Immediate
1. ✅ Update collection name to ZBRICKS/ZBR
2. ✅ Implement factory trust system
3. ✅ Create separate auction creation script
4. ✅ Update tests
5. ✅ Verify all tests pass

### Before Production Deployment
1. Update phase URI configuration in CreateAuction.s.sol with actual IPFS hashes
2. Set TREASURY to actual Gnosis Safe address
3. Deploy infrastructure on target network (Base Mainnet/Testnet)
4. Transfer admin to multisig if desired
5. Create first auction with real property data

### Post-Deployment
1. Verify all contracts on block explorer
2. Test auction flow end-to-end on testnet
3. Document auction addresses in deployments/addresses.json
4. Set up monitoring for auction phases
5. Prepare frontend integration

## Security Considerations

### Deployed
✅ Factory can only be set once
✅ Immutable critical values prevent tampering
✅ Atomic operations prevent partial states
✅ Pull payment pattern prevents reentrancy
✅ Comprehensive test coverage (75 tests)
✅ Role separation (admin vs factory vs auction admin)

### Future Enhancements
- Consider adding factory pause mechanism
- Add factory upgrade path if needed
- Implement auction registry for easier discovery
- Add emergency pause for all auctions
- Consider adding auction template versions

## Compilation Status
✅ All contracts compile successfully (Solc 0.8.30)
✅ 75 tests passing (0 failed)
✅ No critical warnings
✅ Ready for deployment

---

**Implementation Date**: January 2025
**Solidity Version**: ^0.8.13
**Framework**: Foundry
**Networks**: Base Mainnet/Sepolia, Arc Mainnet/Testnet
