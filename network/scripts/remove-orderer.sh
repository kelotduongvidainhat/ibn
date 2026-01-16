#!/bin/bash
# network/scripts/remove-orderer.sh
# Safely removes an Orderer node from the Raft cluster and cleans up infrastructure.

set -e

ORDERER_NUM=$1
CHANNEL_NAME=${2:-mychannel}

# Auto-Determine Highest Orderer ID if not provided
# ORDERER_COMPOSE is defined later, so we need to define it here for this block
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORDERER_COMPOSE="${NETWORK_DIR}/compose/docker-compose-orderers.yaml"

if [ -z "$ORDERER_NUM" ]; then
    echo "🔍 No ID provided, scanning for highest orderer ID..."
    if [ -f "$ORDERER_COMPOSE" ]; then
        # Extract numbers from container_name: ordererX, sort numerically in reverse, take the first (highest)
        ORDERER_NUM=$(grep "container_name: orderer" "$ORDERER_COMPOSE" | grep -o "[0-9]\+" | sort -nr | head -n 1)
    fi
    if [ -z "$ORDERER_NUM" ] || [ "$ORDERER_NUM" -le 1 ]; then
        echo "❌ No removable orderers found (Orderer 1 is protected)."
        exit 1
    fi
    echo "📍 Automatically selected Orderer ${ORDERER_NUM} for removal."
fi

# Check Orderer 1 protection

if [ "$ORDERER_NUM" -eq 1 ]; then
    echo "Usage: ./network/scripts/remove-orderer.sh <orderer_num> [channel_name]"
    echo "Example: ./network/scripts/remove-orderer.sh 2 mychannel"
    echo "Note: Orderer 1 cannot be removed as it is the bootstrap node."
    exit 1
fi

ORDERER_NAME="orderer${ORDERER_NUM}"
ORDERER_HOST="${ORDERER_NAME}.example.com"
# NETWORK_DIR was already defined above for the auto-detection block
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"
ORDERER_COMPOSE="${NETWORK_DIR}/compose/docker-compose-orderers.yaml"
# Ensure permissions are correct for artifacts
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"
sudo chown -R $(id -u):$(id -g) "${ARTIFACTS_DIR}" || true

echo "🔥 [ORDERER] Initiating removal of ${ORDERER_HOST}..."

# 1. Quorum Check
echo "🔍 Checking cluster quorum..."
# We fetch config from orderer1 (node 1) as it is the stay-behind node
docker exec \
  -e CORE_PEER_LOCALMSPID="OrdererMSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp \
  cli peer channel fetch config channel-artifacts/config_block.pb -o orderer.example.com:7050 -c "${CHANNEL_NAME}" --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

configtxlator proto_decode --input "${ARTIFACTS_DIR}/config_block.pb" --type common.Block | jq .data.data[0].payload.data.config > "${ARTIFACTS_DIR}/config.json"

TOTAL_NODES=$(jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters | length' "${ARTIFACTS_DIR}/config.json")
echo "Current Cluster Size: ${TOTAL_NODES}"

if [ "$TOTAL_NODES" -le 3 ]; then
    echo "⚠️  WARNING: Removing this node will leave only $((TOTAL_NODES - 1)) nodes."
    echo "   A 2-node cluster has NO fault tolerance in Raft."
    read -p "Continue anyway? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then exit 1; fi
fi

# 2. Update Channel Configuration
echo "📝 Step 2: Removing ${ORDERER_HOST} from channel metadata..."

# Remove from OrdererAddresses
jq "del(.channel_group.values.OrdererAddresses.value.addresses[] | select(. == \"${ORDERER_HOST}:$((7050 + (ORDERER_NUM-1)*100))\"))" "${ARTIFACTS_DIR}/config.json" > "${ARTIFACTS_DIR}/config_tmp.json"

# Remove from Raft Consenters
jq "del(.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[] | select(.host == \"${ORDERER_HOST}\"))" "${ARTIFACTS_DIR}/config_tmp.json" > "${ARTIFACTS_DIR}/modified_config.json"

# Compute Delta
configtxlator proto_encode --input "${ARTIFACTS_DIR}/config.json" --type common.Config > "${ARTIFACTS_DIR}/config.pb"
configtxlator proto_encode --input "${ARTIFACTS_DIR}/modified_config.json" --type common.Config > "${ARTIFACTS_DIR}/modified_config.pb"
configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original "${ARTIFACTS_DIR}/config.pb" --updated "${ARTIFACTS_DIR}/modified_config.pb" > "${ARTIFACTS_DIR}/config_update.pb"

# Wrap in Envelope
docker exec cli configtxlator proto_decode --input /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/config_update.pb --type common.ConfigUpdate > "${ARTIFACTS_DIR}/config_update.json"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat "${ARTIFACTS_DIR}/config_update.json")'}}}' > "${ARTIFACTS_DIR}/config_update_as_envelope.json"
docker exec cli configtxlator proto_encode --input /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/config_update_as_envelope.json --type common.Envelope > "${ARTIFACTS_DIR}/update_in_envelope.pb"

echo "🗳️  Submitting removal transaction..."
docker exec \
  -e CORE_PEER_LOCALMSPID="OrdererMSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp \
  cli peer channel update -f channel-artifacts/update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

# 3. Cleanup Infrastructure
echo "🧹 Step 3: Wiping Docker resources..."
if [ -f "$ORDERER_COMPOSE" ]; then
    docker compose -f "$ORDERER_COMPOSE" stop "${ORDERER_HOST}" || true
    docker compose -f "$ORDERER_COMPOSE" rm -f "${ORDERER_HOST}" || true
    
    # Remove from modular compose via Python
    python3 <<EOF
import yaml
file_path = '${ORDERER_COMPOSE}'
host = '${ORDERER_HOST}'
with open(file_path, 'r') as f:
    data = yaml.safe_load(f)
if host in data.get('services', {}):
    del data['services'][host]
if host in data.get('volumes', {}):
    del data['volumes'][host]
with open(file_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF
fi

# 4. Filesystem Cleanup
echo "📂 Step 4: Deleting cryptographic material..."
sudo rm -rf "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/${ORDERER_HOST}"

LIFECYCLE_LOG="${NETWORK_DIR}/../docs/logs/org_lifecycle.log"
echo "[$(date)] Permanently removed Orderer ${ORDERER_HOST} from the cluster." >> "$LIFECYCLE_LOG"

echo "✅ [SUCCESS] ${ORDERER_HOST} has been removed from the consortium."
