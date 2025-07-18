#!/usr/bin/env bash
set -euo pipefail

####################################
# 🖥️ Windows check — if running under Git Bash or Cygwin on Windows,
# re-invoke this same script inside WSL and exit
####################################
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "▶ Detected Windows (Git Bash/Cygwin); launching under WSL…"
    # Convert this script’s Windows path to WSL path
    WSL_SCRIPT=$(wsl wslpath -u "$PWD/$0" | tr -d '\r')
    # Pass all arguments
    ARGS=("$@")
    CMD="\"$WSL_SCRIPT\""
    for a in "${ARGS[@]}"; do
      CMD+=" \"$a\""
    done
    wsl bash -lc "$CMD"
    exit
    ;;
esac

####################################
# 📦 Install dependencies (only on Linux)
####################################
OS_NAME=$(uname -s)
if [[ "$OS_NAME" == "Linux" ]]; then
  echo "=== Installing system dependencies ==="
  sudo apt update
  sudo apt install -y build-essential curl git jq
elif [[ "$OS_NAME" == "Darwin" ]]; then
  echo "▶ Detected macOS; skipping apt. Ensure deps via Homebrew:"
  echo "    brew install git jq go"
else
  echo "▶ Detected $OS_NAME; skipping package install."
fi

####################################
# Install Go (version 1.21.6) on Linux, skip on macOS
####################################
if [[ "$OS_NAME" == "Linux" ]]; then
  if ! command -v go &> /dev/null; then
    echo "=== Installing Go ==="
    curl -OL https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz

    # Add Go to PATH for this script
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin

    # Persist Go paths
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
  fi
elif [[ "$OS_NAME" == "Darwin" ]]; then
  if ! command -v go &> /dev/null; then
    echo "❌ Go not found. Install with Homebrew: brew install go"
    exit 1
  fi
fi

# Verify Go installation
echo "✅ Go version: $(go version)"

####################################
# ⬆️ Auto-patch & build wasmd with flora prefixes
####################################
REPO="$HOME/src/github.com/CosmWasm/wasmd"
echo "🔧 Cloning/building wasmd@v0.60.0 → flora…"
if [ -d "$REPO" ]; then
  pushd "$REPO" >/dev/null
  git fetch --all --tags
  git reset --hard origin/main
else
  git clone https://github.com/CosmWasm/wasmd.git "$REPO"
  pushd "$REPO" >/dev/null
fi
git checkout tags/v0.60.0

# Patch Bech32 prefixes
sed -i.bak -E 's|^([[:space:]]*const Bech32Prefix = ).*|\1"flora"|' app/app.go
sed -i.bak -E \
  -e 's|^([[:space:]]*)SetBech32PrefixForAccount\(.*|\1SetBech32PrefixForAccount("flora","florapub")|' \
  -e 's|^([[:space:]]*)SetBech32PrefixForValidator\(.*|\1SetBech32PrefixForValidator("floravaloper","floravaloperpub")|' \
  -e 's|^([[:space:]]*)SetBech32PrefixForConsensusNode\(.*|\1SetBech32PrefixForConsensusNode("floravalcons","floravalconspub")|' \
  cmd/wasmd/main.go

# Build & install
GO_CMD=go
if [[ "$OS_NAME" == "Linux" ]]; then
  GO_CMD=go
fi
# Use go in PATH for both Linux and macOS
$GO_CMD install -mod=readonly -tags "netgo,ledger" \
  -ldflags "\
    -X github.com/CosmWasm/wasmd/app.Bech32Prefix=flora \
    -X github.com/cosmos/cosmos-sdk/version.AppName=wasmd \
    -X github.com/cosmos/cosmos-sdk/version.Name=wasm \
    -X github.com/cosmos/cosmos-sdk/version.Version=v0.60.0 \
    -X github.com/cosmos/cosmos-sdk/version.Commit=$(git rev-parse HEAD)" \
  ./cmd/wasmd
popd
echo "✅ Built $(wasmd version --long | head -n1)"

####################################
# --- New: Verify remote wasmd versions ---
####################################
RPC_SERVERS=(
  "testnet-gateway.metaflora.xyz"
  "testnet-seed1.metaflora.xyz"
  "testnet-seed2.metaflora.xyz"
)
RPC_PORT=26657

