#!/bin/bash
set -euo pipefail

echo "🐳 Setting up Flora Chain peer node with Docker..."

# Create necessary files
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV MONIKER=flora-peer-local
ENV CHAIN_ID=flora-1
ENV FLORA_HOME=/root/.florachain

RUN apt-get update && \
    apt-get install -y curl git make build-essential jq moreutils python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://go.dev/dl/go1.24.4.linux-amd64.tar.gz -o /tmp/go.tgz && \
    tar -C /usr/local -xzf /tmp/go.tgz && \
    rm /tmp/go.tgz

ENV PATH="/usr/local/go/bin:$PATH"
ENV GOMAXPROCS=4
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

RUN curl https://get.ignite.com/cli! | bash
ENV PATH="$HOME/go/bin:$PATH"

WORKDIR /app
COPY one-liner.sh /app/install.sh
RUN chmod +x /app/install.sh

EXPOSE 26656 26657 1317 9090

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:26657/status || exit 1

CMD ["/app/install.sh"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  flora-peer:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: flora-peer-local
    ports:
      - "26656:26656"
      - "26657:26657"
      - "1317:1317"
      - "9090:9090"
    environment:
      - MONIKER=flora-peer-local
    volumes:
      - flora-data:/root/.florachain
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:26657/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s
    networks:
      - flora-network

volumes:
  flora-data:
    driver: local

networks:
  flora-network:
    driver: bridge
EOF

echo "✅ Files created successfully!"
echo "🌱 Starting Flora Chain peer node..."

# Build and start
docker-compose up --build -d

echo "🌱 Flora Chain peer node is starting up..."
echo "📊 Monitor with: docker-compose logs -f"
echo "🔗 RPC: http://localhost:26657"
echo "🌐 API: http://localhost:1317"
echo "⚡ gRPC: localhost:9090"
echo "🔌 P2P: 26656"
