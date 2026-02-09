// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/HouseNFT.sol";
import "../src/AuctionFactory.sol";
import "../src/AuctionManager.sol";

/**
 * @title DeployFactory
 * @notice Complete deployment script for AuctionFactory and sample auction creation
 * @dev Demonstrates the complete workflow:
 *      1. Deploy HouseNFT collection
 *      2. Deploy AuctionFactory
 *      3. Mint NFT
 *      4. Set phase URIs for the NFT
 *      5. Deploy AuctionManager with NFT transferred
 *      6. Set auction as controller
 */
contract DeployFactory is Script {
    
    // Network-specific USDC addresses
    address constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;
    // Arc Mainnet USDC - Update when mainnet launches
    address constant ARC_MAINNET_USDC = 0x0000000000000000000000000000000000000000;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("===========================================");
        console.log("Deploying Auction System");
        console.log("===========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Determine USDC address based on chain
        address usdcAddress;
        string memory networkName;
        
        if (block.chainid == 8453) {
            // Base Mainnet
            usdcAddress = BASE_MAINNET_USDC;
            networkName = "Base Mainnet";
        } else if (block.chainid == 84532) {
            // Base Sepolia
            usdcAddress = BASE_SEPOLIA_USDC;
            networkName = "Base Sepolia Testnet";
        } else if (block.chainid == 5042002) {
            // Arc Testnet
            usdcAddress = ARC_TESTNET_USDC;
            networkName = "Arc Testnet";
        } else if (block.chainid == 5042000) {
            // Arc Mainnet (placeholder - update when mainnet launches)
            usdcAddress = ARC_MAINNET_USDC;
            networkName = "Arc Mainnet";
            require(usdcAddress != address(0), "Arc Mainnet USDC address not configured");
        } else {
            console.log("ERROR: Unsupported network");
            console.log("Supported networks:");
            console.log("  - Base Mainnet (8453)");
            console.log("  - Base Sepolia (84532)");
            console.log("  - Arc Testnet (5042002)");
            console.log("  - Arc Mainnet (5042000) - Coming soon");
            revert("Unsupported network");
        }
        
        console.log("Network:", networkName);
        console.log("Using USDC:", usdcAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ===== Step 1: Deploy HouseNFT =====
        console.log("\n=== Step 1: Deploying HouseNFT ===");
        HouseNFT houseNFT = new HouseNFT("ZBRICKS", "ZBR");
        console.log("HouseNFT deployed at:", address(houseNFT));
        
        // ===== Step 2: Deploy AuctionFactory =====
        console.log("\n=== Step 2: Deploying AuctionFactory ===");
        AuctionFactory factory = new AuctionFactory(
            deployer,
            address(houseNFT),
            usdcAddress
        );
        console.log("AuctionFactory deployed at:", address(factory));
        
        // ===== Step 3: Set Factory as Trusted =====
        console.log("\n=== Step 3: Setting Factory as Trusted ===");
        houseNFT.setFactory(address(factory));
        console.log("Factory set as trusted in HouseNFT");
        
        vm.stopBroadcast();
        
        // ===== Deployment Summary =====
        console.log("\n===========================================");
        console.log("Infrastructure Deployment Complete!");
        console.log("===========================================");
        console.log("Network:", networkName);
        console.log("HouseNFT:", address(houseNFT));
        console.log("AuctionFactory:", address(factory));
        console.log("Payment Token (USDC):", usdcAddress);
        console.log("Admin:", deployer);
        console.log("Trusted Factory:", address(factory));
        console.log("===========================================");
        
        // ===== Next Steps =====
        console.log("\n=== Next Steps ===");
        console.log("1. To create an auction, use CreateAuction.s.sol script:");
        console.log("   forge script script/CreateAuction.s.sol --rpc-url <network> --broadcast");
        console.log("2. Set NFT_ADDRESS and FACTORY_ADDRESS in .env");
        console.log("3. Update auction parameters in CreateAuction.s.sol");
        console.log("4. Admin can transfer role to multisig if needed:");
        console.log("   houseNFT.transferAdmin(newAdmin)");
        console.log("===========================================\n");
    }
    
}
