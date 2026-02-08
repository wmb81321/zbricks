// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title HouseNFT
 * @notice Multi-token ERC721 representing houses with phase-based metadata reveals
 * @dev Each token has independent metadata URIs that update as auction phases progress
 * 
 * ROLES:
 * - Admin: Deployer address with persistent control over metadata URIs, minting, and phase advancement
 * - Controller: AuctionManager contracts that can auto-advance phases for their specific tokens
 */
contract HouseNFT is ERC721 {
    /// @notice Admin address (deployer) with persistent control
    address public admin;
    
    /// @notice Current phase for each token ID (0-3)
    mapping(uint256 => uint8) public tokenPhase;
    
    /// @notice Controller address per token (set to specific AuctionManager)
    mapping(uint256 => address) public tokenController;
    
    /// @notice Metadata URIs for each token and phase
    mapping(uint256 => mapping(uint8 => string)) public tokenPhaseURIs;
    
    /// @notice Token ID counter for auto-incrementing mints
    uint256 private _tokenIdCounter = 1;
    
    // Events
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event ControllerSet(uint256 indexed tokenId, address indexed controller);
    event PhaseAdvanced(uint256 indexed tokenId, uint8 indexed newPhase, address indexed advancedBy);
    event PhaseURIsSet(uint256 indexed tokenId);
    event PhaseURIUpdated(uint256 indexed tokenId, uint8 indexed phase, string uri);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    /**
     * @notice Constructs the HouseNFT collection
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        admin = msg.sender;
    }
    
    /**
     * @notice Mints a new NFT to the specified recipient
     * @param recipient Address to receive the NFT
     * @return tokenId The ID of the newly minted token
     */
    function mintTo(address recipient) external onlyAdmin returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _mint(recipient, tokenId);
        
        return tokenId;
    }
    
    /**
     * @notice Sets all phase URIs for a specific token (admin only)
     * @param tokenId The token ID to set URIs for
     * @param uris Array of 4 metadata URIs for phases 0-3
     */
    function setPhaseURIs(uint256 tokenId, string[4] memory uris) external onlyAdmin {
        _requireOwned(tokenId);
        
        for (uint8 i = 0; i < 4; i++) {
            tokenPhaseURIs[tokenId][i] = uris[i];
        }
        
        emit PhaseURIsSet(tokenId);
    }
    
    /**
     * @notice Updates a single phase URI for a specific token (admin only)
     * @param tokenId The token ID
     * @param phase The phase number (0-3)
     * @param uri The new metadata URI
     */
    function updatePhaseURI(uint256 tokenId, uint8 phase, string memory uri) external onlyAdmin {
        require(phase <= 3, "Invalid phase");
        _requireOwned(tokenId);
        
        tokenPhaseURIs[tokenId][phase] = uri;
        
        emit PhaseURIUpdated(tokenId, phase, uri);
    }
    
    /**
     * @notice Sets the controller address for a specific token (admin only)
     * @param tokenId The token ID
     * @param _controller Address of the AuctionManager contract for this token
     */
    function setController(uint256 tokenId, address _controller) external onlyAdmin {
        require(_controller != address(0), "Invalid controller");
        _requireOwned(tokenId);
        
        tokenController[tokenId] = _controller;
        
        emit ControllerSet(tokenId, _controller);
    }
    
    /**
     * @notice Advances to the next phase for a specific token
     * @dev Can be called by controller (AuctionManager) or admin
     * @param tokenId The token ID to advance
     * @param newPhase The new phase number (must be current + 1, except controller can jump to 3)
     */
    function advancePhase(uint256 tokenId, uint8 newPhase) external {
        _requireOwned(tokenId);
        require(newPhase <= 3, "Phase must be <= 3");
        
        uint8 currentTokenPhase = tokenPhase[tokenId];
        
        // Controller can only advance to phase 3 (finalization)
        if (msg.sender == tokenController[tokenId]) {
            require(newPhase == 3, "Controller can only advance to phase 3");
        } else {
            // Admin must follow sequential progression
            require(msg.sender == admin, "Only admin or controller");
            require(newPhase == currentTokenPhase + 1, "Invalid phase progression");
        }
        
        tokenPhase[tokenId] = newPhase;
        
        emit PhaseAdvanced(tokenId, newPhase, msg.sender);
    }
    
    /**
     * @notice Overloaded advancePhase for backward compatibility with AuctionManager
     * @dev Used by AuctionManager._syncNFTPhase() which passes only phase number
     * @param newPhase The new phase number
     */
    function advancePhase(uint8 newPhase) external {
        // This function is called by AuctionManager without tokenId
        // We need to find which token this controller manages
        // For simplicity, we'll require the controller to call the tokenId version
        revert("Use advancePhase(tokenId, newPhase)");
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
     * @notice Returns the metadata URI based on the current phase for a token
     * @param tokenId The token ID
     * @return The metadata URI for the token's current phase
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return tokenPhaseURIs[tokenId][tokenPhase[tokenId]];
    }
    
    /**
     * @notice Returns the URI for a specific phase and token
     * @param tokenId The token ID
     * @param phase The phase number (0-3)
     * @return The metadata URI
     */
    function getPhaseURI(uint256 tokenId, uint8 phase) external view returns (string memory) {
        require(phase <= 3, "Invalid phase");
        _requireOwned(tokenId);
        return tokenPhaseURIs[tokenId][phase];
    }
    
    /**
     * @notice Returns the current token ID counter value
     * @return The next token ID that will be minted
     */
    function nextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
