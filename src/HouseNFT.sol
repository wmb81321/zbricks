// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title HouseNFT
 * @notice Single-token ERC721 representing a house with phase-based metadata reveals
 * @dev Metadata URI updates automatically as auction phases progress
 * 
 * ROLES:
 * - Admin: Deployer address with persistent control over metadata URIs and phase advancement
 * - Controller: AuctionManager contract that can auto-advance to phase 3 on finalization
 */
contract HouseNFT is ERC721 {
    /// @notice Admin address (deployer) with persistent control
    address public admin;
    
    /// @notice Current phase of the auction (0-3)
    uint8 public currentPhase;
    
    /// @notice Controller address (AuctionManager) authorized to advance phases
    address public controller;
    
    /// @notice Tracks if controller has been set (one-time setup)
    bool private controllerSet;
    
    /// @notice Mapping of phase number to metadata URI
    mapping(uint8 => string) private phaseURIs;
    
    /// @notice Fixed token ID for the single house NFT
    uint256 private constant TOKEN_ID = 1;
    
    // Events
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event ControllerSet(address indexed controller);
    event PhaseAdvanced(uint8 indexed newPhase, address indexed advancedBy);
    event PhaseURIUpdated(uint8 indexed phase, string uri);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    /**
     * @notice Constructs the HouseNFT with pre-initialized phase URIs
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     * @param _phaseURIs Array of 4 metadata URIs for phases 0-3
     * @param _initialOwner Address to receive the minted NFT (AuctionManager)
     */
    constructor(
        string memory name,
        string memory symbol,
        string[4] memory _phaseURIs,
        address _initialOwner
    ) ERC721(name, symbol) {
        require(_initialOwner != address(0), "Invalid initial owner");
        
        // Set deployer as admin
        admin = msg.sender;
        
        // Initialize phase URIs
        for (uint8 i = 0; i < 4; i++) {
            phaseURIs[i] = _phaseURIs[i];
        }
        
        // Mint the single NFT to the auction contract
        _mint(_initialOwner, TOKEN_ID);
    }
    
    /**
     * @notice Transfers admin role to a new address
     * @param newAdmin The address of the new admin
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        
        address previousAdmin = admin;
        admin = newAdmin;
        
        emit AdminTransferred(previousAdmin, newAdmin);
    }
    
    /**
     * @notice Sets the controller address (admin only, one-time setup)
     * @param _controller Address of the AuctionManager contract
     */
    function setController(address _controller) external onlyAdmin {
        require(!controllerSet, "Controller already set");
        require(_controller != address(0), "Invalid controller");
        
        controller = _controller;
        controllerSet = true;
        
        emit ControllerSet(_controller);
    }
    
    /**
     * @notice Advances to the next phase (admin only)
     * @dev Admin manually advances phases 0->1, 1->2, 2->3
     * @param newPhase The new phase number (must be currentPhase + 1)
     */
    function advancePhase(uint8 newPhase) external onlyAdmin {
        require(newPhase == currentPhase + 1, "Invalid phase progression");
        require(newPhase <= 3, "Phase must be <= 3");
        
        currentPhase = newPhase;
        
        emit PhaseAdvanced(newPhase, msg.sender);
    }
    
    /**
     * @notice Updates the metadata URI for a specific phase (admin only)
     * @param phase The phase number to update (0-3)
     * @param uri The new metadata URI
     */
    function updatePhaseURI(uint8 phase, string memory uri) external onlyAdmin {
        require(phase <= 3, "Invalid phase");
        
        phaseURIs[phase] = uri;
        
        emit PhaseURIUpdated(phase, uri);
    }
    
    /**
     * @notice Returns the metadata URI based on the current phase
     * @param tokenId The token ID (must be 1)
     * @return The metadata URI for the current phase
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return phaseURIs[currentPhase];
    }
    
    /**
     * @notice Returns the URI for a specific phase (view function)
     * @param phase The phase number (0-3)
     * @return The metadata URI for the specified phase
     */
    function getPhaseURI(uint8 phase) external view returns (string memory) {
        require(phase <= 3, "Invalid phase");
        return phaseURIs[phase];
    }
}
