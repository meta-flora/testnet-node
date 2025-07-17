# Flora Testnet Node Bootstrap

This repository contains a single script, `join.sh`, to quickly bootstrap a full node on the **flora-1** testnet using PEX + state-sync.

## Usage

```bash
git clone https://github.com/meta-flora/testnet-node.git
cd testnet-node
chmod +x join.sh
./join.sh <MONIKER>
````

## Join Network with 1 line

You can join the Flora testnet in one command:

```bash
curl -sSL https://raw.githubusercontent.com/meta-flora/testnet-node/main/join.sh \
  | bash -s -- <your-moniker>
  ```

* **MONIKER** (optional) — your node’s name (defaults to `floranode`)

## What it does

1. Installs `wasmd` v0.60.1 if missing
2. Removes any old chain data
3. Initializes home folder and downloads genesis via RPC
4. Enables Peer-Exchange (PEX) and bootstraps off DNS seed
5. Configures state-sync from a safe trust height
6. Starts `wasmd` with state-sync enabled

## Configuration

You can edit the top of `join.sh` to customize:

* `CHAIN_ID` (should remain `flora-1`)
* `DNS_SEED` (default: `testnet-gateway.metaflora.xyz`)
* `RPC_PORT` (default: `26657`)
* `STATE_SYNC_DELAY` (blocks to offset for trust height)

---

Let It Grow! 🚀
