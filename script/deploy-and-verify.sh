#!/bin/bash

# Deploy and verify contracts with Blockscout
# Usage: ./script/deploy-and-verify.sh <network>

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
    echo "Usage: ./script/deploy-and-verify.sh <network>"
    echo ""
    echo "Supported networks:"
    echo "  base-sepolia  - Base Sepolia Testnet"
    echo "  base          - Base Mainnet"
    echo "  arc-testnet   - Arc Testnet"
    echo "  arc           - Arc Mainnet"
    echo ""
    exit 1
fi

# Check for private key
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY environment variable not set"
    echo "Set it with: export PRIVATE_KEY=your_private_key"
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

echo "🚀 Deploying and Verifying on $NETWORK"
echo "================================================"
echo "RPC URL: $RPC_URL"
echo "Verifier URL: $VERIFIER_URL"
echo "Chain ID: $CHAIN_ID"
echo "================================================"
echo ""

# Deploy and verify in one command
forge script script/DeployFactory.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --verifier blockscout \
    --verifier-url $VERIFIER_URL \
    -vvvv

echo ""
echo "✅ Deployment and verification complete!"
echo ""
echo "📝 Deployment details saved to:"
echo "   - broadcast/DeployFactory.s.sol/$CHAIN_ID/run-latest.json"
echo ""
