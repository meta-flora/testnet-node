# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         curl bash ca-certificates sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create entrypoint wrapper that fetches and runs the join script, forwarding all args
RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'curl -sSL https://raw.githubusercontent.com/meta-flora/testnet-node/main/join.sh | bash -s -- "$@"' \
    > entrypoint.sh \
    && chmod +x entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--help"]