echo
echo "=== Verifying remote wasmd versions ==="
for host in "${RPC_SERVERS[@]}"; do
  echo -n "$host: "
  curl -sSL "http://$host:$RPC_PORT/abci_info" \
    | jq -r '.result.response.data + " (app ver: " + .result.response.version + ")"'
done
echo

####################################
# 👤 User settings & usage
####################################
if [ $# -lt 1 ]; then
  echo "Usage: $0 <moniker>"
  exit 1
fi
MONIKER="$1"
CHAIN_ID="flora-1"
HOME_DIR="$HOME/florachain"
P2P_PORT=26656
STATE_SYNC_DELAY=1000

####################################
# 🧹 Clean slate & init
####################################
echo "=== Removing old state at $HOME_DIR"
rm -rf "$HOME_DIR"

echo "=== Initializing node: $MONIKER"
wasmd init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" --overwrite

deploy="$HOME_DIR/config"
# CLI settings
sed -i.bak 's|^keyring-backend *=.*|keyring-backend = "test"|' "$deploy/client.toml"
sed -i.bak 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025uflora"|' "$deploy/app.toml"

####################################
# 🌐 Fetch **full** genesis (includes chain_id!)
####################################
GENESIS_URL="http://${RPC_SERVERS[0]}:${RPC_PORT}/genesis"
echo "=== Fetching genesis from $GENESIS_URL"
curl -sSL "$GENESIS_URL" \
  | jq -r '.result.genesis' \
  > "$deploy/genesis.json"

if ! jq -e '.chain_id' "$deploy/genesis.json" >/dev/null; then
  echo "❌ error: genesis.json missing chain_id"
  exit 1
fi

tmp="$deploy/genesis.json.tmp"
jq '.consensus_params.block.time_iota_ms="1000"' "$deploy/genesis.json" > "$tmp" && mv "$tmp" "$deploy/genesis.json"

####################################
# 🔗 Configure P2P & Fast State-Sync
####################################
config="$deploy/config.toml"

# build persistent_peers
peer_list=()
for host in "${RPC_SERVERS[@]}"; do
  id=$(curl -sSL "http://$host:${RPC_PORT}/status" | jq -r '.result.node_info.id')
  peer_list+=("${id}@$host:${P2P_PORT}")
done
PEERS=$(IFS=,; echo "${peer_list[*]}")

echo "=== Setting P2P peers: $PEERS"
sed -i.bak -E \
  -e "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" \
  -e 's|^pex *=.*|pex = true|' \
  -e 's|^seed_mode *=.*|seed_mode = false|' \
  "$config"

# strip any old [state_sync]
awk '!inSync {print} /^\[state_sync\]/ {inSync=1} /^\[.*\]/ && inSync && !/^\[state_sync\]/ {inSync=0; print}' \
  "$config" > tmp.toml && mv tmp.toml "$config"

echo "=== Configuring fast state-sync"
LATEST=$(curl -sSL "http://${RPC_SERVERS[0]}:${RPC_PORT}/status" \
           | jq -r '.result.sync_info.latest_block_height')
TRUST_HEIGHT=$((LATEST - STATE_SYNC_DELAY)); [ "$TRUST_HEIGHT" -lt 1 ] && TRUST_HEIGHT=1
TRUST_HASH=$(curl -sSL "http://${RPC_SERVERS[0]}:${RPC_PORT}/block?height=${TRUST_HEIGHT}" \
                | jq -r '.result.block_id.hash')

cat <<EOF >> "$config"

[state_sync]
enable = true
snapshot-interval = 1000
snapshot-keep-recent = 2
rpc_servers = "$(printf "http://%s:%d," "${RPC_SERVERS[@]}" "$RPC_PORT" | sed 's/,$//')"
trust_height = ${TRUST_HEIGHT}
trust_hash   = "${TRUST_HASH}"
trust_period = "168h0m0s"
EOF

####################################
# 🚀 Start node
####################################
echo "=== Starting wasmd (state & block sync)"
exec wasmd start --home "$HOME_DIR"
