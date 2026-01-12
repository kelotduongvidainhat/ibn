#!/bin/bash
# network/scripts/bootstrap.sh
# Automates the infrastructure setup for the MVP using cryptogen.

# Exit on error
set -e

# Configuration
CHANNEL_NAME="mychannel"
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
ART_DIR="${NETWORK_DIR}/channel-artifacts"
ORG_DIR="${NETWORK_DIR}/organizations"

echo "=== Fabric Infrastructure Bootstrap ==="

# 1. Clean old state
echo "--- Cleaning old state ---"
docker-compose -f "${NETWORK_DIR}/docker-compose.yaml" down --volumes --remove-orphans || true
rm -rf "${ORG_DIR}" "${ART_DIR}"
mkdir -p "${ART_DIR}"

# 2. Generate Identities
echo "--- Generating certificates (cryptogen) ---"
"${BIN_DIR}/cryptogen" generate --config="${NETWORK_DIR}/crypto-config.yaml" --output="${ORG_DIR}"

# 3. Generate Genesis Block
echo "--- Generating channel genesis block ---"
export FABRIC_CFG_PATH="${NETWORK_DIR}"
"${BIN_DIR}/configtxgen" -profile Org1Channel -outputBlock "${ART_DIR}/${CHANNEL_NAME}.block" -channelID "${CHANNEL_NAME}"

# 4. Start Containers
echo "--- Starting network services ---"
docker-compose -f "${NETWORK_DIR}/docker-compose.yaml" up -d

# 5. Wait for containers
echo "--- Waiting for nodes to start (10s) ---"
sleep 10

# 6. Join Orderer to Channel
echo "--- Joining Orderer to channel: ${CHANNEL_NAME} ---"
docker exec cli osnadmin channel join \
  --channelID "${CHANNEL_NAME}" \
  --config-block "/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block" \
  -o orderer.example.com:7053 \
  --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
  --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
  --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

# 7. Join Peer to Channel
echo "--- Joining Peer to channel: ${CHANNEL_NAME} ---"
docker exec cli peer channel join -b "/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block"

# 8. Success Report
echo "--- Final Verification ---"
docker exec cli peer channel list
echo "Bootstrap Complete! Network is ready for chaincode."
