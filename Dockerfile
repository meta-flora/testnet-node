# syntax=docker/dockerfile:1

# Base image
FROM --platform=linux/amd64 ubuntu:22.04

# Disable interactive prompts
ARG DEBIAN_FRONTEND=noninteractive

# Install all required dependencies for building wasmd
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         curl bash ca-certificates sudo git build-essential jq \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# ENTRYPOINT: fetch the latest join.sh and pass all container args as moniker
ENTRYPOINT ["bash", "-lc", "curl -sSL https://raw.githubusercontent.com/meta-flora/testnet-node/main/join.sh | bash -s -- $@"]

# Default to showing help if no args provided
CMD ["--help"]
