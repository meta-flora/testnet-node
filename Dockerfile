FROM --platform=linux/amd64 ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV MONIKER=flora-peer-local
ENV CHAIN_ID=flora-1
ENV FLORA_HOME=/root/.florachain

# Install system dependencies
RUN apt-get update && \
    apt-get install -y curl git make build-essential jq moreutils python3 file libc6-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Go 1.24.4
RUN curl -L https://go.dev/dl/go1.24.4.linux-amd64.tar.gz -o /tmp/go.tgz && \
    tar -C /usr/local -xzf /tmp/go.tgz && \
    rm /tmp/go.tgz

# Set Go environment
ENV PATH="/usr/local/go/bin:$PATH"
ENV GOMAXPROCS=4
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

# Install Ignite CLI
RUN curl https://get.ignite.com/cli! | bash
ENV PATH="$HOME/go/bin:$PATH"

# Create app directory
WORKDIR /app

# Copy the one-liner script
COPY one-liner.sh /app/install.sh
RUN chmod +x /app/install.sh

# Expose ports
EXPOSE 26656 26657 1317 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:26657/status || exit 1

# Start the node
CMD ["/app/install.sh"]