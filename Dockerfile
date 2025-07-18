# syntax=docker/dockerfile:1

# Base image
FROM --platform=linux/amd64 ubuntu:22.04

# Disable interactive prompts
ARG DEBIAN_FRONTEND=noninteractive

# Install curl, bash, and sudo for fetching and running the join script
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         curl bash ca-certificates sudo \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# ENTRYPOINT: fetch the latest join.sh and pass all container args as moniker
ENTRYPOINT ["bash", "-lc", "curl -sSL https://raw.githubusercontent.com/meta-flora/testnet-node/main/join.sh | bash -s -- $@"]

# Default to showing help if no args provided
CMD ["--help"]
