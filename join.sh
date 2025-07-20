#!/usr/bin/env bash
set -euo pipefail

####################################
# 🖥️ Windows check — if running under Git Bash or Cygwin on Windows,
# re-invoke this same script inside WSL and exit
####################################
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "▶ Detected Windows (Git Bash/Cygwin); launching under WSL…"
    if ! wsl -l -q >/dev/null 2>&1 || [ -z "$(wsl -l -q)" ]; then
      echo "▶ No WSL distributions installed; attempting to install Ubuntu..."
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "wsl --install -d Ubuntu"
      echo "▶ Ubuntu install initiated. Please restart your terminal after WSL setup completes, then re-run this script."
      exit
    fi
    WSL_SCRIPT=$(wsl wslpath -u "$PWD/$0" | tr -d '\r')
    ARGS=("$@")
    CMD="\"$WSL_SCRIPT\""
    for a in "${ARGS[@]}"; do CMD+=" \"$a\""; done
    wsl bash -lc "$CMD"
    exit
    ;;
esac

####################################
# 📥 Parse options
####################################
BG=false
if [[ "${1-}" == "-bg" ]]; then
  BG=true
  shift
fi

####################################
# 📦 Install dependencies (only on Linux)
####################################
OS_NAME=$(uname -s)
if [[ "$OS_NAME" == "Linux" ]]; then
  echo "=== Installing system dependencies ==="
  sudo apt update && sudo apt install -y build-essential curl git jq
elif [[ "$OS_NAME" == "Darwin" ]]; then
  echo "▶ Detected macOS; skipping apt. Ensure deps via Homebrew: brew install git jq go"
else
  echo "▶ Detected $OS_NAME; skipping package install."
fi

####################################
# Install Go (version 1.21.6) on Linux, skip on macOS
####################################
if [[ "$OS_NAME" == "Linux" && ! $(command -v go || true) ]]; then
  echo "=== Installing Go ==="
  curl -OL https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOPATH/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
  echo 'export GOPATH=$HOME/go' >> ~/.bashrc
  echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
elif [[ "$OS_NAME" == "Darwin" && ! $(command -v go || true) ]]; then
  echo "❌ Go not found. Install with Homebrew: brew install go"
  exit 1
fi

echo "✅ Go version: $(go version)"

####################################
# ⬆️ Auto-patch & build wasmd with flora prefixes
####################################
REPO="$HOME/src/github.com/CosmWasm/wasmd"
echo "🔧 Cloning/building wasmd@v0.60.0 → flora…"
if [ -d "$REPO" ]; then
  pushd "$REPO" >/dev/null
  git fetch --all --tags && git reset --hard origin/main
else
  git clone https://github.com/CosmWasm/wasmd.git "$REPO"
  pushd "$REPO" >/dev/null
fi

git checkout tags/v0.60.0
# Patch Bech32 prefixes in app/app.go
sed -i.bak -E 's|^([[:space:]]*const Bech32Prefix = ).*|\1"flora"|' app/app.go
# Patch prefixes in cmd/wasmd/main.go
sed -i.bak -E \
  -e 's|^([[:space:]]*)SetBech32PrefixForAccount\(.*|\1SetBech32PrefixForAccount("flora","florapub")|' \
  -e 's|^([[:space:]]*)SetBech32PrefixForValidator\(.*|\1SetBech32PrefixForValidator("floravaloper","floravaloperpub")|' \
  -e 's|^([[:space:]]*)SetBech32PrefixForConsensusNode\(.*|\1SetBech32PrefixForConsensusNode("floravalcons","floravalconspub")|' \
  cmd/wasmd/main.go

GO_CMD=go
$GO_CMD install -mod=readonly -tags "netgo,ledger" \
  -ldflags "-X github.com/CosmWasm/wasmd/app.Bech32Prefix=flora -X github.com/cosmos/cosmos-sdk/version.AppName=wasmd \
-X github.com/cosmos/cosmos-sdk/version.Name=wasm -X github.com/cosmos/cosmos-sdk/version.Version=v0.60.0 \
-X github.com/cosmos/cosmos-sdk/version.Commit=$(git rev-parse HEAD)" \
  ./cmd/wasmd
popd
echo "✅ Built $(wasmd version --long | head -n1)"

