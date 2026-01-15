#!/bin/bash
# network/scripts/add-peer.sh
# Adds a new peer (and its CouchDB) to an existing organization's infrastructure.
# Supports idempotent calling (safe for add-org.sh bootstrapping).

set -e

PEER_ID=$1    
ORG_NAME=$2   
CHANNEL_NAME=${3:-mychannel}

if [ -z "$PEER_ID" ] || [ -z "$ORG_NAME" ]; then
    echo "Usage: ./network/scripts/add-peer.sh <peer_id> <org_name> [channel_name]"
    echo "Example: ./network/scripts/add-peer.sh peer1 org1"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True

# --- DYNAMIC CONFIGURATION ---
ORG_NUM=$(echo $ORG_NAME | grep -o '[0-9]\+')

COMPOSE_FILE="${NETWORK_DIR}/compose/docker-compose-org${ORG_NUM}.yaml"
DOMAIN="${ORG_NAME}.example.com"

if [ "$PEER_ID" == "auto" ]; then
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ Error: Compose file not found for ${ORG_NAME}. Cannot auto-increment."
        exit 1
    fi
    # Find highest peer number in the yaml
    # Grep for "peer[0-9]"
    LAST_ID=$(grep -o "peer[0-9]\+.${DOMAIN}" "$COMPOSE_FILE" | grep -o "peer[0-9]\+" | grep -o "[0-9]\+" | sort -nr | head -n 1)
    if [ -z "$LAST_ID" ]; then
        NEXT_NUM=0
    else
        NEXT_NUM=$((LAST_ID + 1))
    fi
    PEER_ID="peer${NEXT_NUM}"
    echo "🤖 Auto-detected next Peer ID: ${PEER_ID}"
fi

PEER_NUM=$(echo $PEER_ID | grep -o '[0-9]\+')
MSP_ID="Org${ORG_NUM}MSP"
PEER_NAME="${PEER_ID}.${DOMAIN}"
COUCH_NAME="couchdb.${PEER_NAME}"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: Compose file for ${ORG_NAME} not found: $COMPOSE_FILE"
    exit 1
fi

echo "🚀 [INFRA] Provisioning ${PEER_NAME}..."

# --- 1. IDEMPOTENT YAML INJECTION ---
# Calculate Ports strictly matching README.md strategy
# Base = (Org-1)*1000. PeerOffset = Peer*100.
BASE_OFFSET=$(( (ORG_NUM - 1) * 1000 ))
PEER_OFFSET=$(( PEER_NUM * 100 ))

PORT_PEER_LISTEN=$(( 7051 + BASE_OFFSET + PEER_OFFSET ))
PORT_PEER_CC=$(( 7052 + BASE_OFFSET + PEER_OFFSET ))
PORT_PEER_OPS=$(( 9443 + BASE_OFFSET + PEER_OFFSET ))
PORT_COUCH=$(( 5984 + BASE_OFFSET + PEER_OFFSET ))

echo "ℹ️  Ports: Peer=${PORT_PEER_LISTEN}, Couch=${PORT_COUCH}, Ops=${PORT_PEER_OPS}"

python3 <<EOF
import yaml
import os
import sys

file_path = '${COMPOSE_FILE}'
peer_svc_name = '${PEER_NAME}'
couch_svc_name = '${COUCH_NAME}'

org_num = '${ORG_NUM}'
domain = '${DOMAIN}'
msp_id = '${MSP_ID}'

# Ports
p_peer = ${PORT_PEER_LISTEN}
p_cc = ${PORT_PEER_CC}
p_ops = ${PORT_PEER_OPS}
p_couch = ${PORT_COUCH}

if not os.path.exists(file_path):
    sys.exit(1)

with open(file_path, 'r') as f:
    data = yaml.safe_load(f)

if 'services' not in data: data['services'] = {}

# Check idempotency
if peer_svc_name in data['services']:
    print(f"⚠️  Service {peer_svc_name} already exists in YAML. Skipping injection.")
    sys.exit(0)

print(f"📝 Injecting {peer_svc_name} into docker-compose...")

# CouchDB Definition
service_couch = {
    'container_name': couch_svc_name,
    'image': 'couchdb:3.3.2',
    'environment': [
        'COUCHDB_USER=admin',
        'COUCHDB_PASSWORD=adminpw'
    ],
    'ports': [f'{p_couch}:5984'],
    'networks': ['test']
}

# Peer Definition
service_peer = {
    'container_name': peer_svc_name,
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
        f'CORE_PEER_ID={peer_svc_name}',
        f'CORE_PEER_ADDRESS={peer_svc_name}:7051',
        f'CORE_PEER_LISTENADDRESS=0.0.0.0:7051',
        f'CORE_PEER_CHAINCODEADDRESS={peer_svc_name}:7052',
        f'CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052',
        f'CORE_PEER_GOSSIP_BOOTSTRAP={peer_svc_name}:7051',
        f'CORE_PEER_GOSSIP_EXTERNALENDPOINT={peer_svc_name}:7051',
        f'CORE_PEER_LOCALMSPID={msp_id}',
        'CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:9443',
        'CORE_LEDGER_STATE_STATEDATABASE=CouchDB',
        f'CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS={couch_svc_name}:5984',
        'CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin',
        'CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw',
        'CORE_PEER_CHAINCODE_EXTERNALBUILDERS=[{"name":"ccaas-builder","path":"/opt/hyperledger/builders/ccaas"}]'
    ],
    'volumes': [
        '/var/run/docker.sock:/host/var/run/docker.sock',
        f'../organizations/peerOrganizations/{domain}/peers/{peer_svc_name}/msp:/etc/hyperledger/fabric/msp',
        f'../organizations/peerOrganizations/{domain}/peers/{peer_svc_name}/tls:/etc/hyperledger/fabric/tls',
        '../../builders/ccaas:/opt/hyperledger/builders/ccaas',
        f'{peer_svc_name}:/var/hyperledger/production'
    ],
    'working_dir': '/opt/gopath/src/github.com/hyperledger/fabric/peer',
    'command': 'peer node start',
    'ports': [
        f'{p_peer}:7051',
        f'{p_ops}:9443'
    ],
    'depends_on': [couch_svc_name],
    'networks': ['test']
}

