#!/bin/bash
# network/scripts/remove-channel.sh
# Permanently removes an application channel from the Ordering Service.
# This script uses the osnadmin tool via the CLI container.

set -e

CHANNEL_NAME=$1
if [ -z "$CHANNEL_NAME" ]; then
    echo "Usage: ./network/scripts/remove-channel.sh <channel_name>"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "🚮 [CHANNEL] Initiating removal of channel: ${CHANNEL_NAME}..."

# 1. Unregister channel from all Orderer nodes
echo "🗳️ Step 1: Removing channel from Orderer(s) via osnadmin..."

# We discover orderers via their directories in the mount
ORDERER_FOUND=false
for ord_dir in "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers"/*; do
    [ -d "$ord_dir" ] || continue
    ORD_NAME=$(basename "$ord_dir")
    ORDERER_FOUND=true
    
    echo "   Removing from ${ORD_NAME} on port 7053 (internal)..."
    docker exec cli osnadmin channel remove --channelID "${CHANNEL_NAME}" \
      -o "${ORD_NAME}:7053" \
      --ca-file "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" \
      --client-cert "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt" \
      --client-key "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"
done

if [ "$ORDERER_FOUND" = false ]; then
    echo "❌ Error: No orderer nodes found in the organizations directory."
    exit 1
fi

# 2. Update Registries
echo "📝 Updating channel registries..."
HISTORY_FILE="${NETWORK_DIR}/../docs/logs/channel_index.history"
RETIRED_LIST="${NETWORK_DIR}/../docs/logs/retired_channels.list"
mkdir -p "$(dirname "$HISTORY_FILE")"

# Move from History to Retired
if [ -f "$HISTORY_FILE" ]; then
    sed -i "/^${CHANNEL_NAME}$/d" "$HISTORY_FILE"
fi
echo "${CHANNEL_NAME}" >> "$RETIRED_LIST"

# 3. Cleanup local artifacts
echo "🧹 Step 2: Cleaning up local channel artifacts..."
rm -f "${NETWORK_DIR}/channel-artifacts/${CHANNEL_NAME}.block"
rm -f "${NETWORK_DIR}/channel-artifacts/${CHANNEL_NAME}.json"
rm -f "${NETWORK_DIR}/channel-artifacts/config_block.pb"
rm -f "${NETWORK_DIR}/channel-artifacts/config.json"
rm -f "${NETWORK_DIR}/channel-artifacts/modified_config.json"
rm -f "${NETWORK_DIR}/channel-artifacts/update_in_envelope.pb"

echo "✅ [SUCCESS] Channel '${CHANNEL_NAME}' has been removed from the Ordering Service."
echo "📍 Note: Peer ledger data for this channel still exists within peer volumes."
