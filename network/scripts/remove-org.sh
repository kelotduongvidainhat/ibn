#!/bin/bash
# network/scripts/remove-org.sh
# Orchestrates the permanent removal of an organization from the consortium.

set -e

ORG_NUM=$1
CHANNEL_NAME=${2:-mychannel}

if [ -z "$ORG_NUM" ]; then
    echo "Usage: ./network/scripts/remove-org.sh <org_num> [channel_name]"
    echo "Example: ./network/scripts/remove-org.sh 2 mychannel"
    exit 1
fi

ORG_NAME="org${ORG_NUM}"
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"
export PATH="${BIN_DIR}:${PATH}"

echo "🔥 [ADMIN] Initiating permanent removal of ${ORG_NAME}..."

# 1. Update Channel Configuration
echo "📝 Step 1: Removing from channel ledger..."

# Fetch the config block
echo "📦 Fetching the latest configuration block..."
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  cli peer channel fetch config "channel-artifacts/config_block.pb" -o orderer.example.com:7050 -c "${CHANNEL_NAME}" --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

CONFIG_BLOCK="${ARTIFACTS_DIR}/config_block.pb"
CONFIG_JSON="${ARTIFACTS_DIR}/config.json"

echo "🔓 Decoding config block..."
configtxlator proto_decode --input $CONFIG_BLOCK --type common.Block | jq .data.data[0].payload.data.config > $CONFIG_JSON

# --- SAFETY CHECK ---
echo "⚙️  Verifying organization state..."
IS_FROZEN=$(jq -r ".channel_group.groups.Application.groups.\"$MSP_ID\".policies.Admins.policy.value.identities[0].principal.msp_identifier" $CONFIG_JSON)

if [ "$IS_FROZEN" != "ForbiddenMSP" ]; then
    echo "❌ SAFETY FAIL: Organization '$MSP_ID' is NOT frozen."
    echo "Administrators must run './network/scripts/freeze-org.sh' before permanent removal."
    exit 2
fi
# --------------------

echo "🗑️ Removing $MSP_ID from Application group..."
set +e
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  cli /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/internal_config_remove.sh "${CHANNEL_NAME}" "${MSP_ID}"
RESULT=$?
set -e

if [ $RESULT -eq 2 ]; then
    echo "--------------------------------------------------------------------------------"
    echo "❌ ABORTED: Permanent removal is restricted for ACTIVE organizations."
    echo "Two-Step Protocol required:"
    echo "  1. Run: ./network/scripts/freeze-org.sh ${ORG_NUM}"
    echo "  2. Run: ./network/scripts/remove-org.sh ${ORG_NUM}"
    echo "--------------------------------------------------------------------------------"
    exit 1
elif [ $RESULT -ne 0 ]; then
    echo "❌ ERROR: Failed to prepare removal transaction."
    exit 1
fi

echo "✍️  Collecting consortium signatures..."
for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
    [ -d "$org_dir" ] || continue
    EXISTING_ORG_DOMAIN=$(basename "$org_dir")
    
    # Skip the one being removed if it's already frozen/unhappy, 
    # but we usually need majority of REMAINING to sign.
    if [ "$EXISTING_ORG_DOMAIN" == "$DOMAIN" ]; then
        continue
    fi
    
    EXISTING_ORG_NUM=$(echo $EXISTING_ORG_DOMAIN | grep -o '[0-9]\+')
    EXISTING_MSP_ID="Org${EXISTING_ORG_NUM}MSP"
    
    echo "Signing with ${EXISTING_MSP_ID}..."
    docker exec \
      -e CORE_PEER_LOCALMSPID="${EXISTING_MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${EXISTING_ORG_DOMAIN}/users/Admin@${EXISTING_ORG_DOMAIN}/msp" \
      cli peer channel signconfigtx -f update_in_envelope.pb
done

echo "🗳️  Submitting removal transaction to Orderer..."
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer channel update -f update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

# 2. Cleanup Infrastructure
echo "🧹 Step 2: Cleaning up infrastructure..."
docker stop "peer0.${DOMAIN}" "ca_${ORG_NAME}" "couchdb.peer0.${DOMAIN}" || true
docker rm "peer0.${DOMAIN}" "ca_${ORG_NAME}" "couchdb.peer0.${DOMAIN}" || true
docker volume rm "network_peer0.${DOMAIN}" || true

# 3. Patch Configuration Files
echo "📝 Step 3: Patching project files..."
python3 <<EOF
import yaml
import os

# 3.1 Clean configtx.yaml
config_path = '${NETWORK_DIR}/configtx.yaml'
if os.path.exists(config_path):
    with open(config_path, 'r') as f:
        data = yaml.safe_load(f)
    if 'Organizations' in data:
        data['Organizations'] = [o for o in data['Organizations'] if o.get('Name') != '${MSP_ID}']
        with open(config_path, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)

# 3.2 Clean docker-compose.yaml
compose_path = '${NETWORK_DIR}/docker-compose.yaml'
if os.path.exists(compose_path):
    with open(compose_path, 'r') as f:
        data = yaml.safe_load(f)
    
    ca_svc = 'ca_${ORG_NAME}'
    if ca_svc in data.get('services', {}):
        del data['services'][ca_svc]
    
    peer_vol = 'peer0.${DOMAIN}'
    if peer_vol in data.get('volumes', {}):
        del data['volumes'][peer_vol]
        
    with open(compose_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# 4. Filesystem Cleanup
echo "📂 Step 4: Deleting cryptographic material..."
sudo rm -rf "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}"
sudo rm -rf "${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"

LIFECYCLE_LOG="${NETWORK_DIR}/../docs/logs/org_lifecycle.log"
mkdir -p "$(dirname "$LIFECYCLE_LOG")"
echo "[$(date)] Permanently removed ${MSP_ID} from the channel." >> "$LIFECYCLE_LOG"

echo "✅ [SUCCESS] ${ORG_NAME} has been permanently excised from the consortium."