####################################
# Create florachain helper
####################################
WRAPPER="$HOME/.local/bin/florachain"
mkdir -p "$(dirname "$WRAPPER")"
cat << 'EOF' > "$WRAPPER"
#!/usr/bin/env bash
set -euo pipefail
HOME_DIR="$HOME/florachain"
PID_FILE="$HOME_DIR/node.pid"
LOG_FILE="$HOME_DIR/node.log"
case "${1-}" in
  start)
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      echo "▶ Node already running (PID $(cat $PID_FILE))"
      exit 0
    fi
    echo "▶ Starting node..."
    nohup wasmd start --home "$HOME_DIR" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "▶ Node started with PID $(cat $PID_FILE)"
    ;;
  stop)
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      echo "▶ Stopping node..."
      kill $(cat "$PID_FILE")
      rm -f "$PID_FILE"
      echo "▶ Node stopped"
    else
      echo "▶ Node is not running"
    fi
    ;;
  status)
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      pid=$(cat "$PID_FILE")
      echo "▶ Node is running (PID $pid)"
      # Version
      version=$(wasmd version --home "$HOME_DIR" --output json 2>/dev/null | jq -r '.Version // .version // empty' 2>/dev/null)
      if [ -z "$version" ]; then
        version=$(wasmd version --home "$HOME_DIR" | head -n1)
      fi
      echo "  Version: $version"
      # Sync info via RPC
      if status_json=$(curl -s "http://${RPC_SERVERS[0]}:${RPC_PORT}/status"); then
        latest_height=$(jq -r '.result.sync_info.latest_block_height' <<< "$status_json")
        echo "  Network height: $latest_height"
      fi
      # Last local block from logs
      if [ -f "$LOG_FILE" ]; then
        local_height=$(grep -oE 'height=[0-9]+' "$LOG_FILE" | tail -1 | cut -d= -f2)
        echo "  Local height: $local_height"
        if [ -n "$latest_height" ]; then
          diff=$((latest_height - local_height))
          echo "  Blocks behind: $diff"
        fi
      fi
      # Tail of logs for quick preview
      echo "  Recent blocks from logs:"
      grep -E 'height=' "$LOG_FILE" | tail -3
    else
      echo "▶ Node is not running"
    fi
    ;;
  logs)
    echo "▶ Showing node logs (ctrl+C to exit)"
    tail -f "$LOG_FILE"
    ;;
  help|-h)
    echo "Usage: florachain <command>"; echo
    echo "Available commands:"; echo "  start   - Launch node in background";
    echo "  stop    - Stop the running node"; echo "  status  - Show node status";
    echo "  logs    - Tail node logs"; echo "  help    - Show this help message";
    ;;
  *)
    [ -n "${1-}" ] && echo "▶ Unknown command: $1"
    florachain help
    exit 1
    ;;
esac
EOF
chmod +x "$WRAPPER"
if [ -d /usr/local/bin ]; then
  if [ -w /usr/local/bin ]; then
    ln -sf "$WRAPPER" /usr/local/bin/florachain
  else
    sudo ln -sf "$WRAPPER" /usr/local/bin/florachain
  fi
fi

echo "✅ CLI helper installed at $WRAPPER"

####################################
# Verify remote wasmd versions
####################################
RPC_SERVERS=("testnet-gateway.metaflora.xyz" "testnet-seed1.metaflora.xyz" "testnet-seed2.metaflora.xyz")
RPC_PORT=26657

echo "=== Verifying remote wasmd versions ==="
for host in "${RPC_SERVERS[@]}"; do
  echo -n "$host: "
  curl -sSL "http://$host:$RPC_PORT/abci_info" | jq -r '.result.response.data + " (app ver: " + .result.response.version + ")"'
done
echo

####################################
# User init & config
####################################
if [ $# -lt 1 ]; then echo "Usage: $0 [-bg] <moniker>"; exit 1; fi
MONIKER="$1"
HOME_DIR="$HOME/florachain"
P2P_PORT=26656
STATE_SYNC_DELAY=1000

echo "=== Reset state & init ==="
rm -rf "$HOME_DIR"
wasmd init "$MONIKER" --chain-id "flora-1" --home "$HOME_DIR" --overwrite

sed -i.bak 's|^keyring-backend *=.*|keyring-backend = "test"|' "$HOME_DIR/config/client.toml"
sed -i.bak 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025uflora"|' "$HOME_DIR/config/app.toml"

####################################
# Fetch genesis and configure state-sync
####################################
GENESIS_URL="http://${RPC_SERVERS[0]}:${RPC_PORT}/genesis"
echo "=== Fetching genesis from $GENESIS_URL"
curl -sSL "$GENESIS_URL" | jq -r '.result.genesis' > "$HOME_DIR/config/genesis.json"
if ! jq -e '.chain_id' "$HOME_DIR/config/genesis.json" >/dev/null; then
  echo "❌ error: genesis.json missing chain_id"
  exit 1
fi

tmp="$HOME_DIR/config/genesis.json.tmp"
jq '.consensus_params.block.time_iota_ms="1000"' "$HOME_DIR/config/genesis.json" > "$tmp" && mv "$tmp" "$HOME_DIR/config/genesis.json"

config="$HOME_DIR/config/config.toml"
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

awk '!inSync {print} /^\[state_sync\]/ {inSync=1} /^\[.*\]/ && inSync && !/^\[state_sync\]/ {inSync=0; print}' "$config" > tmp.toml && mv tmp.toml "$config"

echo "=== Configuring fast state-sync"
LATEST=$(curl -sSL "http://${RPC_SERVERS[0]}:${RPC_PORT}/status" | jq -r '.result.sync_info.latest_block_height')
TRUST_HEIGHT=$((LATEST - STATE_SYNC_DELAY)); [ "$TRUST_HEIGHT" -lt 1 ] && TRUST_HEIGHT=1
TRUST_HASH=$(curl -sSL "http://${RPC_SERVERS[0]}:${RPC_PORT}/block?height=${TRUST_HEIGHT}" | jq -r '.result.block_id.hash')
rpc_list=()
for host in "${RPC_SERVERS[@]}"; do rpc_list+=("http://${host}:${RPC_PORT}"); done
RPC_SERVERS_CSV=$(IFS=,; echo "${rpc_list[*]}")
cat <<EOF >> "$config"

[state_sync]
enable = true
snapshot-interval = 1000
snapshot-keep-recent = 2
rpc_servers = "$RPC_SERVERS_CSV"
trust_height = ${TRUST_HEIGHT}
trust_hash   = "$TRUST_HASH"
trust_period = "168h0m0s"
EOF

####################################
# 🚀 Start node
####################################
echo "=== Starting wasmd (state & block sync)"
if [ "$BG" = true ]; then
  echo "▶ Launching node in background via 'florachain start'. Logs: $HOME_DIR/node.log"
  florachain start
  echo
  florachain help
  exit 0
else
  exec wasmd start --home "$HOME_DIR"
fi
