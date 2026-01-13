#!/bin/bash
# network/scripts/add-peer.sh
# Handles Identity (CA) and Infrastructure (Docker) for a new node.
# This script automatically provisions a paired CouchDB container.

set -e

PEER_ID=$1    
ORG_NAME=$2   
CHANNEL_NAME=$3

if [ -z "$PEER_ID" ] || [ -z "$ORG_NAME" ]; then
    echo "Usage: ./network/scripts/add-peer.sh <peer_id> <org_name> [channel_name]"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"

# --- DYNAMIC CONFIGURATION ---
ORG_NUM=$(echo $ORG_NAME | grep -o '[0-9]\+')
if [ -z "$ORG_NUM" ]; then
    echo "Error: Organization name must contain a number (e.g. org1)"
    exit 1
fi
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"

# CA Port logic (matching add-org.sh)
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then 
    CA_PORT=10054
elif [ $CA_PORT -ge 10054 ]; then 
    CA_PORT=$((CA_PORT+1000))
fi

PEER_NAME="${PEER_ID}.${DOMAIN}"
ORG_ROOT_CERT="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}/ca-cert.pem"
PEER_PW="${PEER_ID}pw"

# Set CA Home context for all following fabric-ca-client commands
export FABRIC_CA_CLIENT_HOME="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"

echo "🚀 [INFRA] Preparing certificates for ${PEER_NAME}..."

# 1. REGISTER
set +e
fabric-ca-client register --caname "ca-${ORG_NAME}" --id.name "${PEER_ID}" --id.secret "${PEER_PW}" --id.type peer --tls.certfiles "${ORG_ROOT_CERT}" 2>/dev/null
set -e

PEER_BASE_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}"
rm -rf "${PEER_BASE_DIR}/msp" "${PEER_BASE_DIR}/tls" # Fresh start

# 2. ENROLL MSP
mkdir -p "${PEER_BASE_DIR}/msp"
fabric-ca-client enroll -u "https://${PEER_ID}:${PEER_PW}@localhost:${CA_PORT}" \
    --caname "ca-${ORG_NAME}" -M "${PEER_BASE_DIR}/msp" --tls.certfiles "${ORG_ROOT_CERT}"
cp "$(ls ${PEER_BASE_DIR}/msp/cacerts/*.pem | head -n 1)" "${PEER_BASE_DIR}/msp/cacerts/ca.crt"
cp "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/msp/config.yaml" "${PEER_BASE_DIR}/msp/config.yaml"

# 3. ENROLL TLS
mkdir -p "${PEER_BASE_DIR}/tls"
fabric-ca-client enroll -u "https://${PEER_ID}:${PEER_PW}@localhost:${CA_PORT}" \
    --caname "ca-${ORG_NAME}" --enrollment.profile tls --csr.hosts "${PEER_NAME},localhost" \
    -M "${PEER_BASE_DIR}/tls" --tls.certfiles "${ORG_ROOT_CERT}"
cp "${PEER_BASE_DIR}/tls/keystore/"* "${PEER_BASE_DIR}/tls/server.key"
cp "${PEER_BASE_DIR}/tls/signcerts/"* "${PEER_BASE_DIR}/tls/server.crt"
cp "${ORG_ROOT_CERT}" "${PEER_BASE_DIR}/tls/ca.crt"

# 4. UPDATE DOCKER
echo "🐳 Updating docker-compose.yaml with Peer and CouchDB info..."
python3 <<EOF
import yaml
composed_path = '${NETWORK_DIR}/docker-compose.yaml'
with open(composed_path, 'r') as f:
    data = yaml.safe_load(f)

peer_name = '${PEER_NAME}'
org_domain = '${DOMAIN}'
msp_id = '${MSP_ID}'

peers = [svc for svc in data['services'] if 'peer' in svc and svc != 'cli']
couches = [svc for svc in data['services'] if 'couchdb' in svc]
max_grpc = 6051
max_ops = 8443
max_couch = 4984

for p in peers:
    if p == peer_name: continue 
    ports = data['services'][p].get('ports', [])
    if len(ports) >= 1:
        grpc = int(ports[0].split(':')[0])
        if grpc > max_grpc and grpc < 20000: max_grpc = grpc
    if len(ports) >= 2:
        ops = int(ports[1].split(':')[0])
        if ops > max_ops and ops < 20000: max_ops = ops

