#!/bin/bash
# network/scripts/add-orderer.sh
# Automates adding a new Orderer node to the Raft cluster.

set -e

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"
mkdir -p "${ARTIFACTS_DIR}"

echo "🚀 [ORDERER] Starting Dynamic Orderer Provisioning..."

# 1. Auto-Determine Next Orderer ID
# scan docker-compose-orderers.yaml (if exists) or assume 2 if only base exists
ORDERER_COMPOSE="${NETWORK_DIR}/compose/docker-compose-orderers.yaml"

LAST_ID=1
if [ -f "$ORDERER_COMPOSE" ]; then
    LAST_ID=$(grep "container_name: orderer" "$ORDERER_COMPOSE" | grep -o "[0-9]\+" | sort -nr | head -n 1)
    if [ -z "$LAST_ID" ]; then LAST_ID=1; fi
fi

NEW_ID=$((LAST_ID + 1))
ORDERER_NAME="orderer${NEW_ID}"
ORDERER_HOST="${ORDERER_NAME}.example.com"
echo "📍 Assigned New Orderer ID: ${NEW_ID} (${ORDERER_HOST})"

# Port Strategy:
# Orderer1: 7050, 7053
# Orderer2: 7150, 7153 (+100 offset)
LISTEN_PORT=$((7050 + (NEW_ID-1)*100))
ADMIN_PORT=$((7053 + (NEW_ID-1)*100))

# 2. Generate/Update Docker Compose
echo "🐳 Updating ${ORDERER_COMPOSE}..."
python3 <<EOF
import yaml
import os

file_path = '${ORDERER_COMPOSE}'
new_id = ${NEW_ID}
host = '${ORDERER_HOST}'
listen = ${LISTEN_PORT}
admin = ${ADMIN_PORT}

data = {'version': '3.7', 'networks': {'test': {'name': 'fabric_test'}}, 'services': {}, 'volumes': {}}

if os.path.exists(file_path):
    with open(file_path, 'r') as f:
        data = yaml.safe_load(f) or data

# Service Definition
service = {
    'container_name': host,
    'image': 'hyperledger/fabric-orderer:2.5.14',
    'environment': [
        'FABRIC_LOGGING_SPEC=INFO',
        'ORDERER_GENERAL_LISTENADDRESS=0.0.0.0',
        f'ORDERER_GENERAL_LISTENPORT={listen}',
        'ORDERER_GENERAL_BOOTSTRAPMETHOD=none',
        'ORDERER_CHANNELPARTICIPATION_ENABLED=true',
        'ORDERER_GENERAL_LOCALMSPID=OrdererMSP',
        'ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp',
        'ORDERER_GENERAL_TLS_ENABLED=true',
        'ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key',
        'ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt',
        'ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]',
        'ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1',
        'ORDERER_KAFKA_VERBOSE=true',
        'ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt',
        'ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key',
        'ORDERER_GENERAL_CLUSTER_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]',
        f'ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:{admin}',
        'ORDERER_ADMIN_TLS_ENABLED=true',
        'ORDERER_ADMIN_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key',
        'ORDERER_ADMIN_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt',
        'ORDERER_ADMIN_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]',
        'ORDERER_ADMIN_TLS_CLIENTAUTHREQUIRED=true',
        'ORDERER_ADMIN_TLS_CLIENTROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]'
    ],
    'working_dir': '/opt/gopath/src/github.com/hyperledger/fabric',
    'command': 'orderer',
    'volumes': [
        f'../organizations/ordererOrganizations/example.com/orderers/{host}/msp:/var/hyperledger/orderer/msp',
        f'../organizations/ordererOrganizations/example.com/orderers/{host}/tls:/var/hyperledger/orderer/tls',
        f'{host}:/var/hyperledger/production/orderer'
    ],
    'ports': [
        f'{listen}:{listen}',
        f'{admin}:{admin}'
    ],
    'networks': ['test']
}

data['services'][host] = service
data['volumes'][host] = {}

