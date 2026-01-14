#!/bin/bash
# network/scripts/add-peer.sh
# Refactored for Modular Infrastructure

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
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"
PEER_NAME="${PEER_ID}.${DOMAIN}"

# Modular Compose File
COMPOSE_FILE="${NETWORK_DIR}/compose/docker-compose-org${ORG_NUM}.yaml"

# CA Port logic (matching add-org.sh)
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then CA_PORT=10054; elif [ $CA_PORT -ge 10054 ]; then CA_PORT=$((CA_PORT+1000)); fi

export FABRIC_CA_CLIENT_HOME="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"
ORG_ROOT_CERT="${FABRIC_CA_CLIENT_HOME}/ca-cert.pem"

echo "🚀 [INFRA] Enrolling identities for ${PEER_NAME}..."

# 1. Register/Enroll MSP & TLS
set +e
fabric-ca-client register --caname "ca-${ORG_NAME}" --id.name "${PEER_ID}" --id.secret "${PEER_ID}pw" --id.type peer --tls.certfiles "${ORG_ROOT_CERT}" 2>/dev/null
set -e

PEER_BASE_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}"
mkdir -p "${PEER_BASE_DIR}/msp" "${PEER_BASE_DIR}/tls"

fabric-ca-client enroll -u "https://${PEER_ID}:${PEER_ID}pw@localhost:${CA_PORT}" --caname "ca-${ORG_NAME}" -M "${PEER_BASE_DIR}/msp" --tls.certfiles "${ORG_ROOT_CERT}"
cp "$(ls ${PEER_BASE_DIR}/msp/cacerts/*.pem | head -n 1)" "${PEER_BASE_DIR}/msp/cacerts/ca.crt"
cp "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/msp/config.yaml" "${PEER_BASE_DIR}/msp/config.yaml"

fabric-ca-client enroll -u "https://${PEER_ID}:${PEER_ID}pw@localhost:${CA_PORT}" --caname "ca-${ORG_NAME}" --enrollment.profile tls --csr.hosts "${PEER_NAME},localhost" -M "${PEER_BASE_DIR}/tls" --tls.certfiles "${ORG_ROOT_CERT}"
cp "${PEER_BASE_DIR}/tls/keystore/"* "${PEER_BASE_DIR}/tls/server.key"
cp "${PEER_BASE_DIR}/tls/signcerts/"* "${PEER_BASE_DIR}/tls/server.crt"
cp "${ORG_ROOT_CERT}" "${PEER_BASE_DIR}/tls/ca.crt"

# 2. Start Services
echo "🏗️  Starting ${PEER_NAME} and its CouchDB via modular compose..."
docker compose -f "${NETWORK_DIR}/compose/docker-compose-base.yaml" -f "$COMPOSE_FILE" up -d "couchdb.${PEER_NAME}" "${PEER_NAME}"

# 3. Channel Join
if [ ! -z "$CHANNEL_NAME" ]; then
    echo "🔗 Joining ${PEER_NAME} to channel ${CHANNEL_NAME}..."
    sleep 5
    BLOCK_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block"
    
    docker exec \
      -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt" \
      cli peer channel join -b "${BLOCK_PATH}"
fi
