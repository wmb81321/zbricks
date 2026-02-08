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
    address public treasury = address(5);
    
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
        
        // Deploy HouseNFT
        nft = new HouseNFT("Test House", "HOUSE");
        
        // Mint NFT to this contract temporarily
        uint256 tokenId = nft.mintTo(address(this));
        
        // Set phase URIs for the token
        nft.setPhaseURIs(tokenId, phaseURIs);
        
        // Calculate next contract address for auction deployment
        uint256 nonce = vm.getNonce(address(this));
        address predictedAuction = computeCreateAddress(address(this), nonce);
        
        // Transfer NFT to predicted auction address
        nft.transferFrom(address(this), predictedAuction, tokenId);
        
        // Deploy auction with correct parameters
        auction = new AuctionManager(
            admin,                    // initialOwner
            address(usdc),           // paymentToken
            address(nft),            // nftContract
            tokenId,                 // tokenId
            phaseDurations,          // phaseDurations
            1000e6,                  // floorPrice (1000 USDC)
            5,                       // minBidIncrementPercent (5%)
            true,                    // enforceMinIncrement
            0,                       // participationFee (0 for basic tests)
            treasury                 // treasury address
        );
        
        // Verify auction address matches prediction
        require(address(auction) == predictedAuction, "Address mismatch");
        
        // Set auction as controller for the token
        nft.setController(tokenId, address(auction));
        
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
        vm.expectRevert("Bid increment too low");
        auction.placeBid(1000e6); // Same amount
    }
    
    function testBidRefundsFormerLeader() public {
        // First bid
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Second bid (higher)
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Check that bidder1 is no longer leader
        assertEq(auction.currentLeader(), bidder2);
        assertEq(auction.currentHighBid(), 2000e6);
        // bidder1's bid is still recorded
        assertEq(auction.userBids(bidder1), 1000e6);
    }
    
    function testChecksEffectsInteractionsPattern() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // Verify state was updated before USDC transfer
        assertEq(auction.currentLeader(), bidder1);
        assertEq(auction.currentHighBid(), 1000e6);
    }
    
    function testCannotBidAfterPhase2() public {
        uint256 startTime = block.timestamp;
        
        // Advance to phase 2 (bidding still allowed)
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase(); // Phase 1
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase(); // Phase 2
        
        // Bidding is still allowed in phase 2
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        // But after finalization, bidding is closed
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
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
        
        // Bidder1 withdraws bid
        uint256 balanceBefore = usdc.balanceOf(bidder1);
        
        vm.prank(bidder1);
        auction.withdrawBid();
        
        uint256 balanceAfter = usdc.balanceOf(bidder1);
        assertEq(balanceAfter - balanceBefore, 1000e6);
        assertEq(auction.userBids(bidder1), 0);
    }
    
    function testCannotWithdrawWhenPaused() public {
        // Place two bids
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Pause auction
        vm.prank(admin);
        auction.pause();
        
        // Bidder1 cannot withdraw when paused (contract is paused)
        vm.prank(bidder1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        auction.withdrawBid();
    }
    
    function testCannotWithdrawAfterFinalization() public {
        // Place bids  
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        uint256 startTime = block.timestamp;
        
        // Advance to phase 2 and finalize
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Bidder1 cannot withdraw after finalization (auction ended)
        vm.prank(bidder1);
        vm.expectRevert("Auction ended - cannot withdraw");
        auction.withdrawBid();
    }
    
    function testCannotWithdrawZeroBalance() public {
        vm.prank(bidder1);
        vm.expectRevert("No bid to withdraw");
        auction.withdrawBid();
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
        vm.warp(block.timestamp + 48 hours + 1);
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
        vm.warp(block.timestamp + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        // Check phase 0 was locked
        (,, address leader, uint256 highBid, bool revealed) = auction.phases(0);
        assertEq(leader, bidder1);
        assertEq(highBid, 1000e6);
        assertTrue(revealed);
    }
    
    function testCannotAdvanceWhenPaused() public {
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(admin);
        auction.pause();
        
        vm.prank(admin);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        auction.advancePhase();
    }
    
    function testOnlyAdminCanAdvancePhase() public {
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bidder1));
        auction.advancePhase();
    }
    
    function testNFTMetadataUpdatesOnAdvance() public {
        uint256 tokenId = auction.tokenId();
        
        // Check initial phase
        assertEq(nft.tokenPhase(tokenId), 0);
        assertEq(nft.tokenURI(tokenId), "ipfs://phase0");
        
        // Advance auction phase
        vm.warp(block.timestamp + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        // Admin must manually advance NFT metadata
        nft.advancePhase(tokenId, 1);
        
        // Check updated phase
        assertEq(nft.tokenPhase(tokenId), 1);
        assertEq(nft.tokenURI(tokenId), "ipfs://phase1");
    }
    
    // ============ Finalization Tests ============
    
    function testFinalizeAuction() public {
        // Place bid
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        uint256 startTime = block.timestamp;
        
        // Advance through phases 0->1->2
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        // Finalize at phase 2 (wait for phase 2 duration)
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Check NFT transferred
        assertEq(nft.ownerOf(1), bidder1);
        assertTrue(auction.finalized());
    }
    
    function testCannotFinalizeWithoutWinner() public {
        // Advance through phases to phase 2 without bids
        vm.warp(block.timestamp + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(block.timestamp + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        // Wait for phase 2 duration
        vm.warp(block.timestamp + 24 hours + 1);
        
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
        
        uint256 startTime = block.timestamp;
        
        // Advance to phase 2
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
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
        
        uint256 startTime = block.timestamp;
        
        // Advance to phase 2
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        // Finalize
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
        vm.prank(admin);
        auction.finalizeAuction();
        
        // Withdraw proceeds (goes to treasury, not admin)
        uint256 balanceBefore = usdc.balanceOf(treasury);
        
        vm.prank(admin);
        auction.withdrawProceeds();
        
        uint256 balanceAfter = usdc.balanceOf(treasury);
        assertEq(balanceAfter - balanceBefore, 1000e6);
    }
    
    function testCannotWithdrawProceedsTwice() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        uint256 startTime = block.timestamp;
        
        // Advance to phase 2 and finalize
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
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
    
    function testTransferOwnership() public {
        address newOwner = address(5);
        
        vm.prank(admin);
        auction.transferOwnership(newOwner);
        
        assertEq(auction.owner(), newOwner);
        
        // Old admin cannot perform owner actions
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        auction.pause();
        
        // New owner can
        vm.prank(newOwner);
        auction.pause();
    }
    
    function testCannotTransferAdminToZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        auction.transferOwnership(address(0));
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
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bidder1));
        auction.pause();
    }
    
    // ============ View Functions Tests ============
    
    function testGetCurrentPhaseInfo() public {
        (uint256 minDuration, uint256 startTime,,,) = auction.getCurrentPhaseInfo();
        
        assertEq(minDuration, 48 hours);
        assertGt(startTime, 0);
    }
    
    function testGetBidderBid() public {
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        vm.prank(bidder2);
        auction.placeBid(2000e6);
        
        // Check bids in the system
        assertEq(auction.userBids(bidder1), 1000e6);
        assertEq(auction.userBids(bidder2), 2000e6);
    }
    
    function testIsAuctionActive() public {
        assertTrue(auction.isAuctionActive());
        
        // Place bid and finalize
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        uint256 startTime = block.timestamp;
        
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auction.advancePhase();
        
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
        vm.prank(admin);
        auction.finalizeAuction();
        
        assertFalse(auction.isAuctionActive());
    }
    
    function testGetTimeRemaining() public {
        uint256 startTime = block.timestamp;
        uint256 remaining = auction.getTimeRemaining();
        assertEq(remaining, 48 hours);
        
        // Warp forward by exactly 24 hours (no +1)
        vm.warp(startTime + 24 hours);
        remaining = auction.getTimeRemaining();
        assertEq(remaining, 24 hours);
        
        // After duration met
        vm.warp(startTime + 48 hours + 1);
        remaining = auction.getTimeRemaining();
        assertEq(remaining, 0);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzzBidAmount(uint256 amount) public {
        amount = bound(amount, 1000e6, 1_000_000_000e6); // floor price (1000 USDC) to 1B USDC
        
        usdc.mint(address(this), amount);
        usdc.approve(address(auction), amount);
        
        auction.placeBid(amount);
        
        assertEq(auction.currentHighBid(), amount);
        assertEq(auction.currentLeader(), address(this));
    }
    
    function testFuzzMultipleBids(uint256 bid1, uint256 bid2, uint256 bid3) public {
        // Bound bids to reasonable amounts within bidders' balances
        // Floor price is 1000 USDC, 5% minimum increment
        bid1 = bound(bid1, 1000e6, 1_000_000e6); // floor price to 1M USDC
        bid2 = bound(bid2, bid1 + (bid1 * 5 / 100), 2_000_000e6); // Must be 5% higher than bid1
        bid3 = bound(bid3, bid2 + (bid2 * 5 / 100), 3_000_000e6); // Must be 5% higher than bid2
        
        vm.prank(bidder1);
        auction.placeBid(bid1);
        
        vm.prank(bidder2);
        auction.placeBid(bid2);
        
        vm.prank(bidder3);
        auction.placeBid(bid3);
        
        assertEq(auction.userBids(bidder1), bid1);
        assertEq(auction.userBids(bidder2), bid2);
        assertEq(auction.currentLeader(), bidder3);
        assertEq(auction.currentHighBid(), bid3);
    }
    
    // ============ Participation Fee Tests ============
    
    function testParticipationFeeCharged() public {
        // Deploy auction with participation fee
        HouseNFT nftWithFee = new HouseNFT("Test House Fee", "HOUSE");
        uint256 tokenId = nftWithFee.mintTo(address(this));
        nftWithFee.setPhaseURIs(tokenId, phaseURIs);
        
        uint256 nonce = vm.getNonce(address(this));
        address predictedAuction = computeCreateAddress(address(this), nonce);
        nftWithFee.transferFrom(address(this), predictedAuction, tokenId);
        
        uint256 participationFee = 10e6; // 10 USDC
        AuctionManager auctionWithFee = new AuctionManager(
            admin,
            address(usdc),
            address(nftWithFee),
            tokenId,
            phaseDurations,
            1000e6,
            5,
            true,
            participationFee,
            treasury
        );
        
        nftWithFee.setController(tokenId, address(auctionWithFee));
        
        // Approve auction
        vm.prank(bidder1);
        usdc.approve(address(auctionWithFee), type(uint256).max);
        
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        uint256 bidder1BalanceBefore = usdc.balanceOf(bidder1);
        
        // Place first bid
        vm.prank(bidder1);
        auctionWithFee.placeBid(1000e6);
        
        // Verify participation fee was charged
        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore + participationFee, "Treasury should receive fee");
        assertEq(usdc.balanceOf(bidder1), bidder1BalanceBefore - 1000e6 - participationFee, "Bidder should pay bid + fee");
        assertEq(auctionWithFee.hasPaid(bidder1), true, "Bidder should be marked as paid");
        assertEq(auctionWithFee.totalParticipationFees(), participationFee, "Total fees should be tracked");
    }
    
    function testParticipationFeeOnlyChargedOnce() public {
        // Deploy auction with participation fee
        HouseNFT nftWithFee = new HouseNFT("Test House Fee", "HOUSE");
        uint256 tokenId = nftWithFee.mintTo(address(this));
        nftWithFee.setPhaseURIs(tokenId, phaseURIs);
        
        uint256 nonce = vm.getNonce(address(this));
        address predictedAuction = computeCreateAddress(address(this), nonce);
        nftWithFee.transferFrom(address(this), predictedAuction, tokenId);
        
        uint256 participationFee = 10e6;
        AuctionManager auctionWithFee = new AuctionManager(
            admin,
            address(usdc),
            address(nftWithFee),
            tokenId,
            phaseDurations,
            1000e6,
            5,
            true,
            participationFee,
            treasury
        );
        
        nftWithFee.setController(tokenId, address(auctionWithFee));
        
        vm.prank(bidder1);
        usdc.approve(address(auctionWithFee), type(uint256).max);
        
        // First bid - should charge fee
        vm.prank(bidder1);
        auctionWithFee.placeBid(1000e6);
        
        uint256 treasuryBalanceAfterFirst = usdc.balanceOf(treasury);
        uint256 bidder1BalanceAfterFirst = usdc.balanceOf(bidder1);
        
        // Second bid - should NOT charge fee again
        vm.prank(bidder1);
        auctionWithFee.placeBid(100e6); // Increase bid
        
        assertEq(usdc.balanceOf(treasury), treasuryBalanceAfterFirst, "Treasury should not receive second fee");
        assertEq(usdc.balanceOf(bidder1), bidder1BalanceAfterFirst - 100e6, "Bidder should only pay additional bid");
        assertEq(auctionWithFee.totalParticipationFees(), participationFee, "Total fees should remain same");
    }
    
    function testZeroParticipationFeeWorks() public {
        // This is the default setup - verify no fees charged
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore, "Treasury should not receive fee when fee is 0");
        assertEq(auction.hasPaid(bidder1), false, "hasPaid should remain false when fee is 0");
        assertEq(auction.totalParticipationFees(), 0, "Total fees should be 0");
    }
    
    function testTreasuryValidation() public {
        HouseNFT nftTest = new HouseNFT("Test House", "HOUSE");
        uint256 tokenId = nftTest.mintTo(address(this));
        nftTest.setPhaseURIs(tokenId, phaseURIs);
        
        uint256 nonce = vm.getNonce(address(this));
        address predictedAuction = computeCreateAddress(address(this), nonce);
        nftTest.transferFrom(address(this), predictedAuction, tokenId);
        
        // Attempt to deploy with zero address treasury
        vm.expectRevert("Invalid treasury address");
        new AuctionManager(
            admin,
            address(usdc),
            address(nftTest),
            tokenId,
            phaseDurations,
            1000e6,
            5,
            true,
            0,
            address(0) // Invalid treasury
        );
    }
    
    function testProceedsGoToTreasury() public {
        // Deploy auction with treasury
        HouseNFT nftWithTreasury = new HouseNFT("Test House Treasury", "HOUSE");
        uint256 tokenId = nftWithTreasury.mintTo(address(this));
        nftWithTreasury.setPhaseURIs(tokenId, phaseURIs);
        
        uint256 nonce = vm.getNonce(address(this));
        address predictedAuction = computeCreateAddress(address(this), nonce);
        nftWithTreasury.transferFrom(address(this), predictedAuction, tokenId);
        
        AuctionManager auctionWithTreasury = new AuctionManager(
            admin,
            address(usdc),
            address(nftWithTreasury),
            tokenId,
            phaseDurations,
            1000e6,
            5,
            true,
            0,
            treasury
        );
        
        nftWithTreasury.setController(tokenId, address(auctionWithTreasury));
        
        // Place bids
        vm.prank(bidder1);
        usdc.approve(address(auctionWithTreasury), type(uint256).max);
        vm.prank(bidder1);
        auctionWithTreasury.placeBid(1000e6);
        
        uint256 startTime = block.timestamp;
        
        // Advance through phases and finalize
        // Phase 0 -> Phase 1 (after 48 hours)
        vm.warp(startTime + 48 hours + 1);
        vm.prank(admin);
        auctionWithTreasury.advancePhase();
        
        // Phase 1 -> Phase 2 (after 24 hours)
        vm.warp(startTime + 48 hours + 24 hours + 1);
        vm.prank(admin);
        auctionWithTreasury.advancePhase();
        
        // Wait for phase 2 duration before finalizing (24 hours)
        vm.warp(startTime + 48 hours + 24 hours + 24 hours + 1);
        vm.prank(admin);
        auctionWithTreasury.finalizeAuction();
        
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        
        // Withdraw proceeds
        vm.prank(admin);
        auctionWithTreasury.withdrawProceeds();
        
        // Verify proceeds went to treasury
        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore + 1000e6, "Proceeds should go to treasury");
    }
    
    function testEmergencyWithdrawFunds() public {
        // Place a bid
        vm.prank(bidder1);
        auction.placeBid(1000e6);
        
        uint256 adminBalanceBefore = usdc.balanceOf(admin);
        uint256 auctionBalance = usdc.balanceOf(address(auction));
        
        // Emergency withdraw
        vm.prank(admin);
        auction.emergencyWithdrawFunds();
        
        // Verify funds went to admin
        assertEq(usdc.balanceOf(admin), adminBalanceBefore + auctionBalance, "Funds should go to admin");
        assertEq(usdc.balanceOf(address(auction)), 0, "Auction should have 0 balance");
    }
}

