#!/bin/bash

# Verify already deployed contracts with Blockscout
# Usage: ./script/verify-contracts.sh <network>

set -e

# Load .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

NETWORK=$1

if [ -z "$NETWORK" ]; then
    echo "❌ Error: Network not specified"
    echo ""
    echo "Usage: ./script/verify-contracts.sh <network>"
    echo ""
    echo "Supported networks:"
    echo "  base-sepolia  - Base Sepolia Testnet"
    echo "  base          - Base Mainnet"
    echo "  arc-testnet   - Arc Testnet"
    echo "  arc           - Arc Mainnet"
    echo ""
    exit 1
fi

# Set RPC URL and Blockscout verifier URL based on network
case $NETWORK in
    base-sepolia)
        RPC_URL="https://sepolia.base.org"
        VERIFIER_URL="https://base-sepolia.blockscout.com/api/"
        CHAIN_ID=84532
        ;;
    base)
        RPC_URL="https://mainnet.base.org"
        VERIFIER_URL="https://base.blockscout.com/api/"
        CHAIN_ID=8453
        ;;
    arc-testnet)
        RPC_URL="https://rpc.testnet.arc.network"
        VERIFIER_URL="https://testnet.arcscan.app/api/"
        CHAIN_ID=5042002
        ;;
    arc)
        RPC_URL="https://rpc.arc.network"  # Update when mainnet launches
        VERIFIER_URL="https://arcscan.app/api/"  # Update when mainnet launches
        CHAIN_ID=5042000  # Placeholder - update when mainnet launches
        ;;
    *)
        echo "❌ Error: Unknown network: $NETWORK"
        exit 1
        ;;
esac

echo "🔍 Verifying contracts on $NETWORK"
echo "================================================"
echo "RPC URL: $RPC_URL"
echo "Verifier URL: $VERIFIER_URL"
echo "Chain ID: $CHAIN_ID"
echo "================================================"
echo ""

# Check for deployment file
DEPLOYMENT_FILE="broadcast/DeployFactory.s.sol/$CHAIN_ID/run-latest.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "❌ Error: Deployment file not found: $DEPLOYMENT_FILE"
    echo "Deploy contracts first using: ./script/deploy-and-verify.sh $NETWORK"
    exit 1
fi

echo "📄 Using deployment file: $DEPLOYMENT_FILE"
echo ""

# Verify using the deployment file
forge script script/DeployFactory.s.sol \
    --rpc-url $RPC_URL \
    --resume \
    --verify \
    --verifier blockscout \
    --verifier-url $VERIFIER_URL \
    -vvv

echo ""
echo "✅ Verification complete!"
echo ""
