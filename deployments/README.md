# Deployed Contracts

*Last updated: 2026-02-08T04:15:46.409Z*

## Networks

### Arc Testnet (Chain ID: 5042002)

| Contract | Address | Explorer |
|----------|---------|----------|
| **HouseNFT** | `0x335845ef4f622145d963c9f39d6ff1b60757fee4` | [View](https://testnet.arcscan.app/address/0x335845ef4f622145d963c9f39d6ff1b60757fee4) |
| **AuctionFactory** | `0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7` | [View](https://testnet.arcscan.app/address/0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7) |
| **AuctionManager** | `0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca` | [View](https://testnet.arcscan.app/address/0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca) |

### Base Mainnet (Chain ID: 8453)

| Contract | Address | Explorer |
|----------|---------|----------|
| **HouseNFT** | `0x335845ef4f622145d963c9f39d6ff1b60757fee4` | [View](https://base.blockscout.com/address/0x335845ef4f622145d963c9f39d6ff1b60757fee4) |
| **AuctionFactory** | `0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7` | [View](https://base.blockscout.com/address/0x57cdf2cdeae3f54e598e8def3583a251fec0eaf7) |
| **AuctionManager** | `0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca` | [View](https://base.blockscout.com/address/0xe6afb32fdd1c03edd3dc2f1b0037c3d4580d6dca) |

### Base Sepolia (Chain ID: 84532)

| Contract | Address | Explorer |
|----------|---------|----------|
| **HouseNFT** | `0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6` | [View](https://base-sepolia.blockscout.com/address/0xe23157f7d8ad43bfcf7aaff64257fd0fa17177d6) |
| **AuctionFactory** | `0xd3390e5fec170d7577c850f5687a6542b66a4bbd` | [View](https://base-sepolia.blockscout.com/address/0xd3390e5fec170d7577c850f5687a6542b66a4bbd) |
| **AuctionManager** | `0x3347f6a853e04281daa0314f49a76964f010366f` | [View](https://base-sepolia.blockscout.com/address/0x3347f6a853e04281daa0314f49a76964f010366f) |

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
