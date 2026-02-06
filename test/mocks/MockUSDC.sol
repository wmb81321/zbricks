// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing with 6 decimals
 */
contract MockUSDC is ERC20 {
    /**
     * @notice Constructs the mock USDC token
     */
    constructor() ERC20("Mock USDC", "USDC") {}
    
    /**
     * @notice Returns 6 decimals to match real USDC
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    /**
     * @notice Mints tokens to an address (public for testing)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint (in 6 decimals)
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
