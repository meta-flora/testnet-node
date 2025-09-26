#!/bin/bash
set -euo pipefail

echo "🌱 Starting Flora Chain peer node..."

# Set environment variables
export MONIKER=${MONIKER:-flora-peer-local}
export CHAIN_ID=${CHAIN_ID:-flora-1}
export FLORA_HOME=${FLORA_HOME:-/root/.florachain}

echo "📋 Configuration:"
echo "  Moniker: $MONIKER"
echo "  Chain ID: $CHAIN_ID"
echo "  Home: $FLORA_HOME"

# Download the actual Flora Chain binary if not present or if it's gaiad
if ! command -v florachaind &> /dev/null || (florachaind version 2>&1 | grep -q "v13.0.0"); then
    echo "📥 Downloading Flora Chain binary from gateway..."
    curl -L "https://testnet-gateway.metaflora.xyz/downloads/florachaind" -o /usr/local/bin/florachaind
    chmod +x /usr/local/bin/florachaind
    
    # Verify the download
    if ! command -v florachaind &> /dev/null; then
        echo "❌ Error: Failed to download Flora Chain binary!"
        exit 1
    fi
    
    echo "✅ Flora Chain binary downloaded successfully!"
fi

# Create flora directory
mkdir -p "$FLORA_HOME"

# Initialize the chain if not already done
if [ ! -f "$FLORA_HOME/config/genesis.json" ]; then
    echo "🔧 Initializing Flora Chain for network sync..."
    
    # Initialize the chain with florachaind
    florachaind init "$MONIKER" --chain-id "$CHAIN_ID" --home "$FLORA_HOME"
    
    # Download the actual Flora Chain genesis file
    echo "📥 Downloading Flora Chain genesis file..."
    curl -s "https://testnet-gateway.metaflora.xyz/downloads/genesis.json" -o "$FLORA_HOME/config/genesis.json"
    
    echo "✅ Flora Chain initialized with correct genesis file!"
else
    echo "📁 Using existing Flora Chain configuration"
fi

# Configure the node
echo "⚙️  Configuring node..."

# Update config.toml for network sync
sed -i 's|addr_book_strict = true|addr_book_strict = false|g' "$FLORA_HOME/config/config.toml"
sed -i 's|external_address = ""|external_address = "tcp://0.0.0.0:26656"|g' "$FLORA_HOME/config/config.toml"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|g' "$FLORA_HOME/config/config.toml"

# Configure seed nodes for Flora Chain network
sed -i 's|seeds = ""|seeds = "75875d284d452fe397ab4f21d7a938b53af3414f@testnet-gateway.metaflora.xyz:26656"|g' "$FLORA_HOME/config/config.toml"

# Enable peer exchange
sed -i 's|pex = false|pex = true|g' "$FLORA_HOME/config/config.toml"

# Disable seed mode (we want to be a peer, not a seed)
sed -i 's|seed_mode = true|seed_mode = false|g' "$FLORA_HOME/config/config.toml"

# Update app.toml
sed -i 's|address = "tcp://0.0.0.0:1317"|address = "tcp://0.0.0.0:1317"|g' "$FLORA_HOME/config/app.toml"
sed -i 's|enabled-unsafe-cors = false|enabled-unsafe-cors = true|g' "$FLORA_HOME/config/app.toml"

# Set minimum gas prices
sed -i 's|minimum-gas-prices = ""|minimum-gas-prices = "0.025stake"|g' "$FLORA_HOME/config/app.toml"

echo "🚀 Starting Flora Chain peer node..."

# Start the node with florachaind
exec florachaind start --home "$FLORA_HOME" --rpc.laddr "tcp://0.0.0.0:26657" --p2p.laddr "tcp://0.0.0.0:26656" --grpc.address "0.0.0.0:9090" --log_level info
