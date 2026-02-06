// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AuctionManager.sol";
import "../src/HouseNFT.sol";
import "../test/mocks/MockUSDC.sol";

/**
 * @title DeployAuction
 * @notice Deployment script for the House NFT Auction system with verification support
 * @dev Supports Base Sepolia (testnet) and Base (mainnet) with automatic USDC address detection
 * 
 * Usage:
 * 1. Set environment variables in .env:
 *    - PRIVATE_KEY: Deployer private key
 *    - ADMIN_ADDRESS: (optional) Admin address, defaults to deployer
 *    - BASE_SEPOLIA_RPC_URL: Base Sepolia RPC endpoint
 *    - BASE_RPC_URL: Base Mainnet RPC endpoint
 *    - BASESCAN_API_KEY: Basescan API key for verification
 * 
 * 2. Deploy to Base Sepolia:
 *    forge script script/DeployAuction.s.sol:DeployAuction --rpc-url base_sepolia --broadcast --verify
 * 
 * 3. Deploy to Base Mainnet:
 *    forge script script/DeployAuction.s.sol:DeployAuction --rpc-url base --broadcast --verify
 * 
 * 4. Extract deployment info:
 *    node script/extractDeployment.js
 */
contract DeployAuction is Script {
    // Network-specific USDC addresses
    address constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // Chain IDs
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 constant BASE_CHAIN_ID = 8453;
    
    // Phase durations: 48h for phase 0, 24h for phases 1-3
    uint256[4] phaseDurations = [
        uint256(48 hours),  // Phase 0: Initial reveal
        uint256(24 hours),  // Phase 1
        uint256(24 hours),  // Phase 2
        uint256(24 hours)   // Phase 3: Final
    ];
    
    // Metadata URIs (replace with actual IPFS/Arweave URLs before deployment)
    string[4] phaseURIs = [
        "ipfs://QmPhase0/metadata.json",  // Phase 0 metadata
        "ipfs://QmPhase1/metadata.json",  // Phase 1 metadata
        "ipfs://QmPhase2/metadata.json",  // Phase 2 metadata
        "ipfs://QmPhase3/metadata.json"   // Phase 3 metadata (full reveal)
    ];
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Determine admin address (use env var or default to deployer)
        address admin;
        try vm.envAddress("ADMIN_ADDRESS") returns (address envAdmin) {
            admin = envAdmin;
        } catch {
            admin = deployer;
        }
        
        console.log("==== Deployment Configuration ====");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("");
        
        // Determine USDC address based on network
        address usdcAddress = getUSDCAddress();
        console.log("USDC Address:", usdcAddress);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("==== Deployed Contracts ====");
        
        // Deploy HouseNFT first with deployer as temporary owner
        HouseNFT houseNFT = new HouseNFT(
            "Luxury House NFT",
            "HOUSE",
            phaseURIs,
            deployer
        );
        
        console.log("HouseNFT:", address(houseNFT));
        
        // Deploy AuctionManager with HouseNFT address
        AuctionManager auctionManager = new AuctionManager(
            usdcAddress,
            address(houseNFT),
            admin,
            phaseDurations
        );
        
        console.log("AuctionManager:", address(auctionManager));
        console.log("");
        
        // Transfer NFT to auction manager
        houseNFT.transferFrom(deployer, address(auctionManager), 1);
        
        // Set controller on NFT contract
        houseNFT.setController(address(auctionManager));
        
        vm.stopBroadcast();
        
        // Output configuration details
        console.log("==== Configuration ====");
        console.log("Phase 0 Duration:", phaseDurations[0] / 1 hours, "hours");
        console.log("Phase 1 Duration:", phaseDurations[1] / 1 hours, "hours");
        console.log("Phase 2 Duration:", phaseDurations[2] / 1 hours, "hours");
        console.log("Phase 3 Duration:", phaseDurations[3] / 1 hours, "hours");
        console.log("");
        
        console.log("==== Metadata URIs ====");
        for (uint8 i = 0; i < 4; i++) {
            console.log("Phase", i, "URI:", phaseURIs[i]);
        }
        console.log("");
        
        console.log("==== Deployment Complete ====");
        console.log("NFT Owner (AuctionManager):", houseNFT.ownerOf(1));
        console.log("NFT Controller:", houseNFT.controller());
        console.log("Auction Admin:", auctionManager.admin());
        console.log("Current Phase:", houseNFT.currentPhase());
        console.log("");
        
        console.log("==== Next Steps ====");
        console.log("1. Contracts will be auto-verified if --verify flag was used");
        console.log("2. Run: node script/extractDeployment.js to get addresses and ABIs");
        console.log("3. Update metadata URIs if needed via updatePhaseURI()");
        console.log("4. Monitor auction start time");
        console.log("5. Advance phases using advancePhase() after minimum duration");
        console.log("");
        
        // Save deployment info to broadcast folder (automatically saved by forge)
        console.log("Deployment info saved to: broadcast/DeployAuction.s.sol/<chainid>/run-latest.json");
    }
    
    /**
     * @notice Determines the USDC address based on the current network
     * @return The USDC token address for the current network
     */
    function getUSDCAddress() internal returns (address) {
        uint256 chainId = block.chainid;
        
        if (chainId == BASE_SEPOLIA_CHAIN_ID) {
            console.log("Detected network: Base Sepolia (Testnet)");
            return BASE_SEPOLIA_USDC;
        } else if (chainId == BASE_CHAIN_ID) {
            console.log("Detected network: Base (Mainnet)");
            return BASE_USDC;
        } else {
            console.log("Unknown network, deploying MockUSDC for testing");
            MockUSDC mockUSDC = new MockUSDC();
            console.log("MockUSDC deployed at:", address(mockUSDC));
            return address(mockUSDC);
        }
    }
}
