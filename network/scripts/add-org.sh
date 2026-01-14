#!/bin/bash
# network/scripts/add-org.sh
# Automates Phase 1-5 for adding a new Organization to the network.

set -e

CHANNEL_NAME=${1:-mychannel}
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export COMPOSE_PROJECT_NAME=fabric
DOCS_LOG_DIR="${NETWORK_DIR}/../docs/logs"
mkdir -p "${DOCS_LOG_DIR}"

# 1. Setup Logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${DOCS_LOG_DIR}/add-org_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--------------------------------------------------------------------------------"
echo "🚀 [AUTOMATION] Execution started at: $(date)"
echo "--------------------------------------------------------------------------------"

# 2. Auto-Determine Next ORG_NUM
HISTORY_FILE="${DOCS_LOG_DIR}/org_index.history"
LAST_ID=0
if [ -f "$HISTORY_FILE" ]; then
    LAST_ID=$(tail -n 1 "$HISTORY_FILE" | grep -o "[0-9]\+")
fi

# Scan configtx.yaml for highest existing ID to prevent collisions
MAX_CONFIG_ID=$(grep -o "Org[0-9]\+MSP" "${NETWORK_DIR}/configtx.yaml" | grep -o "[0-9]\+" | sort -nr | head -n 1 || echo 0)

# Scan filesystem for legacy folders
MAX_FS_ID=$(ls "${NETWORK_DIR}/organizations/peerOrganizations" 2>/dev/null | grep -o "[0-9]\+" | sort -nr | head -n 1 || echo 0)

# The next ID is the max of all known sources + 1
ORG_NUM=$(( (MAX_CONFIG_ID > LAST_ID ? MAX_CONFIG_ID : LAST_ID) ))
ORG_NUM=$(( (MAX_FS_ID > ORG_NUM ? MAX_FS_ID : ORG_NUM) + 1 ))

ORG_NAME="org${ORG_NUM}"
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"
BIN_DIR="${NETWORK_DIR}/../bin"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"
export PATH="${BIN_DIR}:${PATH}"

echo "📍 Assigned New Organization ID: ${ORG_NUM} (${MSP_ID})"

# 3. Persist ID reservation
echo "${ORG_NUM}" >> "$HISTORY_FILE"
echo "[$(date)] Reserving ${MSP_ID} for provisioning..." >> "${DOCS_LOG_DIR}/org_lifecycle.log"

# 1. Update configtx.yaml (Future proofing)
echo "📝 Patching configtx.yaml..."
python3 <<EOF
import yaml
config_path = '${NETWORK_DIR}/configtx.yaml'
with open(config_path, 'r') as f:
    data = yaml.safe_load(f)

org_num = '${ORG_NUM}'
msp_id = '${MSP_ID}'
org_name = '${ORG_NAME}'
domain = '${DOMAIN}'

org_def = {
    'Name': msp_id,
    'ID': msp_id,
    'MSPDir': f'organizations/peerOrganizations/{domain}/msp',
    'Policies': {
        'Readers': {'Type': 'Signature', 'Rule': f"OR('{msp_id}.admin', '{msp_id}.peer', '{msp_id}.client')"},
        'Writers': {'Type': 'Signature', 'Rule': f"OR('{msp_id}.admin', '{msp_id}.client')"},
        'Admins': {'Type': 'Signature', 'Rule': f"OR('{msp_id}.admin')"},
        'Endorsement': {'Type': 'Signature', 'Rule': f"OR('{msp_id}.peer')"}
    },
    'AnchorPeers': [{'Host': f'peer0.{domain}', 'Port': 7051}]
}

# Add to Organizations list if not already there
if not any(o.get('Name') == msp_id for o in data['Organizations']):
    data['Organizations'].append(org_def)

