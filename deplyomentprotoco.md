Phase 1: Infrastructure (Once per network)
├─ forge script DeployFactory.s.sol --rpc-url base --broadcast --verify
├─ HouseNFT deployed: 0xNFT...
├─ Factory deployed: 0xFACT...
├─ setFactory() called
└─ Admin can now transfer to multisig if needed

Phase 2: Per Auction (Repeat for each property)
├─ Update CreateAuction.s.sol parameters
├─ forge script CreateAuction.s.sol --rpc-url base --broadcast
├─ NFT minted to factory
├─ URIs set for 4 phases
├─ Auction deployed with Safe as treasury
└─ Auction ready to accept bids