# Volume Definition
if 'volumes' not in data or data['volumes'] is None: data['volumes'] = {}
data['volumes'][peer_svc_name] = None

# Update Data
data['services'][couch_svc_name] = service_couch
data['services'][peer_svc_name] = service_peer

# Write Back
with open(file_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF


# --- 2. CRYPTO ENROLLMENT ---
echo "🔑 Generating crypto material for ${PEER_NAME}..."

# Determine CA Port (Org3 Exception Logic matches add-org.sh)
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then CA_PORT=10054; elif [ $CA_PORT -ge 10054 ]; then CA_PORT=$((CA_PORT+1000)); fi

export FABRIC_CA_CLIENT_HOME="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"
ORG_ROOT_CERT="${FABRIC_CA_CLIENT_HOME}/ca-cert.pem"

TLS_CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/tls"
TLS_ROOT_CERT="${TLS_CA_HOME}/ca-cert.pem"

PEER_BASE_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}"
mkdir -p "${PEER_BASE_DIR}/msp" "${PEER_BASE_DIR}/tls"

set +e
# Register Identity (ignore if exists)
fabric-ca-client register --caname "ca-${ORG_NAME}" --id.name "${PEER_ID}" --id.secret "${PEER_ID}pw" --id.type peer --tls.certfiles "${ORG_ROOT_CERT}" 2>/dev/null
# Register TLS Identity
FABRIC_CA_CLIENT_HOME="${TLS_CA_HOME}" fabric-ca-client register --caname ca-tls --id.name "${ORG_NAME}-${PEER_ID}" --id.secret "${PEER_ID}pw" --id.type peer --tls.certfiles "${TLS_ROOT_CERT}" 2>/dev/null
set -e

# Enroll MSP
if [ ! -f "${PEER_BASE_DIR}/msp/config.yaml" ]; then
    fabric-ca-client enroll -u "https://${PEER_ID}:${PEER_ID}pw@localhost:${CA_PORT}" --caname "ca-${ORG_NAME}" -M "${PEER_BASE_DIR}/msp" --tls.certfiles "${ORG_ROOT_CERT}"
    cp "$(ls ${PEER_BASE_DIR}/msp/cacerts/*.pem | head -n 1)" "${PEER_BASE_DIR}/msp/cacerts/ca.crt"
    cp "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/msp/config.yaml" "${PEER_BASE_DIR}/msp/config.yaml"
fi

# Enroll TLS
if [ ! -f "${PEER_BASE_DIR}/tls/server.crt" ]; then
    FABRIC_CA_CLIENT_HOME="${TLS_CA_HOME}" fabric-ca-client enroll -u "https://${ORG_NAME}-${PEER_ID}:${PEER_ID}pw@localhost:5054" --caname ca-tls --enrollment.profile tls --csr.hosts "${PEER_NAME},localhost" -M "${PEER_BASE_DIR}/tls" --tls.certfiles "${TLS_ROOT_CERT}"
    cp "${PEER_BASE_DIR}/tls/keystore/"* "${PEER_BASE_DIR}/tls/server.key"
    cp "${PEER_BASE_DIR}/tls/signcerts/"* "${PEER_BASE_DIR}/tls/server.crt"
    cp "${TLS_ROOT_CERT}" "${PEER_BASE_DIR}/tls/ca.crt"
fi


# --- 3. START SERVICES ---
echo "🏗️  Starting ${PEER_NAME}..."
docker compose -f "${NETWORK_DIR}/compose/docker-compose-base.yaml" -f "$COMPOSE_FILE" up -d "${COUCH_NAME}" "${PEER_NAME}"


# --- 4. JOIN CHANNEL ---
if [ ! -z "$CHANNEL_NAME" ]; then
    echo "🔗 Joining ${PEER_NAME} to channel ${CHANNEL_NAME}..."
    sleep 5
    BLOCK_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block"
    
    # If 0-block is missing (dynamic peer add), fetch it from Peer0 of same org or just try 0
    # For now assume channel-artifacts/mychannel.block exists if bootstrap ran.
    # If not, we might need to fetch it. (omitted for brevity, usually exists on CLI).

    docker exec \
      -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt" \
      cli peer channel join -b "${BLOCK_PATH}" || echo "⚠️  Join failed (Already joined?)"
fi

# --- 5. INSTALL CHAINCODE ---
CC_PACKAGE="${NETWORK_DIR}/packaging/basic.tar.gz"
if [ -f "$CC_PACKAGE" ]; then
    echo "Using Chaincode Package: ${CC_PACKAGE}"
    
    # Wait for peer to be ready
    echo "⏳ Waiting 10s for peer startup before installing chaincode..."
    sleep 10

    echo "📦 Installing Chaincode on ${PEER_NAME}..."
    docker exec \
      -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt" \
      cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/packaging/basic.tar.gz || echo "⚠️ Chaincode install failed (Already installed?)"
else
    echo "⚠️ Chaincode package not found at ${CC_PACKAGE}. Skipping install."
fi

echo "✅ Peer ${PEER_NAME} provisioning complete!"
