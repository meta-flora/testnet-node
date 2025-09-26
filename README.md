# Flora Chain Testnet Node

A complete Docker setup for running a Flora Chain peer node on the `flora-1` testnet.

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/meta-flora/testnet-node.git
cd testnet-node

# Start the Flora Chain peer node
docker-compose up -d

# View logs
docker-compose logs -f
```

### Option 2: One-liner Script

```bash
# Run directly with curl
curl -sSL https://raw.githubusercontent.com/meta-flora/testnet-node/main/setup.sh | bash
```

### Option 3: Manual Docker

```bash
# Build and run
docker build -t flora-peer .
docker run -d --name flora-peer-local \
  -p 26656:26656 -p 26657:26657 -p 1317:1317 -p 9090:9090 \
  flora-peer
```

## What This Setup Does

1. **Downloads Flora Chain Binary**: Automatically downloads the real `florachaind` binary from the gateway
2. **Downloads Genesis File**: Gets the correct genesis file for `flora-1` testnet
3. **Configures Network**: Sets up proper seed nodes and peer exchange
4. **Platform Compatible**: Works on both Intel and Apple Silicon Macs
5. **Auto-sync**: Connects to the Flora Chain network and starts syncing

## Configuration

The node is pre-configured for the Flora Chain testnet:

- **Chain ID**: `flora-1`
- **Seed Nodes**: `testnet-gateway.metaflora.xyz:26656`
- **Genesis**: Downloaded from `https://testnet-gateway.metaflora.xyz/downloads/genesis.json`
- **Binary**: Downloaded from `https://testnet-gateway.metaflora.xyz/downloads/florachaind`

## Access Points

Once running, you can access:

- **RPC**: http://localhost:26657
- **API**: http://localhost:1317
- **gRPC**: localhost:9090
- **P2P**: 26656

## Check Node Status

```bash
# Check sync status
curl -s http://localhost:26657/status | jq '.result.sync_info'

# Check connected peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# Check latest block
curl -s http://localhost:26657/status | jq '.result.sync_info.latest_block_height'
```

## Files

- `Dockerfile` - Container definition with Ubuntu 22.04 and dependencies
- `docker-compose.yml` - Orchestration with proper platform settings
- `one-liner.sh` - Main script that downloads binary, configures, and starts node
- `setup.sh` - Quick deployment script

## Requirements

- Docker and Docker Compose
- Internet connection for downloading binary and genesis file
- Ports 26656, 26657, 1317, 9090 available

## Troubleshooting

### Apple Silicon (M1/M2) Issues
The setup automatically handles Apple Silicon compatibility by building for the `linux/amd64` platform.

### Binary Download Issues
If the binary download fails, check that the gateway endpoints are accessible:
- https://testnet-gateway.metaflora.xyz/downloads/florachaind
- https://testnet-gateway.metaflora.xyz/downloads/genesis.json

### Sync Issues
If the node isn't syncing, check the logs:
```bash
docker-compose logs -f
```

## Network Information

- **Testnet**: flora-1
- **Gateway**: testnet-gateway.metaflora.xyz
- **Seed Node**: 75875d284d452fe397ab4f21d7a938b53af3414f@testnet-gateway.metaflora.xyz:26656

---

Let It Grow! 🌱
