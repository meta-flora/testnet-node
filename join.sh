#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <moniker>"
  exit 1
fi

####################################
# 👤 User settings
####################################
MONIKER="$1"
CHAIN_ID="flora-1"
HOME_DIR="$HOME/florachain"
DNS_SEED="testnet-gateway.metaflora.xyz"
P2P_PORT=26656
RPC_PORT=26657        # Tendermint RPC for state-sync & status
REST_PORT=1317       # REST API on your gateway
GENESIS_URL="http://${DNS_SEED}:${RPC_PORT}/genesis"
RPC_URL="http://${DNS_SEED}:${RPC_PORT}"
STATE_SYNC_DELAY=1000

####################################
# 🧹 1) Clean slate
####################################
echo "=== Cleaning old state at $HOME_DIR"
rm -rf "$HOME_DIR"

####################################
# 🛠 2) Initialize
####################################
echo "=== wasmd init $MONIKER"
wasmd init "$MONIKER" \
  --chain-id "$CHAIN_ID" \
  --home "$HOME_DIR" \
  --overwrite

####################################
# 🔑 3) keyring-backend=test
####################################
echo "=== Setting keyring-backend=test"
sed -i.bak 's|^keyring-backend *=.*|keyring-backend = "test"|' \
  "$HOME_DIR/config/client.toml"

####################################
# 📥 4) Fetch genesis
####################################
echo "=== Downloading genesis from $GENESIS_URL"
curl -sSL "$GENESIS_URL" \
  | jq -r '.result.genesis' \
  > "$HOME_DIR/config/genesis.json"

####################################
# 🔗 5) P2P / PEX config
####################################
echo "=== Disabling seeds, enabling PEX"
CFG="$HOME_DIR/config/config.toml"
sed -i.bak \
  -e 's|^seeds *=.*|seeds = ""|' \
  -e 's|^persistent_peers *=.*|persistent_peers = ""|' \
  -e 's|^pex *=.*|pex = true|' \
  -e 's|^seed_mode *=.*|seed_mode = false|' \
  "$CFG"

####################################
# ⏩ 6) Fast state-sync
####################################
echo "=== Configuring state-sync (delay = ${STATE_SYNC_DELAY})"
LATEST_HEIGHT=$(curl -sSL "${RPC_URL}/status" | jq -r '.result.sync_info.latest_block_height')
TRUST_HEIGHT=$((LATEST_HEIGHT - STATE_SYNC_DELAY))
[ "$TRUST_HEIGHT" -lt 1 ] && TRUST_HEIGHT=1

TRUST_HASH=$(curl -sSL "${RPC_URL}/block?height=${TRUST_HEIGHT}" \
  | jq -r '.result.block_id.hash')

cat <<EOF >> "$CFG"

[state_sync]
trust_height = ${TRUST_HEIGHT}
trust_hash   = "${TRUST_HASH}"
rpc_servers  = "${RPC_URL},${RPC_URL}"
EOF

####################################
# 🌐 7) Bootstrap off DNS seed
####################################
echo "=== Fetching bootstrap node ID from ${RPC_URL}"
BOOT_ID=$(curl -sSL "${RPC_URL}/status" | jq -r '.result.node_info.id')
if [[ -z "$BOOT_ID" || "$BOOT_ID" == "null" ]]; then
  echo "✗ ERROR: Could not fetch bootstrap node ID"
  exit 1
fi

echo ">>> Using bootstrap peer: ${BOOT_ID}@${DNS_SEED}:${P2P_PORT}"
sed -i.bak "s|^persistent_peers *=.*|persistent_peers = \"${BOOT_ID}@${DNS_SEED}:${P2P_PORT}\"|" \
  "$CFG"

####################################
# 🚀 8) Start your node
####################################
echo "=== Starting wasmd..."
exec wasmd start --home "$HOME_DIR"
