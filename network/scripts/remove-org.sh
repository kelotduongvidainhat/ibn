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
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True
BIN_DIR="${NETWORK_DIR}/../bin"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"
export PATH="${BIN_DIR}:${PATH}"
RETIRED_LIST="${NETWORK_DIR}/../docs/logs/retired_orgs.list"
mkdir -p "$(dirname "$RETIRED_LIST")"

echo "🔥 [ADMIN] Initiating permanent removal of ${ORG_NAME}..."

# 1. Update Channel Configurations (Discovery & Loop)
echo "📝 Step 1: Scanning all channels for ${MSP_ID}..."

# Discover all channels the network is participating in
CHANNELS=$(docker exec cli peer channel list | grep -v "Channels peers has joined" | grep -v "listing channels:" | xargs)

if [ -z "$CHANNELS" ]; then
    echo "⚠️  No active channels detected. Proceeding to infrastructure cleanup."
else
    # Discovery & Safety Scan
    echo "🔍 Found channels: $CHANNELS"
    for CH in $CHANNELS; do
        # Fetch the config block to verify presence and state
        docker exec \
          -e CORE_PEER_LOCALMSPID="Org1MSP" \
          -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
          cli peer channel fetch config "channel-artifacts/config_checker.pb" -o orderer.example.com:7050 -c "${CH}" --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt > /dev/null 2>&1 || continue

        CONFIG_JSON="${ARTIFACTS_DIR}/temp_config.json"
        docker exec cli configtxlator proto_decode --input channel-artifacts/config_checker.pb --type common.Block | jq .data.data[0].payload.data.config > "$CONFIG_JSON"

        HAS_ORG=$(jq -r ".channel_group.groups.Application.groups | has(\"$MSP_ID\")" "$CONFIG_JSON")
        if [ "$HAS_ORG" == "true" ]; then
            IS_FROZEN=$(jq -r ".channel_group.groups.Application.groups.\"$MSP_ID\".policies.Admins.policy.value.identities[0].principal.msp_identifier" "$CONFIG_JSON")
            if [ "$IS_FROZEN" != "ForbiddenMSP" ]; then
                echo "❌ ATOMICITY FAIL: Organization '$MSP_ID' is NOT frozen in channel '${CH}'."
                echo "Aborting removal. All channels must be frozen before permanent excision."
                exit 2
            fi
            CHANNELS_TO_CLEAN="$CHANNELS_TO_CLEAN $CH"
        fi
    done

    # Removal Loop
    for CH in $CHANNELS_TO_CLEAN; do
        echo "--- Execising from Channel: ${CH} ---"

        # Remove from channel
        echo "   Generating removal transaction for ${CH}..."
        docker exec \
          -e CORE_PEER_LOCALMSPID="Org1MSP" \
          -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
          cli /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/internal_config_remove.sh "${CH}" "${MSP_ID}"

        # Collecting consortium signatures
        for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
            [ -d "$org_dir" ] || continue
            EXISTING_ORG_DOMAIN=$(basename "$org_dir")
            if [ "$EXISTING_ORG_DOMAIN" == "$DOMAIN" ]; then continue; fi
            
            EXISTING_ORG_NUM=$(echo $EXISTING_ORG_DOMAIN | grep -o '[0-9]\+')
            EXISTING_MSP_ID="Org${EXISTING_ORG_NUM}MSP"
            
            echo "   Signing with ${EXISTING_MSP_ID}..."
            docker exec \
              -e CORE_PEER_LOCALMSPID="${EXISTING_MSP_ID}" \
              -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${EXISTING_ORG_DOMAIN}/users/Admin@${EXISTING_ORG_DOMAIN}/msp" \
              cli peer channel signconfigtx -f update_in_envelope.pb
        done

        echo "   Submitting removal to orderer..."
        docker exec \
          -e CORE_PEER_LOCALMSPID="Org1MSP" \
          -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
          cli peer channel update -f update_in_envelope.pb -c "${CH}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
    done
fi

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

# 3.2 Clean Modular Docker Config
    compose_module = '${NETWORK_DIR}/compose/docker-compose-org${ORG_NUM}.yaml'
    if os.path.exists(compose_module):
        print(f"🐳 Removing modular infrastructure for Org${ORG_NUM}")
        # We handle the 'docker down' outside python for simplicity
        pass 
    
    # 3.3 Legacy docker-compose.yaml cleanup (optional, for safety)
    compose_path = '${NETWORK_DIR}/docker-compose.yaml'
    if os.path.exists(compose_path):
        with open(compose_path, 'r') as f:
            data = yaml.safe_load(f)
        ca_svc = 'ca_${ORG_NAME}'
        if ca_svc in data.get('services', {}): del data['services'][ca_svc]
        peer_vol = 'peer0.${DOMAIN}'
        if peer_vol in data.get('volumes', {}): del data['volumes'][peer_vol]
        with open(compose_path, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# Stop and remove modular services if file exists
COMPOSE_MODULE="${NETWORK_DIR}/compose/docker-compose-org${ORG_NUM}.yaml"
if [ -f "$COMPOSE_MODULE" ]; then
    echo "🐳 Stopping and wiping ${ORG_NAME} containers and volumes..."
    docker compose -f "$COMPOSE_MODULE" down --volumes || true
    rm "$COMPOSE_MODULE"
fi

# 4. Filesystem Cleanup
echo "📂 Step 4: Deleting cryptographic material..."
sudo rm -rf "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}"
sudo rm -rf "${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"

LIFECYCLE_LOG="${NETWORK_DIR}/../docs/logs/org_lifecycle.log"
mkdir -p "$(dirname "$LIFECYCLE_LOG")"
echo "[$(date)] Permanently removed ${MSP_ID} from the consortium." >> "$LIFECYCLE_LOG"
echo "${MSP_ID}" >> "${RETIRED_LIST}"

# 5. Refresh SDK Connection Profiles
echo "📇 Step 5: Refreshing connection profiles..."
"${SCRIPTS_DIR}/profile-gen.sh"

echo "✅ [SUCCESS] ${ORG_NAME} has been permanently excised from the consortium."
