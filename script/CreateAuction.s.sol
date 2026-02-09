// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/HouseNFT.sol";
import "../src/AuctionFactory.sol";
import "../src/AuctionManager.sol";

/**
 * @title CreateAuction
 * @notice Script for creating individual auctions after infrastructure deployment
 * @dev This script reads all configuration from .env file
 * 
 * Prerequisites:
 * - Infrastructure must be deployed (HouseNFT and AuctionFactory)
 * - Configure .env with all required parameters (see .env.example)
 * 
 * Usage:
 * 1. Copy .env.example to .env
 * 2. Update all AUCTION_* parameters in .env
 * 3. Run: forge script script/CreateAuction.s.sol:CreateAuction --rpc-url <network> --broadcast
 */
contract CreateAuction is Script {
    // Contract instances
    HouseNFT public houseNFT;
    AuctionFactory public factory;
    
    function run() external {
        // Load deployer private key from .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("Creating New Auction");
        console.log("========================================");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("");
        
        // Load deployed contract addresses from .env
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        houseNFT = HouseNFT(nftAddress);
        factory = AuctionFactory(factoryAddress);
        
        console.log("Loaded Addresses:");
        console.log("  HouseNFT:", address(houseNFT));
        console.log("  Factory:", address(factory));
        console.log("");
        
        // ============================================
        // LOAD AUCTION CONFIGURATION FROM .ENV
        // ============================================
        
        // Auction parameters
        uint256 FLOOR_PRICE = vm.envUint("AUCTION_FLOOR_PRICE");  // In USDC (6 decimals)
        uint256 OPEN_DURATION = vm.envUint("AUCTION_OPEN_DURATION");  // Phase 0 in seconds
        uint256 BIDDING_DURATION = vm.envUint("AUCTION_BIDDING_DURATION");  // Phase 1 in seconds
        uint256 EXECUTION_PERIOD = vm.envUint("AUCTION_EXECUTION_PERIOD");  // Phase 2 in seconds
        uint256 MIN_BID_INCREMENT_PERCENT = vm.envUint("AUCTION_MIN_BID_INCREMENT");  // Percentage
        uint256 PARTICIPATION_FEE = vm.envUint("AUCTION_PARTICIPATION_FEE");  // In USDC (6 decimals)
        address TREASURY = vm.envAddress("AUCTION_TREASURY");
        
        // Admin address (optional - defaults to deployer if not set or is zero address)
        address ADMIN;
        try vm.envAddress("AUCTION_ADMIN") returns (address adminAddr) {
            ADMIN = adminAddr;
        } catch {
            ADMIN = address(0);
        }
        
        // Phase metadata URIs
        string memory PHASE_0_URI = vm.envString("AUCTION_PHASE_0_URI");
        string memory PHASE_1_URI = vm.envString("AUCTION_PHASE_1_URI");
        string memory PHASE_2_URI = vm.envString("AUCTION_PHASE_2_URI");
        string memory PHASE_3_URI = vm.envString("AUCTION_PHASE_3_URI");
        
        // Validate required parameters
        require(TREASURY != address(0), "Treasury address must be set in .env");
        require(bytes(PHASE_0_URI).length > 0, "Phase 0 URI must be set in .env");
        require(bytes(PHASE_1_URI).length > 0, "Phase 1 URI must be set in .env");
        require(bytes(PHASE_2_URI).length > 0, "Phase 2 URI must be set in .env");
        require(bytes(PHASE_3_URI).length > 0, "Phase 3 URI must be set in .env");
        
        // Determine admin address (use ADMIN if set, otherwise use deployer)
        address auctionAdmin = ADMIN != address(0) ? ADMIN : deployer;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ========================================
        // STEP 1: Mint NFT to Factory
        // ========================================
        console.log("Step 1: Minting NFT to Factory...");
        uint256 tokenId = houseNFT.mintTo(address(factory));
        console.log("  NFT minted to factory");
        console.log("  Token ID:", tokenId);
        console.log("  Owner:", houseNFT.ownerOf(tokenId));
        console.log("");
        
        // ========================================
        // STEP 2: Set Phase URIs
        // ========================================
        console.log("Step 2: Setting Phase URIs...");
        string[4] memory phaseURIs = [PHASE_0_URI, PHASE_1_URI, PHASE_2_URI, PHASE_3_URI];
        houseNFT.setPhaseURIs(tokenId, phaseURIs);
        console.log("  Phase 0:", PHASE_0_URI);
        console.log("  Phase 1:", PHASE_1_URI);
        console.log("  Phase 2:", PHASE_2_URI);
        console.log("  Phase 3:", PHASE_3_URI);
        console.log("");
        
        // ========================================
        // STEP 3: Create Auction via Factory
        // ========================================
        console.log("Step 3: Creating Auction...");
        console.log("  Admin:", auctionAdmin);
        console.log("  Floor Price: $", FLOOR_PRICE / 10**6);
        console.log("  Open Duration:", OPEN_DURATION / 1 days, "days");
        console.log("  Bidding Duration:", BIDDING_DURATION / 1 days, "days");
        console.log("  Execution Period:", EXECUTION_PERIOD / 1 days, "days");
        console.log("  Min Bid Increment:", MIN_BID_INCREMENT_PERCENT, "%");
        console.log("  Participation Fee: $", PARTICIPATION_FEE / 10**6);
        console.log("  Treasury:", TREASURY);
        console.log("");
        
        uint256[4] memory phaseDurations = [
            OPEN_DURATION,
            BIDDING_DURATION,
            EXECUTION_PERIOD,
            0  // Phase 3 has no duration (final state)
        ];
        
        address auctionAddress = factory.createAuction(
            auctionAdmin,
            tokenId,
            phaseDurations,
            FLOOR_PRICE,
            MIN_BID_INCREMENT_PERCENT,
            true,  // ENFORCE_MIN_INCREMENT - always true for security
            PARTICIPATION_FEE,
            TREASURY
        );
        
        console.log("  Auction created at:", auctionAddress);
        console.log("  Controller set:", houseNFT.tokenController(tokenId));
        console.log("  NFT transferred to auction:", houseNFT.ownerOf(tokenId));
        console.log("");
        
        vm.stopBroadcast();
        
        // ========================================
        // Deployment Summary
        // ========================================
        console.log("========================================");
        console.log("Auction Creation Complete!");
        console.log("========================================");
        console.log("New Auction Address:", auctionAddress);
        console.log("Token ID:", tokenId);
        console.log("Floor Price: $", FLOOR_PRICE / 10**6);
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify the auction contract on block explorer");
        console.log("2. Add auction address to deployments/addresses.json");
        console.log("3. Test the auction phases:");
        console.log("   - Phase 0 (Open): Users register with participation fee");
        console.log("   - Phase 1 (Bidding): Registered users place bids");
        console.log("   - Phase 2 (Execution): Winner executes and gets NFT");
        console.log("   - Phase 3 (Completed): NFT transferred to winner");
        console.log("========================================");
    }
}
