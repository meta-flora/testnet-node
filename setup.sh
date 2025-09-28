#!/bin/bash

# Flora Chain Peer Node Setup Script
echo "🌱 Flora Chain Peer Node Setup"
echo "==============================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "✅ Docker is available"

# Check if Docker Compose is available for local builds
if command -v docker-compose > /dev/null 2>&1; then
    echo "✅ Docker Compose is available"
    USE_DOCKER_COMPOSE=true
else
    echo "⚠️  Docker Compose not found, using Docker Hub image instead"
    USE_DOCKER_COMPOSE=false
fi

# Choose deployment method
echo ""
echo "🚀 Starting Flora Chain peer node..."

if [ "$USE_DOCKER_COMPOSE" = true ] && [ -f "docker-compose.yml" ]; then
    echo "📦 Building and starting with Docker Compose..."
    docker-compose up -d --build
    CONTAINER_NAME="flora-peer"
else
    echo "📦 Pulling and starting from Docker Hub..."
    docker run -d --name flora-peer \
      -p 26656:26656 -p 26657:26657 -p 1317:1317 -p 9090:9090 \
      ggingerbreadman/flora-chain-testnet-peer:latest
    CONTAINER_NAME="flora-peer"
fi

# Wait a moment for the container to start
sleep 5

# Check if container is running
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✅ Flora Chain peer node is running!"
    echo ""
    echo "📊 Monitor the node with:"
    echo "  docker logs -f $CONTAINER_NAME"
    echo ""
    echo "🌐 Access the node at:"
    echo "  RPC: http://localhost:26657"
    echo "  API: http://localhost:1317"
    echo "  gRPC: localhost:9090"
    echo "  P2P: localhost:26656"
    echo ""
    echo "🛑 Stop the node with:"
    if [ "$USE_DOCKER_COMPOSE" = true ]; then
        echo "  docker-compose down"
    else
        echo "  docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
    fi
else
    echo "❌ Failed to start Flora Chain peer node"
    echo "Check the logs with: docker logs $CONTAINER_NAME"
    exit 1
fi