for c in couches:
    p_list = data['services'][c].get('ports', [])
    if p_list:
        c_port = int(p_list[0].split(':')[0])
        if c_port > max_couch: max_couch = c_port

couch_name = f"couchdb.{peer_name}"
couch_port = max_couch + 1000

couch_config = {
    'container_name': couch_name,
    'image': 'couchdb:3.3.2',
    'environment': ['COUCHDB_USER=admin', 'COUCHDB_PASSWORD=adminpw'],
    'ports': [f'{couch_port}:5984'],
    'networks': ['test']
}

peer_config = {
    'container_name': peer_name,
    'image': 'hyperledger/fabric-peer:2.5.14',
    'environment': [
        'CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock',
        'CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_test',
        'FABRIC_LOGGING_SPEC=INFO',
        'CORE_PEER_TLS_ENABLED=true',
        'CORE_PEER_PROFILE_ENABLED=true',
        'CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt',
        'CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key',
        'CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt',
        f'CORE_PEER_ID={peer_name}',
        f'CORE_PEER_ADDRESS={peer_name}:7051',
        'CORE_PEER_LISTENADDRESS=0.0.0.0:7051',
        f'CORE_PEER_CHAINCODEADDRESS={peer_name}:7052',
        'CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052',
        'CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051',
        f'CORE_PEER_GOSSIP_EXTERNALENDPOINT={peer_name}:7051',
        f'CORE_PEER_LOCALMSPID={msp_id}',
        'CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:9443',
        'CORE_LEDGER_STATE_STATEDATABASE=CouchDB',
        f'CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS={couch_name}:5984',
        'CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin',
        'CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw',
        'CORE_PEER_CHAINCODE_EXTERNALBUILDERS=[{"name":"ccaas-builder","path":"/opt/hyperledger/builders/ccaas"}]'
    ],
    'volumes': [
        '/var/run/docker.sock:/host/var/run/docker.sock',
        f'./organizations/peerOrganizations/{org_domain}/peers/{peer_name}/msp:/etc/hyperledger/fabric/msp',
        f'./organizations/peerOrganizations/{org_domain}/peers/{peer_name}/tls:/etc/hyperledger/fabric/tls',
        '../builders/ccaas:/opt/hyperledger/builders/ccaas',
        f'{peer_name}:/var/hyperledger/production'
    ],
    'working_dir': '/opt/gopath/src/github.com/hyperledger/fabric/peer',
    'command': 'peer node start',
    'ports': [f'{max_grpc + 1000}:7051', f'{max_ops + 1000}:9443'],
    'depends_on': [couch_name],
    'networks': ['test']
}
data['services'][couch_name] = couch_config
data['services'][peer_name] = peer_config
data['volumes'][peer_name] = None
with open(composed_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

echo "🏗️ Starting containers for ${PEER_NAME} and CouchDB..."
docker-compose -f "${NETWORK_DIR}/docker-compose.yaml" up -d "couchdb.${PEER_NAME}" "${PEER_NAME}"

if [ ! -z "$CHANNEL_NAME" ]; then
    echo "🔗 Waiting for ${PEER_NAME} to initialize (8s)..."
    sleep 8
    
    BLOCK_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block"
    ADMIN_MSP="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp"
    TLS_ROOT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt"
    PEER_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/server.crt"
    PEER_KEY="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/server.key"

    echo "🔗 Joining ${PEER_NAME} to channel ${CHANNEL_NAME}..."
    docker exec \
      -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="${ADMIN_MSP}" \
      -e CORE_PEER_TLS_CERT_FILE="${PEER_CERT}" \
      -e CORE_PEER_TLS_KEY_FILE="${PEER_KEY}" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="${TLS_ROOT}" \
      cli peer channel join -b "${BLOCK_PATH}"
    
    echo "✅ SUCCESS: ${PEER_NAME} joined ${CHANNEL_NAME}."
else
    echo "✅ Node is UP. To join a channel manually, use: docker exec cli peer channel join -b <block> (with correct env)"
fi