with open(config_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# 2. Update Modular Docker Config
echo "🐳 Generating modular docker-compose-org${ORG_NUM}.yaml..."

# Port Calculation Logic
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then CA_PORT=10054; elif [ $CA_PORT -ge 10054 ]; then CA_PORT=$((CA_PORT+1000)); fi
CA_OPS_PORT=$((10000 + CA_PORT))

PEER_PORT=$((7051 + (ORG_NUM-1)*1000))
PEER_OPS_PORT=$((9443 + (ORG_NUM-1)*1000))
COUCH_PORT=$((5984 + (ORG_NUM-1)*1000))

cat > "${NETWORK_DIR}/compose/docker-compose-org${ORG_NUM}.yaml" <<EOF
version: '3.7'
networks:
  test:
    name: fabric_test
services:
  ca_${ORG_NAME}:
    image: hyperledger/fabric-ca:1.5.15
    container_name: ca_${ORG_NAME}
    environment:
    - FABRIC_CA_SERVER_CA_NAME=ca-${ORG_NAME}
    - FABRIC_CA_SERVER_TLS_ENABLED=true
    - FABRIC_CA_SERVER_PORT=7054
    - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:17054
    - FABRIC_CA_SERVER_CA_BOOTSTRAP_ENTRIES=admin:adminpw
    ports:
    - ${CA_PORT}:7054
    - ${CA_OPS_PORT}:17054
    volumes:
    - ../organizations/fabric-ca/${ORG_NAME}:/etc/hyperledger/fabric-ca-server
    networks:
    - test

  couchdb.peer0.${DOMAIN}:
    container_name: couchdb.peer0.${DOMAIN}
    image: couchdb:3.3.2
    environment:
    - COUCHDB_USER=admin
    - COUCHDB_PASSWORD=adminpw
    ports:
    - ${COUCH_PORT}:5984
    networks:
    - test

  peer0.${DOMAIN}:
    container_name: peer0.${DOMAIN}
    image: hyperledger/fabric-peer:2.5.14
    environment:
    - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
    - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_test
    - FABRIC_LOGGING_SPEC=INFO
    - CORE_PEER_TLS_ENABLED=true
    - CORE_PEER_PROFILE_ENABLED=true
    - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
    - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
    - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
    - CORE_PEER_ID=peer0.${DOMAIN}
    - CORE_PEER_ADDRESS=peer0.${DOMAIN}:7051
    - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
    - CORE_PEER_CHAINCODEADDRESS=peer0.${DOMAIN}:7052
    - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
    - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051
    - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${DOMAIN}:7051
    - CORE_PEER_LOCALMSPID=${MSP_ID}
    - CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:9443
    - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
    - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb.peer0.${DOMAIN}:5984
    - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
    - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
    - CORE_PEER_CHAINCODE_EXTERNALBUILDERS=[{"name":"ccaas-builder","path":"/opt/hyperledger/builders/ccaas"}]
    volumes:
    - /var/run/docker.sock:/host/var/run/docker.sock
    - ../organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/msp:/etc/hyperledger/fabric/msp
    - ../organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls:/etc/hyperledger/fabric/tls
    - ../../builders/ccaas:/opt/hyperledger/builders/ccaas
    - peer0.${DOMAIN}:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
    - ${PEER_PORT}:7051
    - ${PEER_OPS_PORT}:9443
    depends_on:
    - couchdb.peer0.${DOMAIN}
    networks:
    - test

volumes:
  peer0.${DOMAIN}:
EOF

# 3. Start CA and Bootstrap Identities
echo "🏗️ Starting CA for ${ORG_NAME}..."
docker compose -f "${NETWORK_DIR}/compose/docker-compose-org${ORG_NUM}.yaml" up -d "ca_${ORG_NAME}"
sleep 3
sudo chown -R $(id -u):$(id -g) "${NETWORK_DIR}/organizations"

export FABRIC_CA_CLIENT_HOME="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"
ORG_ROOT_CERT="${FABRIC_CA_CLIENT_HOME}/ca-cert.pem"
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then CA_PORT=10054; elif [ $CA_PORT -ge 10054 ]; then CA_PORT=$((CA_PORT+1000)); fi

echo "🔑 Enrolling identities..."
# Enroll bootstrap admin
fabric-ca-client enroll -u https://admin:adminpw@localhost:${CA_PORT} --caname "ca-${ORG_NAME}" --tls.certfiles "${ORG_ROOT_CERT}"

# Register Identities (Ignore error if already registered)
set +e
fabric-ca-client register --caname "ca-${ORG_NAME}" --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${ORG_ROOT_CERT}"
fabric-ca-client register --caname "ca-${ORG_NAME}" --id.name "orgadmin" --id.secret adminpw --id.type admin --tls.certfiles "${ORG_ROOT_CERT}"
set -e

# MSP Folder for Org
ORG_MSP="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/msp"
mkdir -p "${ORG_MSP}/cacerts" "${ORG_MSP}/tlscacerts"
cp "${ORG_ROOT_CERT}" "${ORG_MSP}/cacerts/ca.crt"
cp "${ORG_ROOT_CERT}" "${ORG_MSP}/tlscacerts/ca.crt"

# Admin MSP
ADMIN_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp"
mkdir -p "${ADMIN_DIR}"
fabric-ca-client enroll -u https://orgadmin:adminpw@localhost:${CA_PORT} --caname "ca-${ORG_NAME}" -M "${ADMIN_DIR}" --tls.certfiles "${ORG_ROOT_CERT}"
cp "${ADMIN_DIR}/cacerts/"*.pem "${ADMIN_DIR}/cacerts/ca.crt"

# NodeOU Config
cat > "${ORG_MSP}/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: orderer
EOF
cp "${ORG_MSP}/config.yaml" "${ADMIN_DIR}/config.yaml"

# 4. The Admin Dance (Channel admission)
echo "💃 Performing the Admin Dance..."
export FABRIC_CFG_PATH="${NETWORK_DIR}"
configtxgen -printOrg "${MSP_ID}" > "${ARTIFACTS_DIR}/${ORG_NAME}.json"

# Use internal_config_update.sh through CLI
# We allow this to fail if no differences are detected
set +e
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  cli /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/internal_config_update.sh "${CHANNEL_NAME}" "/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${ORG_NAME}.json" "${MSP_ID}"
UPDATE_RESULT=$?
set -e

if [ $UPDATE_RESULT -eq 0 ]; then
    echo "✍️ Collecting signatures..."
    # Loop through existing organizations in the organizations folder to find admins
    for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
        [ -d "$org_dir" ] || continue
        EXISTING_ORG=$(basename "$org_dir")
        [ "$EXISTING_ORG" == "$DOMAIN" ] && continue # Skip the new one
        
        EXISTING_MSP_ID="Org$(echo $EXISTING_ORG | grep -o '[0-9]\+')MSP"
        echo "Signing with ${EXISTING_MSP_ID}..."
        
        docker exec \
          -e CORE_PEER_LOCALMSPID="${EXISTING_MSP_ID}" \
          -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${EXISTING_ORG}/users/Admin@${EXISTING_ORG}/msp" \
          cli peer channel signconfigtx -f update_in_envelope.pb
    done

    echo "🗳️ Submitting channel update..."
    MAX_RETRIES=5
    RETRY_COUNT=0
    SUCCESS=false
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        set +e
        docker exec \
          -e CORE_PEER_LOCALMSPID="Org1MSP" \
          -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
          cli peer channel update -f update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
        
        if [ $? -eq 0 ]; then
            SUCCESS=true
            set -e
            break
        else
            RETRY_COUNT=$((RETRY_COUNT+1))
            echo "⚠️ Channel update failed (attempt $RETRY_COUNT/$MAX_RETRIES). Retrying in 5s..."
            sleep 5
        fi
        set -e
    done
    if [ "$SUCCESS" = false ]; then echo "❌ ERROR: Failed to submit channel update."; exit 1; fi
else
    echo "ℹ️ Skipping channel update: Organization already exists in channel or no changes detected."
fi

# 5. Bring Peer Online and Join
echo "🏢 Starting Peer..."
"${SCRIPTS_DIR}/add-peer.sh" peer0 "${ORG_NAME}" "${CHANNEL_NAME}"

# 6. Chaincode Lifecycle
echo "📦 Finalizing Chaincode Lifecycle for ${ORG_NAME}..."
PACKAGE_ID=$(cat "${NETWORK_DIR}/packaging/package_id.txt")

docker exec \
  -e CORE_PEER_ADDRESS="peer0.${DOMAIN}:7051" \
  -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
  -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls/ca.crt" \
  cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/packaging/basic.tar.gz

    MAX_RETRIES=5
    RETRY_COUNT=0
    SUCCESS=false
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        set +e
        docker exec \
          -e CORE_PEER_ADDRESS="peer0.${DOMAIN}:7051" \
          -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
          -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
          -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls/ca.crt" \
          cli peer lifecycle chaincode approveformyorg \
            --channelID "${CHANNEL_NAME}" --name basic --version 1.0 \
            --package-id "${PACKAGE_ID}" --sequence 1 --tls \
            --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
        
        if [ $? -eq 0 ]; then
            SUCCESS=true
            set -e
            break
        else
            RETRY_COUNT=$((RETRY_COUNT+1))
            echo "⚠️ CC Approval failed (attempt $RETRY_COUNT/$MAX_RETRIES). Retrying in 5s..."
            sleep 5
        fi
        set -e
    done
    if [ "$SUCCESS" = false ]; then echo "❌ ERROR: Failed to approve chaincode."; exit 1; fi

echo "✅ [SUCCESS] ${ORG_NAME} has been added and integrated!"
