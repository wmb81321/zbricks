# Deployed Contracts

*Last updated: 2026-02-08T15:50:30.323Z*

## Networks

### Arc Testnet (Chain ID: 5042002)

| Contract | Address | Explorer |
|----------|---------|----------|
| **HouseNFT** | `0x6bb77d0b235d4d27f75ae0e3a4f465bf8ac91c0b` | [View](https://testnet.arcscan.app/address/0x6bb77d0b235d4d27f75ae0e3a4f465bf8ac91c0b) |
| **AuctionFactory** | `0x88cc60b8a6161758b176563c78abeb7495d664d1` | [View](https://testnet.arcscan.app/address/0x88cc60b8a6161758b176563c78abeb7495d664d1) |
| **AuctionManager** | `0x2fbaed3a30a53bd61676d9c5f46db5a73f710f53` | [View](https://testnet.arcscan.app/address/0x2fbaed3a30a53bd61676d9c5f46db5a73f710f53) |

### Base Mainnet (Chain ID: 8453)

| Contract | Address | Explorer |
|----------|---------|----------|
| **HouseNFT** | `0x44b659c474d1bcb0e6325ae17c882994d772e471` | [View](https://base.blockscout.com/address/0x44b659c474d1bcb0e6325ae17c882994d772e471) |
| **AuctionFactory** | `0x1d5854ef9b5fd15e1f477a7d15c94ea0e795d9a5` | [View](https://base.blockscout.com/address/0x1d5854ef9b5fd15e1f477a7d15c94ea0e795d9a5) |
| **AuctionManager** | `0x24220aeb9360aaf896c99060c53332258736e30d` | [View](https://base.blockscout.com/address/0x24220aeb9360aaf896c99060c53332258736e30d) |

### Base Sepolia (Chain ID: 84532)

| Contract | Address | Explorer |
|----------|---------|----------|
| **HouseNFT** | `0x3911826c047726de1881f5518faa06e06413aba6` | [View](https://base-sepolia.blockscout.com/address/0x3911826c047726de1881f5518faa06e06413aba6) |
| **AuctionFactory** | `0xd13e24354d6e9706b4bc89272e31374ec71a2e75` | [View](https://base-sepolia.blockscout.com/address/0xd13e24354d6e9706b4bc89272e31374ec71a2e75) |
| **AuctionManager** | `0x4aee0c5afe353fb9fa111e0b5221db715b53cb10` | [View](https://base-sepolia.blockscout.com/address/0x4aee0c5afe353fb9fa111e0b5221db715b53cb10) |

## ABIs

Contract ABIs are available in [`deployments/abi/`](./abi/) directory:

- [`AuctionFactory.json`](./abi/AuctionFactory.json)
- [`AuctionManager.json`](./abi/AuctionManager.json)
- [`HouseNFT.json`](./abi/HouseNFT.json)

## Usage

```javascript
const addresses = require('./deployments/addresses.json');
const houseNFTAbi = require('./deployments/abi/HouseNFT.json');

// Get contract address for specific chain
const chainId = '84532'; // Base Sepolia
const houseNFTAddress = addresses[chainId].contracts.HouseNFT;

// Use with ethers.js or viem
// const contract = new ethers.Contract(houseNFTAddress, houseNFTAbi, provider);
```
