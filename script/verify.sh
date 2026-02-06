#!/bin/bash

# Manual verification script for contracts
# Usage: ./script/verify.sh <network> <contract_name> <contract_address> [constructor_args...]

set -e

NETWORK=$1
CONTRACT_NAME=$2
CONTRACT_ADDRESS=$3
shift 3
CONSTRUCTOR_ARGS="$@"

if [ -z "$NETWORK" ] || [ -z "$CONTRACT_NAME" ] || [ -z "$CONTRACT_ADDRESS" ]; then
    echo "Usage: ./script/verify.sh <network> <contract_name> <contract_address> [constructor_args...]"
    echo ""
    echo "Examples:"
    echo "  ./script/verify.sh base_sepolia HouseNFT 0x123..."
    echo "  ./script/verify.sh base AuctionManager 0x456... <usdc_address> <nft_address> <admin> <durations>"
    exit 1
fi

echo "🔍 Verifying $CONTRACT_NAME on $NETWORK..."
echo "   Address: $CONTRACT_ADDRESS"

if [ -n "$CONSTRUCTOR_ARGS" ]; then
    echo "   Constructor args: $CONSTRUCTOR_ARGS"
    forge verify-contract \
        --rpc-url $NETWORK \
        --watch \
        $CONTRACT_ADDRESS \
        src/${CONTRACT_NAME}.sol:${CONTRACT_NAME} \
        --constructor-args $CONSTRUCTOR_ARGS
else
    forge verify-contract \
        --rpc-url $NETWORK \
        --watch \
        $CONTRACT_ADDRESS \
        src/${CONTRACT_NAME}.sol:${CONTRACT_NAME}
fi

echo "✅ Verification complete!"
