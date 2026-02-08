// DEPRECATED: This deployment script is for the old architecture
// Use DeployFactory.s.sol instead for the new factory-based deployment

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

/**
 * @title DeployAuction (DEPRECATED)
 * @notice Old deployment script - use DeployFactory.s.sol instead
 * @dev This script is kept for reference only
 */
contract DeployAuction is Script {
    function run() external {
        console.log("===========================================");
        console.log("DEPRECATED SCRIPT");
        console.log("===========================================");
        console.log("This deployment script is deprecated.");
        console.log("Please use: script/DeployFactory.s.sol");
        console.log("===========================================");
        revert("Use DeployFactory.s.sol instead");
    }
}
