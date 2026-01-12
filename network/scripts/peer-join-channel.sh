#!/bin/bash
# network/scripts/peer-join-channel.sh
# Targets a specific peer and joins it to a specified channel.

set -e

PEER_ID=$1       # e.g. peer0
ORG_NAME=$2      # e.g. org1
CHANNEL_NAME=$3  # e.g. mychannel

if [ -z "$PEER_ID" ] || [ -z "$ORG_NAME" ] || [ -z "$CHANNEL_NAME" ]; then
    echo "Usage: ./network/scripts/peer-join-channel.sh <peer_id> <org_name> <channel_name>"
    exit 1
fi

DOMAIN="${ORG_NAME}.example.com"
# Convert org1 to Org1MSP
ORG_NUM=$(echo $ORG_NAME | grep -o '[0-9]\+')
MSP_ID="Org${ORG_NUM}MSP"

PEER_NAME="${PEER_ID}.${DOMAIN}"
BLOCK_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block"
ADMIN_MSP="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp"

# Peer-specific TLS paths within the CLI container
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