with open(file_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# 3. Generate Crypto
echo "🔑 Generating Crypto for ${ORDERER_HOST}..."
ORD_CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/orderer"
TLS_CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/tls"
ORDERER_MSP_DIR="${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/${ORDERER_HOST}/msp"
ORDERER_TLS_DIR="${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/${ORDERER_HOST}/tls"

mkdir -p "${ORDERER_MSP_DIR}" "${ORDERER_TLS_DIR}"

# Determine Orderer CA Port (From bootstrap) -> 9054
CA_PORT=9054
TLS_PORT=5054

# Register (ignore error if exists)
echo "   Registering with Orderer CA..."
set +e
FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client register -u https://localhost:${CA_PORT} --caname ca-orderer --id.name "${ORDERER_NAME}" --id.secret ordererpw --id.type orderer --tls.certfiles "${ORD_CA_HOME}/ca-cert.pem" 2>/dev/null
# Register TLS
echo "   Registering with TLS CA..."
FABRIC_CA_CLIENT_HOME="${TLS_CA_HOME}" fabric-ca-client register -u https://localhost:${TLS_PORT} --caname ca-tls --id.name "${ORDERER_NAME}" --id.secret ordererpw --id.type orderer --tls.certfiles "${TLS_CA_HOME}/ca-cert.pem" 2>/dev/null
set -e

# Enroll Admin for OrdererOrg (if not already present)
# This is needed to sign the channel config update
ORD_ADMIN_MSP="${NETWORK_DIR}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp"
if [ ! -d "${ORD_ADMIN_MSP}" ]; then
    echo "   Enrolling Orderer Admin..."
    set +e
    FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client register --caname ca-orderer --id.name ordadmin --id.secret ordadminpw --id.type admin --tls.certfiles "${ORD_CA_HOME}/ca-cert.pem" 2>/dev/null
    set -e
    mkdir -p "${ORD_ADMIN_MSP}"
    FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client enroll -u https://ordadmin:ordadminpw@localhost:9054 --caname ca-orderer -M "${ORD_ADMIN_MSP}" --tls.certfiles "${ORD_CA_HOME}/ca-cert.pem"
    cp "${ORD_ADMIN_MSP}/cacerts/"*.pem "${ORD_ADMIN_MSP}/cacerts/ca.crt"
    cp "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/msp/config.yaml" "${ORD_ADMIN_MSP}/config.yaml"
fi

# Enroll MSP
echo "   Enrolling MSP..."
FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client enroll -u "https://${ORDERER_NAME}:ordererpw@localhost:${CA_PORT}" --caname ca-orderer -M "${ORDERER_MSP_DIR}" --tls.certfiles "${ORD_CA_HOME}/ca-cert.pem"
# Setup NodeOU
cp "${ORDERER_MSP_DIR}/cacerts/"*.pem "${ORDERER_MSP_DIR}/cacerts/ca.crt"
cp "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/msp/config.yaml" "${ORDERER_MSP_DIR}/config.yaml"

# Enroll TLS
echo "   Enrolling TLS..."
FABRIC_CA_CLIENT_HOME="${TLS_CA_HOME}" fabric-ca-client enroll -u "https://${ORDERER_NAME}:ordererpw@localhost:${TLS_PORT}" --caname ca-tls -M "${ORDERER_TLS_DIR}" --enrollment.profile tls --csr.hosts "${ORDERER_HOST},localhost" --tls.certfiles "${NETWORK_DIR}/organizations/fabric-ca/tls/ca-cert.pem"

# Move/Rename Keys
mv "${ORDERER_TLS_DIR}/keystore/"*_sk "${ORDERER_TLS_DIR}/server.key"
cp "${ORDERER_TLS_DIR}/signcerts/cert.pem" "${ORDERER_TLS_DIR}/server.crt"
cp "${ORDERER_TLS_DIR}/tlscacerts/"* "${ORDERER_TLS_DIR}/ca.crt"

# 4. Update Channel Config (The Heavy Lifting)
echo "📝 Updating Channel Configuration to include new Consenter..."
sleep 5

# Fetch Config
CHANNEL_NAME="mychannel" # System channel is usually mychannel in modern fabric (app channel)
echo "   Fetching config block..."
docker exec cli peer channel fetch config channel-artifacts/config_block.pb -o orderer.example.com:7050 -c "${CHANNEL_NAME}" --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
configtxlator proto_decode --input "${ARTIFACTS_DIR}/config_block.pb" --type common.Block | jq .data.data[0].payload.data.config > "${ARTIFACTS_DIR}/config.json"

# Python Script to modify Config JSON
echo "   Injecting new consenter info..."
python3 <<EOF
import json
import base64

config_file = '${ARTIFACTS_DIR}/config.json'
tls_cert_file = '${ORDERER_TLS_DIR}/server.crt'
host = '${ORDERER_HOST}'
port = ${LISTEN_PORT}

with open(config_file, 'r') as f:
    data = json.load(f)

# Read TLS Cert and Base64 Encode it (Standard encoding, not URL safe?)
# Fabric expects 'client_tls_cert' as byte bytes in the protobuf, which translates to base64 string in JSON.
with open(tls_cert_file, 'rb') as f:
    cert_pem = f.read()

# Encode base64
cert_b64 = base64.b64encode(cert_pem).decode('utf-8')

# 1. Add to OrdererAddresses
# Path: channel_group.values.OrdererAddresses.value.addresses
addresses = data['channel_group']['values']['OrdererAddresses']['value']['addresses']
new_addr = f"{host}:{port}"
if new_addr not in addresses:
    addresses.append(new_addr)

# 2. Add to Consenters (EtcdRaft)
# Path: channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters
# This structure depends on Fabric version. For 2.x it is 'consenters'.
consenters = data['channel_group']['groups']['Orderer']['values']['ConsensusType']['value']['metadata']['consenters']

# Check duplicate
exists = any(c['host'] == host and c['port'] == port for c in consenters)

if not exists:
    new_consenter = {
        'host': host,
        'port': port,
        'client_tls_cert': cert_b64,
        'server_tls_cert': cert_b64
    }
    consenters.append(new_consenter)
    print(f"Added consenter: {host}:{port}")
else:
    print("Consenter already present.")

with open('${ARTIFACTS_DIR}/modified_config.json', 'w') as f:
    json.dump(data, f)
EOF

# Encode back to PB (Using CLI for version compatibility)
echo "   Computing update delta (via CLI)..."
docker exec cli configtxlator proto_encode --input channel-artifacts/config.json --type common.Config --output channel-artifacts/original_config.pb
docker exec cli configtxlator proto_encode --input channel-artifacts/modified_config.json --type common.Config --output channel-artifacts/modified_config.pb
docker exec cli configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original channel-artifacts/original_config.pb --updated channel-artifacts/modified_config.pb --output channel-artifacts/config_update.pb

# Wrap in Envelope
echo "   Wrapping in envelope (via CLI)..."
docker exec cli sh -c "configtxlator proto_decode --input channel-artifacts/config_update.pb --type common.ConfigUpdate | jq '{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"${CHANNEL_NAME}\", \"type\":2}},\"data\":{\"config_update\":.}}}' | configtxlator proto_encode --type common.Envelope --output channel-artifacts/update_in_envelope.pb"

# 5. Sign and Submit
# Needs to be signed by Orderer Admin (OrdererMSP)
echo "🗳️  Submitting Config Update (Adding Orderer)..."

docker exec \
  -e CORE_PEER_LOCALMSPID="OrdererMSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp \
  cli peer channel update -f channel-artifacts/update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

# 6. Start Container
echo "🏗️  Starting ${ORDERER_HOST}..."
docker compose -f "${ORDERER_COMPOSE}" up -d "${ORDERER_HOST}"

echo "⏳ Waiting for ${ORDERER_HOST} to start (5s)..."
sleep 5

# 7. Join Channel
echo "🔗 Joining ${ORDERER_HOST} to channel ${CHANNEL_NAME}..."
docker exec cli osnadmin channel join \
  --channelID "${CHANNEL_NAME}" \
  --config-block "/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/config_block.pb" \
  -o "${ORDERER_HOST}:${ADMIN_PORT}" \
  --ca-file "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" \
  --client-cert "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt" \
  --client-key "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"

echo "✅ [SUCCESS] ${ORDERER_HOST} has been provisioned and joined the cluster!"
