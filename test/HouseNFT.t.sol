// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/HouseNFT.sol";

contract HouseNFTTest is Test {
    HouseNFT public nft;
    
    address public admin; // Test contract is admin (deployer)
    address public owner = address(1);
    address public controller = address(2);
    address public user = address(3);
    
    string[4] public phaseURIs = [
        "ipfs://Qm1234/phase0.json",
        "ipfs://Qm1234/phase1.json",
        "ipfs://Qm1234/phase2.json",
        "ipfs://Qm1234/phase3.json"
    ];
    
    function setUp() public {
        nft = new HouseNFT("Test House", "HOUSE");
        admin = address(this); // Test contract is the deployer/admin
        
        // Mint NFT to owner
        uint256 tokenId = nft.mintTo(owner);
        
        // Set phase URIs for the minted token
        vm.prank(admin);
        nft.setPhaseURIs(tokenId, phaseURIs);
    }
    
    // ============ Constructor Tests ============
    
    function testConstructorMintsToOwner() public {
        assertEq(nft.ownerOf(1), owner);
        assertEq(nft.balanceOf(owner), 1);
    }
    
    function testConstructorInitializesPhaseURIs() public {
        for (uint8 i = 0; i < 4; i++) {
            assertEq(nft.getPhaseURI(1, i), phaseURIs[i]);
        }
    }
    
    function testConstructorInitializesPhase0() public {
        assertEq(nft.tokenPhase(1), 0);
        assertEq(nft.tokenURI(1), phaseURIs[0]);
    }
    
    function testCannotMintToZeroAddress() public {
        vm.expectRevert("Invalid recipient");
        nft.mintTo(address(0));
    }
    
    // ============ Controller Tests ============
    
    function testSetController() public {
        nft.setController(1, controller);
        
        assertEq(nft.tokenController(1), controller);
    }
    
    function testCannotSetControllerToZeroAddress() public {
        vm.expectRevert("Invalid controller");
        nft.setController(1, address(0));
    }
    
    function testNonAdminCannotSetController() public {
        vm.prank(user);
        vm.expectRevert("Only admin");
        nft.setController(1, controller);
    }
    
    // ============ Phase Advancement Tests ============
    
    function testAdvancePhase() public {
        nft.setController(1, controller);
        
        // Admin can advance phases
        nft.advancePhase(1, 1);
        
        assertEq(nft.tokenPhase(1), 1);
    }
    
    function testAdvancePhaseUpdatesTokenURI() public {
        nft.setController(1, controller);
        
        assertEq(nft.tokenURI(1), phaseURIs[0]);
        
        // Admin advances phase
        nft.advancePhase(1, 1);
        
        assertEq(nft.tokenURI(1), phaseURIs[1]);
    }
    
    function testCannotAdvancePhaseWithoutAdmin() public {
        vm.prank(user);
        vm.expectRevert("Only admin or controller");
        nft.advancePhase(1, 1);
    }
    
    function testCannotSkipPhases() public {
        nft.setController(1, controller);
        
        // Admin cannot skip phases
        vm.expectRevert("Invalid phase progression");
        nft.advancePhase(1, 2); // Try to skip phase 1
    }
    
    function testCannotAdvanceBeyondPhase3() public {
        nft.setController(1, controller);
        
        // Admin advances through all phases
        nft.advancePhase(1, 1);
        nft.advancePhase(1, 2);
        nft.advancePhase(1, 3);
        
        // Try to advance to phase 4 should fail
        vm.expectRevert("Phase must be <= 3");
        nft.advancePhase(1, 4);
    }
    
    function testAdvanceThroughAllPhases() public {
        nft.setController(1, controller);
        
        // Admin advances Phase 0 -> 1
        nft.advancePhase(1, 1);
        assertEq(nft.tokenPhase(1), 1);
        assertEq(nft.tokenURI(1), phaseURIs[1]);
        
        // Admin advances Phase 1 -> 2
        nft.advancePhase(1, 2);
        assertEq(nft.tokenPhase(1), 2);
        assertEq(nft.tokenURI(1), phaseURIs[2]);
        
        // Admin advances Phase 2 -> 3
        nft.advancePhase(1, 3);
        assertEq(nft.tokenPhase(1), 3);
        assertEq(nft.tokenURI(1), phaseURIs[3]);
    }
    
    // ============ Metadata Update Tests ============
    
    function testUpdatePhaseURI() public {
        string memory newURI = "ipfs://Qm5678/phase0.json";
        
        // Admin (test contract) updates URI
        nft.updatePhaseURI(1, 0, newURI);
        
        assertEq(nft.getPhaseURI(1, 0), newURI);
        assertEq(nft.tokenURI(1), newURI); // Should reflect immediately since we're in phase 0
    }
    
    function testUpdatePhaseURIForFuturePhase() public {
        nft.setController(1, controller);
        
        string memory newURI = "ipfs://QmNEW/phase2.json";
        
        // Admin updates URI
        nft.updatePhaseURI(1, 2, newURI);
        
        assertEq(nft.getPhaseURI(1, 2), newURI);
        
        // TokenURI should still show phase 0
        assertEq(nft.tokenURI(1), phaseURIs[0]);
        
        // Admin advances to phase 2
        nft.advancePhase(1, 1);
        nft.advancePhase(1, 2);
        
        // Now tokenURI should show the updated URI
        assertEq(nft.tokenURI(1), newURI);
    }
    
    function testCannotUpdatePhaseURIWithoutAdmin() public {
        vm.prank(user);
        vm.expectRevert("Only admin");
        nft.updatePhaseURI(1, 0, "ipfs://test");
    }
    
    function testCannotUpdateInvalidPhase() public {
        nft.setController(1, controller);
        
        // Admin trying to update invalid phase
        vm.expectRevert("Invalid phase");
        nft.updatePhaseURI(1, 4, "ipfs://test");
    }
    
    // ============ TokenURI Tests ============
    
    function testTokenURIRevertsForInvalidToken() public {
        vm.expectRevert();
        nft.tokenURI(2); // Token 2 doesn't exist
    }
    
    function testTokenURIReflectsCurrentPhase() public {
        nft.setController(1, controller);
        
        for (uint8 i = 0; i < 4; i++) {
            assertEq(nft.tokenURI(1), phaseURIs[i]);
            
            if (i < 3) {
                // Admin advances all phases
                nft.advancePhase(1, i + 1);
            }
        }
    }
    
    // ============ View Function Tests ============
    
    function testGetPhaseURI() public view {
        for (uint8 i = 0; i < 4; i++) {
            assertEq(nft.getPhaseURI(1, i), phaseURIs[i]);
        }
    }
    
    function testGetPhaseURIRevertsForInvalidPhase() public {
        vm.expectRevert("Invalid phase");
        nft.getPhaseURI(1, 4);
    }
    
    // ============ ERC721 Standard Tests ============
    
    function testName() public view {
        assertEq(nft.name(), "Test House");
    }
    
    function testSymbol() public view {
        assertEq(nft.symbol(), "HOUSE");
    }
    
    function testTotalSupply() public view {
        assertEq(nft.balanceOf(owner), 1);
    }
    
    function testTransfer() public {
        vm.prank(owner);
        nft.transferFrom(owner, user, 1);
        
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.balanceOf(owner), 0);
    }
    
    function testSafeTransfer() public {
        vm.prank(owner);
        nft.safeTransferFrom(owner, user, 1);
        
        assertEq(nft.ownerOf(1), user);
    }
    
    function testApprove() public {
        vm.prank(owner);
        nft.approve(user, 1);
        
        assertEq(nft.getApproved(1), user);
        
        // User can now transfer
        vm.prank(user);
        nft.transferFrom(owner, user, 1);
        
        assertEq(nft.ownerOf(1), user);
    }
    
    function testSetApprovalForAll() public {
        vm.prank(owner);
        nft.setApprovalForAll(user, true);
        
        assertTrue(nft.isApprovedForAll(owner, user));
        
        // User can transfer
        vm.prank(user);
        nft.transferFrom(owner, address(4), 1);
        
        assertEq(nft.ownerOf(1), address(4));
    }
    
    // ============ Edge Cases ============
    
    function testAdminCanSetController() public {
        // Only admin can set controller
        nft.setController(1, controller);
        
        assertEq(nft.tokenController(1), controller);
    }
    
    function testMetadataPreservesAfterTransfer() public {
        nft.setController(1, controller);
        
        // Admin advances to phase 2
        nft.advancePhase(1, 1);
        nft.advancePhase(1, 2);
        
        // Transfer NFT
        vm.prank(owner);
        nft.transferFrom(owner, user, 1);
        
        // Metadata should still reflect phase 2
        assertEq(nft.tokenURI(1), phaseURIs[2]);
        assertEq(nft.tokenPhase(1), 2);
    }
    
    function testEmitsEvents() public {
        // Test ControllerSet event
        vm.expectEmit(true, true, false, false);
        emit HouseNFT.ControllerSet(1, controller);
        nft.setController(1, controller);
        
        // Test PhaseAdvanced event
        vm.expectEmit(true, true, true, false);
        emit HouseNFT.PhaseAdvanced(1, 1, admin);
        nft.advancePhase(1, 1);
        
        // Test PhaseURIUpdated event
        vm.expectEmit(true, true, false, true);
        emit HouseNFT.PhaseURIUpdated(1, 0, "ipfs://new");
        nft.updatePhaseURI(1, 0, "ipfs://new");
    }
}
