# Flora Chain Peer Node - Production Version
# Uses official gateway endpoints with checksum verification
FROM --platform=linux/amd64 ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV FLORA_HOME=/root/.florachain
ENV MONIKER=flora-peer-docker

# Network Configuration (from official gateway)
ENV CHAIN_ID="flora-1"
ENV MAIN_NODE_ID="0fdd195eba262dbb1cf1e33f85ff5990722d93c6"
ENV MAIN_NODE_ADDRESS="testnet-gateway.metaflora.xyz:26656"
ENV RPC_ENDPOINT="https://testnet-gateway.metaflora.xyz:26657"
ENV GRPC_ENDPOINT="https://testnet-gateway.metaflora.xyz:9090"

# Download URLs (official gateway)
ENV BINARY_URL="https://testnet-gateway.metaflora.xyz/downloads/florachaind-v2"
ENV GENESIS_URL="https://testnet-gateway.metaflora.xyz/downloads/genesis.json"
ENV CHECKSUM_URL="https://testnet-gateway.metaflora.xyz/downloads/florachaind-v2.sha256"
ENV SETUP_SCRIPT_URL="https://testnet-gateway.metaflora.xyz/downloads/peer-setup.sh"

# Install dependencies including build tools and compatibility libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    jq \
    ca-certificates \
    wget \
    libc6-dev \
    libgcc-s1 \
    libstdc++6 \
    file \
    libc6 \
    && rm -rf /var/lib/apt/lists/* && \
    # Download CosmWasm library matching the binary's version (v2.2.4)
    curl -L "https://github.com/CosmWasm/wasmvm/releases/download/v2.2.4/libwasmvm.x86_64.so" -o /lib/libwasmvm.x86_64.so && \
    chmod +x /lib/libwasmvm.x86_64.so

# Copy the peer script
COPY simple-flora-peer.sh /usr/local/bin/simple-flora-peer.sh
RUN chmod +x /usr/local/bin/simple-flora-peer.sh

# Pre-download and install the binary
RUN curl -s --connect-timeout 60 "https://testnet-gateway.metaflora.xyz/downloads/florachaind-v2" -o /usr/local/bin/florachaind && \
    chmod +x /usr/local/bin/florachaind && \
    mkdir -p /lib64 && \
    ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Expose ports
EXPOSE 26656 26657 9090 1317

# Set volume for data persistence
VOLUME ["/root/.florachain"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:26657/status || exit 1

# Labels for container identification
LABEL com.flora.service="peer-node"
LABEL com.flora.chain="flora-1"
LABEL com.flora.network="testnet"
LABEL com.flora.feature="production-gateway"
LABEL com.flora.gateway="testnet-gateway.metaflora.xyz"

# Start the peer node
CMD ["/usr/local/bin/simple-flora-peer.sh"]
