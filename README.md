# 🌱 Flora Chain Peer Node

A production-ready Docker setup for running a Flora Chain peer node on the testnet with full CosmWasm support.

## 🚀 Quick Start

### Option 1: Docker Hub (Recommended - No Build Required)

```bash
# Pull and run the pre-built image from Docker Hub
docker run -d --name flora-peer \
  -p 26656:26656 -p 26657:26657 -p 1317:1317 -p 9090:9090 \
  ggingerbreadman/flora-chain-testnet-peer:latest

# Check node status
curl http://localhost:26657/status | jq -r '.result.node_info.moniker, .result.sync_info.latest_block_height'
```

### Option 2: Docker Compose

```bash
# Clone the repository
git clone https://github.com/meta-flora/testnet-node.git
cd testnet-node

# Start the Flora Chain peer node
docker-compose up -d

# Check node status
curl http://localhost:26657/status | jq -r '.result.node_info.moniker, .result.sync_info.latest_block_height'
```

### Option 3: One-liner Script

```bash
# Run directly with curl (uses Docker Hub image)
curl -sSL https://raw.githubusercontent.com/meta-flora/testnet-node/main/setup.sh | bash
```

## 📋 Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- Ports 26656, 26657, 9090, and 1317 available

## 🐳 Docker Hub

The pre-built image is available on Docker Hub:

- **Image**: `ggingerbreadman/flora-chain-testnet-peer:latest`
- **Tags**: `latest`, `main`, `v1.0.0`
- **Platforms**: `linux/amd64`, `linux/arm64` (multi-architecture support)
- **Size**: ~200MB (optimized for quick downloads)

### Available Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release |
| `main` | Latest from main branch |
| `v1.0.0` | Specific version releases |

### Pull Command

```bash
# Pull the latest image
docker pull ggingerbreadman/flora-chain-testnet-peer:latest

# Pull a specific version
docker pull ggingerbreadman/flora-chain-testnet-peer:v1.0.0
```

## 🏗️ Architecture

This setup uses:
- **Base Image**: Ubuntu 22.04 (x86_64 platform)
- **Binary**: `florachaind-v2` from official gateway
- **CosmWasm**: v2.2.4 library for smart contract support
- **Chain**: Flora Chain testnet (`flora-1`)

## 📁 Project Structure

```
testnet-node/
├── Dockerfile              # Production Docker image
├── docker-compose.yml      # Docker Compose configuration
├── simple-flora-peer.sh    # Main peer node script
├── setup.sh               # Convenience setup script
├── README.md              # This file
├── LICENSE                # MIT License
└── .gitignore             # Git ignore file
```

## 🔧 Configuration

### Environment Variables

The following environment variables can be customized in `docker-compose.yml`:

```yaml
environment:
  - MONIKER=flora-peer-docker     # Node identifier
  - FLORA_HOME=/root/.florachain  # Data directory
  - CHAIN_ID=flora-1             # Chain identifier
  - MAIN_NODE_ID=0fdd195eba262dbb1cf1e33f85ff5990722d93c6
  - MAIN_NODE_ADDRESS=testnet-gateway.metaflora.xyz:26656
```

### Network Configuration

- **P2P Port**: 26656 (node-to-node communication)
- **RPC Port**: 26657 (JSON-RPC API)
- **API Port**: 1317 (REST API)
- **gRPC Port**: 9090 (gRPC API)

## 🌐 Available Endpoints

Once running, the following endpoints are available:

| Service | URL | Description |
|---------|-----|-------------|
| RPC | `http://localhost:26657` | JSON-RPC API for blockchain queries |
| API | `http://localhost:1317` | REST API for application queries |
| gRPC | `http://localhost:9090` | gRPC API for high-performance queries |
| P2P | `localhost:26656` | Peer-to-peer networking |

## 📊 Monitoring

### Check Node Status
```bash
# Basic status
curl http://localhost:26657/status

# Get latest block height
curl http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'

# Get node information
curl http://localhost:26657/status | jq -r '.result.node_info.id, .result.node_info.moniker'
```

### View Logs
```bash
# Follow logs
docker logs -f flora-peer

# Last 50 lines
docker logs --tail 50 flora-peer
```

### Health Check
```bash
# Check if container is healthy
docker ps

# Manual health check
curl -f http://localhost:26657/status || echo "Node not responding"
```

## 🛠️ Management Commands

### Start/Stop Services
```bash
# Start the peer node
docker-compose up -d

# Stop the peer node
docker-compose down

# Stop and remove all data (fresh start)
docker-compose down -v
```

### Rebuild and Restart
```bash
# Rebuild with latest changes
docker-compose up -d --build

# Force rebuild without cache
docker-compose build --no-cache
docker-compose up -d
```

### Data Management
```bash
# View data volume
docker volume ls | grep flora

# Backup data (optional)
docker run --rm -v florapeer_flora-data:/data -v $(pwd):/backup ubuntu tar czf /backup/flora-backup.tar.gz /data

# Restore data (optional)
docker run --rm -v florapeer_flora-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/flora-backup.tar.gz -C /
```

## 🔍 Troubleshooting

### Common Issues

**Container keeps restarting**
```bash
# Check logs for errors
docker logs flora-peer

# Verify system resources
docker stats flora-peer
```

**Node not syncing**
```bash
# Check network connectivity
docker exec flora-peer curl -s https://testnet-gateway.metaflora.xyz:26657/status

# Check peer connections
curl http://localhost:26657/net_info | jq -r '.result.n_peers'
```

**Port conflicts**
```bash
# Check what's using the ports
lsof -i :26656 -i :26657 -i :9090 -i :1317

# Modify ports in docker-compose.yml if needed
```

### Reset Node State
```bash
# Stop and remove all data for fresh sync
docker-compose down -v
docker-compose up -d
```

## 🔒 Security Considerations

- The node runs with default Docker security settings
- No root privileges are required on the host
- Data is persisted in Docker volumes
- Network ports are bound to localhost by default

## 📈 Performance Tuning

### Resource Limits
Add resource limits to `docker-compose.yml`:
```yaml
services:
  flora-peer:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
```

### Optimize for Production
- Use a dedicated server with SSD storage
- Ensure stable internet connection
- Monitor system resources regularly
- Consider using Docker Swarm or Kubernetes for high availability

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the troubleshooting section above
- Review Docker and Docker Compose logs
- Ensure all prerequisites are met
- Verify network connectivity to Flora Chain testnet

## 🎯 What's Included

✅ **Production-ready setup** with official Flora Chain v2 binary  
✅ **Full CosmWasm support** with matching library version  
✅ **Automatic binary verification** with checksum validation  
✅ **Health monitoring** with built-in health checks  
✅ **Persistent data storage** with Docker volumes  
✅ **Complete API access** (RPC, REST, gRPC)  
✅ **Easy management** with Docker Compose  
✅ **Comprehensive documentation** and troubleshooting guide  

---

**🌱 Happy Flora Chaining!** 🚀
