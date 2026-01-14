#!/bin/bash
# network/scripts/freeze-org.sh
# Orchestrates the freezing of an organization in the consortium.

set -e

ORG_NUM=$1
CHANNEL_NAME=${2:-mychannel}

if [ -z "$ORG_NUM" ]; then
    echo "Usage: ./network/scripts/freeze-org.sh <org_num> [channel_name]"
    echo "Example: ./network/scripts/freeze-org.sh 2 mychannel"
    exit 1
fi

ORG_NAME="org${ORG_NUM}"
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"

echo "❄️ [ADMIN] Initiating freeze protocol for ${ORG_NAME}..."

# 1. Generate the update envelope inside CLI
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  cli /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/internal_config_freeze.sh "${CHANNEL_NAME}" "${MSP_ID}"

# 2. Collect signatures from ALL organizations
echo "✍️  Collecting consortium signatures..."
for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
    [ -d "$org_dir" ] || continue
    EXISTING_ORG_DOMAIN=$(basename "$org_dir")
    
    # Extract Org number to build MSP ID
    EXISTING_ORG_NUM=$(echo $EXISTING_ORG_DOMAIN | grep -o '[0-9]\+')
    EXISTING_MSP_ID="Org${EXISTING_ORG_NUM}MSP"
    
    echo "Signing with ${EXISTING_MSP_ID}..."
    docker exec \
      -e CORE_PEER_LOCALMSPID="${EXISTING_MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${EXISTING_ORG_DOMAIN}/users/Admin@${EXISTING_ORG_DOMAIN}/msp" \
      cli peer channel signconfigtx -f update_in_envelope.pb
done

# 3. Submit Update
echo "🗳️  Submitting freeze transaction to Orderer..."
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer channel update -f update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

echo "📉 Powering down ${ORG_NAME} infrastructure..."
docker stop "peer0.${DOMAIN}" "ca_${ORG_NAME}" || echo "⚠️ Could not stop containers (already down?)"

echo "✅ [SUCCESS] ${ORG_NAME} is now frozen and restricted from the channel."
