// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AuctionManager.sol";
import "../src/HouseNFT.sol";
import "./mocks/MockUSDC.sol";

contract AuctionManagerTest is Test {
    AuctionManager public auction;
    HouseNFT public nft;
    MockUSDC public usdc;
    
    address public admin = address(1);
    address public bidder1 = address(2);
    address public bidder2 = address(3);
    address public bidder3 = address(4);
    
    // Phase URIs for testing
    string[4] public phaseURIs = [
        "ipfs://phase0",
        "ipfs://phase1",
        "ipfs://phase2",
        "ipfs://phase3"
    ];
    
    // Phase durations: 48h, 24h, 24h, 24h
    uint256[4] public phaseDurations = [
        uint256(48 hours),
        uint256(24 hours),
        uint256(24 hours),
        uint256(24 hours)
    ];
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockUSDC();
        
        // Deploy HouseNFT (will be owned by auction contract)
        // We need to deploy auction first, so we'll do it in two steps
        
        // First deploy with temporary owner
        nft = new HouseNFT("Test House", "HOUSE", phaseURIs, address(this));
        
        // Deploy auction
        auction = new AuctionManager(
            address(usdc),
            address(nft),
            admin,
            phaseDurations
        );
        
        // Transfer NFT to auction and set controller
        nft.transferFrom(address(this), address(auction), 1);
        nft.setController(address(auction));
        
        // Mint USDC to bidders
        usdc.mint(bidder1, 10_000_000e6); // 10M USDC
        usdc.mint(bidder2, 10_000_000e6);
        usdc.mint(bidder3, 10_000_000e6);
        
        // Approve auction contract
        vm.prank(bidder1);
        usdc.approve(address(auction), type(uint256).max);
        
        vm.prank(bidder2);
        usdc.approve(address(auction), type(uint256).max);
        
        vm.prank(bidder3);
        usdc.approve(address(auction), type(uint256).max);
    }
    
    // ============ Bidding Tests ============
    
    function testBidPlacement() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6); // 1000 USDC
        
        assertEq(auction.currentLeader(), bidder1);
        assertEq(auction.currentHighBid(), 1000e6);
        assertEq(usdc.balanceOf(address(auction)), 1000e6);
    }
    
    function testBidMustBeHigher() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        vm.expectRevert("Bid too low");
        auction.placeBid(1000e6); // Same amount
    }
    
    function testBidRefundsFormerLeader() public {
        // First bid
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Second bid (higher)
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Check refund balance for bidder1
        assertEq(auction.refundBalance(bidder1), 1000e6);
        assertEq(auction.currentLeader(), bidder2);
        assertEq(auction.currentHighBid(), 2000e6);
    }
    
    function testChecksEffectsInteractionsPattern() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Verify state was updated before USDC transfer
        assertEq(auction.currentLeader(), bidder1);
        assertEq(auction.currentHighBid(), 1000e6);
    }
    
    function testCannotBidAfterPhase2() public {
        // Advance to phase 2 (bidding still allowed)
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase(); // Phase 1
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase(); // Phase 2
        
        // Bidding is still allowed in phase 2
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // But after finalization, bidding is closed
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        vm.prank(bidder2);
        vm.expectRevert("Auction ended");
        auction.placeBid(2000e6);
    }
    
    function testCannotBidWhenPaused() public {
        vm.prank(admin);
        auction.pause();
        
        vm.prank(bidder1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        auction.placeBid(1000e6);
    }
    
    // ============ Withdrawal Tests ============
    
    function testWithdrawRefund() public {
        // Place two bids
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Bidder1 withdraws refund
        uint256 balanceBefore = usdc.balanceOf(bidder1);
        
        vm.prank(bidder1);
        auction.withdraw();
        
        uint256 balanceAfter = usdc.balanceOf(bidder1);
        assertEq(balanceAfter - balanceBefore, 1000e6);
        assertEq(auction.refundBalance(bidder1), 0);
    }
    
    function testWithdrawWorksWhenPaused() public {
        // Place two bids
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Pause auction
        vm.prank(admin);
        auction.pause();
        
        // Bidder1 can still withdraw (emergency fund access)
        vm.prank(bidder1);
        auction.withdraw();
        
        assertEq(usdc.balanceOf(bidder1), 10_000_000e6); // Full amount back
    }
    
    function testWithdrawAfterFinalization() public {
        // Place bids  
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Advance to phase 2 and finalize
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Bidder1 can still withdraw after finalization
        vm.prank(bidder1);
        auction.withdraw();
        
        assertEq(auction.refundBalance(bidder1), 0);
    }
    
    function testCannotWithdrawZeroBalance() public {
        vm.prank(bidder1);
        vm.expectRevert("No refund");
        auction.withdraw();
    }
    
    // ============ Phase Advancement Tests ============
    
    function testPhase0Requires48Hours() public {
        // Try to advance before 48 hours
        vm.warp(block.timestamp + 47 hours);
        vm.prank(admin);
        vm.expectRevert("Duration not met");
        auction.advancePhase();
        
        // Advance after 48 hours
        vm.warp(block.timestamp + 1 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        assertEq(auction.currentPhase(), 1);
    }
    
    function testPhase1Requires24Hours() public {
        // Advance to phase 1
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        // Try to advance before 24 hours
        vm.warp(block.timestamp + 23 hours);
        vm.prank(admin);
        vm.expectRevert("Duration not met");
        auction.advancePhase();
        
        // Advance after 24 hours
        vm.warp(block.timestamp + 1 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        assertEq(auction.currentPhase(), 2);
    }
    
    function testPhaseAdvancementLocksLeader() public {
        // Place bid in phase 0
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Advance to phase 1
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        // Check phase 0 was locked
        (,, address leader, uint256 highBid, bool revealed) = auction.phases(0);
        assertEq(leader, bidder1);
        assertEq(highBid, 1000e6);
        assertTrue(revealed);
    }
    
    function testCannotAdvanceWhenPaused() public {
        vm.warp(block.timestamp + 48 hours);
        
        vm.prank(admin);
        auction.pause();
        
        vm.prank(admin);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        auction.advancePhase();
    }
    
    function testOnlyAdminCanAdvancePhase() public {
        vm.warp(block.timestamp + 48 hours);
        
        vm.prank(bidder1);
        vm.expectRevert("Only admin");
        auction.advancePhase();
    }
    
    function testNFTMetadataUpdatesOnAdvance() public {
        // Check initial phase
        assertEq(nft.currentPhase(), 0);
        assertEq(nft.tokenURI(1), "ipfs://phase0");
        
        // Advance auction phase
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        // Admin must manually advance NFT metadata
        nft.advancePhase(1);
        
        // Check updated phase
        assertEq(nft.currentPhase(), 1);
        assertEq(nft.tokenURI(1), "ipfs://phase1");
    }
    
    // ============ Finalization Tests ============
    
    function testFinalizeAuction() public {
        // Place bid
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Advance through phases 0->1->2
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        // Finalize at phase 2
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Check NFT transferred
        assertEq(nft.ownerOf(1), bidder1);
        assertTrue(auction.finalized());
    }
    
    function testCannotFinalizeWithoutWinner() public {
        // Advance through phases to phase 2 without bids
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        // Wait for phase 2 duration
        vm.warp(block.timestamp + 24 hours);
        
        // Try to finalize without winner
        vm.prank(admin);
        vm.expectRevert("No winner");
        auction.finalizeAuction();
    }
    
    function testCannotFinalizeBeforePhase2() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(admin);
        vm.expectRevert("Must be at phase 2");
        auction.finalizeAuction();
    }
    
    function testCannotFinalizeTwice() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Advance to phase 2
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Try again
        vm.prank(admin);
        vm.expectRevert("Already finalized");
        auction.finalizeAuction();
    }
    
    // ============ Admin Functions Tests ============
    
    function testWithdrawProceeds() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Advance to phase 2
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        // Finalize
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Withdraw proceeds
        uint256 balanceBefore = usdc.balanceOf(admin);
        
        vm.prank(admin);
        auction.withdrawProceeds();
        
        uint256 balanceAfter = usdc.balanceOf(admin);
        assertEq(balanceAfter - balanceBefore, 1000e6);
    }
    
    function testCannotWithdrawProceedsTwice() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Advance to phase 2 and finalize
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // First withdrawal
        vm.prank(admin);
        auction.withdrawProceeds();
        
        // Try again
        vm.prank(admin);
        vm.expectRevert("Already withdrawn");
        auction.withdrawProceeds();
    }
    
    function testTransferAdmin() public {
        address newAdmin = address(5);
        
        vm.prank(admin);
        auction.transferAdmin(newAdmin);
        
        assertEq(auction.admin(), newAdmin);
        
        // Old admin cannot perform admin actions
        vm.prank(admin);
        vm.expectRevert("Only admin");
        auction.pause();
        
        // New admin can
        vm.prank(newAdmin);
        auction.pause();
    }
    
    function testCannotTransferAdminToZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid admin");
        auction.transferAdmin(address(0));
    }
    
    // ============ Pause Tests ============
    
    function testPauseAndUnpause() public {
        vm.prank(admin);
        auction.pause();
        
        assertTrue(auction.paused());
        
        vm.prank(admin);
        auction.unpause();
        
        assertFalse(auction.paused());
    }
    
    function testOnlyAdminCanPause() public {
        vm.prank(bidder1);
        vm.expectRevert("Only admin");
        auction.pause();
    }
    
    // ============ View Functions Tests ============
    
    function testGetCurrentPhaseInfo() public {
        (uint256 minDuration, uint256 startTime,,,) = auction.getCurrentPhaseInfo();
        
        assertEq(minDuration, 48 hours);
        assertGt(startTime, 0);
    }
    
    function testGetBidderRefund() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        assertEq(auction.getBidderRefund(bidder1), 1000e6);
        assertEq(auction.getBidderRefund(bidder2), 0);
    }
    
    function testIsAuctionActive() public {
        assertTrue(auction.isAuctionActive());
        
        // Place bid and finalize
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.warp(block.timestamp + 48 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours);
        vm.prank(admin);
        auction.finalizeAuction();
        
        assertFalse(auction.isAuctionActive());
    }
    
    function testGetTimeRemaining() public {
        uint256 remaining = auction.getTimeRemaining();
        assertEq(remaining, 48 hours);
        
        // Warp forward
        vm.warp(block.timestamp + 24 hours);
        remaining = auction.getTimeRemaining();
        assertEq(remaining, 24 hours);
        
        // After duration met
        vm.warp(block.timestamp + 24 hours);
        remaining = auction.getTimeRemaining();
        assertEq(remaining, 0);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzzBidAmount(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000_000e6); // 1 USDC to 1B USDC
        
        usdc.mint(address(this), amount);
        usdc.approve(address(auction), amount);
        
        auction.placeBid(amount);
        
        assertEq(auction.currentHighBid(), amount);
        assertEq(auction.currentLeader(), address(this));
    }
    
    function testFuzzMultipleBids(uint256 bid1, uint256 bid2, uint256 bid3) public {
        // Bound bids to reasonable amounts within bidders' balances
        bid1 = bound(bid1, 1e6, 1_000_000e6); // 1 USDC to 1M USDC
        bid2 = bound(bid2, bid1 + 1, 2_000_000e6); // Must be higher than bid1, up to 2M
        bid3 = bound(bid3, bid2 + 1, 3_000_000e6); // Must be higher than bid2, up to 3M
        
        vm.prank(bidder1);
        auction.placeBid(bid1);
        
        vm.prank(bidder2);
        auction.placeBid(bid2);
        
        vm.prank(bidder3);
        auction.placeBid(bid3);
        
        assertEq(auction.refundBalance(bidder1), bid1);
        assertEq(auction.refundBalance(bidder2), bid2);
        assertEq(auction.currentLeader(), bidder3);
        assertEq(auction.currentHighBid(), bid3);
    }
}
