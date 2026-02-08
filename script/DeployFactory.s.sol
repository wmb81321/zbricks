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
        HouseNFT houseNFT = new HouseNFT("Luxury House NFT", "HOUSE");
        console.log("HouseNFT deployed at:", address(houseNFT));
        
        // ===== Step 2: Deploy AuctionFactory =====
        console.log("\n=== Step 2: Deploying AuctionFactory ===");
        AuctionFactory factory = new AuctionFactory(deployer);
        console.log("AuctionFactory deployed at:", address(factory));
        
        // ===== Step 3: Mint NFT =====
        console.log("\n=== Step 3: Minting NFT ===");
        uint256 tokenId = houseNFT.mintTo(deployer);
        console.log("Minted token ID:", tokenId);
        
        // ===== Step 4: Set Phase URIs =====
        console.log("\n=== Step 4: Setting Phase URIs ===");
        string[4] memory phaseURIs = [
            "ipfs://QmPhase0URI/metadata.json", // Phase 0: 30% reveal
            "ipfs://QmPhase1URI/metadata.json", // Phase 1: 60% reveal
            "ipfs://QmPhase2URI/metadata.json", // Phase 2: 100% reveal
            "ipfs://QmPhase3URI/metadata.json"  // Phase 3: Final with winner
        ];
        houseNFT.setPhaseURIs(tokenId, phaseURIs);
        console.log("Phase URIs set for token", tokenId);
        
        // ===== Step 5: Deploy AuctionManager with NFT Transfer =====
        console.log("\n=== Step 5: Deploying AuctionManager ===");
        
        // Auction parameters
        address auctionAdmin = deployer; // Can be different address
        uint256[4] memory phaseDurations = [
            uint256(48 hours), // Phase 0: 48 hours
            uint256(24 hours), // Phase 1: 24 hours
            uint256(24 hours), // Phase 2: 24 hours
            uint256(0)         // Phase 3: N/A (not used in AuctionManager)
        ];
        uint256 floorPrice = 100_000 * 1e6; // $100,000 USDC (6 decimals)
        uint256 minBidIncrementPercent = 5; // 5% minimum increment
        bool enforceMinIncrement = true;    // Enforce the increment
        
        console.log("Auction Parameters:");
        console.log("  Admin:", auctionAdmin);
        console.log("  Floor Price: $100,000 USDC");
        console.log("  Min Bid Increment: 5%");
        console.log("  Enforce Increment:", enforceMinIncrement);
        console.log("  Phase 0 Duration:", phaseDurations[0], "seconds");
        console.log("  Phase 1 Duration:", phaseDurations[1], "seconds");
        console.log("  Phase 2 Duration:", phaseDurations[2], "seconds");
        
        // Calculate next contract address (for AuctionManager)
        // Current nonce + 1 because we'll do transferFrom before deploying
        uint256 nonce = vm.getNonce(deployer) + 1;
        address predictedAuction = computeCreateAddress(deployer, nonce);
        
        console.log("\nTransferring NFT to predicted auction address:", predictedAuction);
        
        // Transfer NFT to predicted auction address BEFORE deployment
        houseNFT.transferFrom(deployer, predictedAuction, tokenId);
        console.log("NFT transferred successfully");
        
        // Now deploy auction (which will verify it owns the NFT)
        console.log("Deploying AuctionManager...");
        AuctionManager auction = new AuctionManager(
            auctionAdmin,
            usdcAddress,
            address(houseNFT),
            tokenId,
            phaseDurations,
            floorPrice,
            minBidIncrementPercent,
            enforceMinIncrement
        );
        
        // Verify address matches prediction
        require(address(auction) == predictedAuction, "Address mismatch - nonce calculation error");
        console.log("AuctionManager deployed at:", address(auction));
        
        // ===== Step 6: Set Controller =====
        console.log("\n=== Step 6: Setting Auction as Controller ===");
        houseNFT.setController(tokenId, address(auction));
        console.log("Auction set as controller for token", tokenId);
        
        vm.stopBroadcast();
        
        // ===== Deployment Summary =====
        console.log("\n===========================================");
        console.log("Deployment Complete!");
        console.log("===========================================");
        console.log("HouseNFT:", address(houseNFT));
        console.log("AuctionFactory:", address(factory));
        console.log("AuctionManager:", address(auction));
        console.log("Token ID:", tokenId);
        console.log("Payment Token (USDC):", usdcAddress);
        console.log("===========================================");
        
        // ===== Next Steps =====
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on block explorer:");
        console.log("   Run: forge script script/DeployFactory.s.sol --rpc-url <network> --broadcast --verify --verifier blockscout --verifier-url <explorer_url>/api/");
        console.log("2. Users can now bid on the auction at:", address(auction));
        console.log("3. Admin can advance phases after durations pass");
        console.log("4. Finalize auction to transfer NFT to winner");
        console.log("\n=== Verification Commands ===");
        console.log("Base Sepolia:");
        console.log("  --verifier-url https://base-sepolia.blockscout.com/api/");
        console.log("Base Mainnet:");
        console.log("  --verifier-url https://base.blockscout.com/api/");
        console.log("Arc Network:");
        console.log("  --verifier-url https://arc.blockscout.com/api/ (or Arc explorer URL)");
        console.log("===========================================\n");
        console.log("2. Users can now bid on the auction at:", address(auction));
        console.log("3. Admin can advance phases after durations pass");
        console.log("4. Finalize auction to transfer NFT to winner");
        console.log("===========================================\n");
    }
    
    /**
     * @notice Helper function to compute CREATE address
     * @dev Used to predict the auction contract address before deployment
     */
    function computeCreateAddress(address deployer, uint256 nonce) internal pure override returns (address) {
        // RLP encoding for nonce
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}
