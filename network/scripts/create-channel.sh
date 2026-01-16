#!/bin/bash
# network/scripts/create-channel.sh
# Dynamically provisions a new application channel without network restarts.
# Refactored to run via CLI container for backend compatibility.

set -e

CHANNEL_NAME=$1
if [ -z "$CHANNEL_NAME" ]; then
    echo "Usage: ./network/scripts/create-channel.sh <channel_name>"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "🚀 [CHANNEL] Initiating creation of channel: ${CHANNEL_NAME}..."

# 0. Assemble configuration
"${NETWORK_DIR}/scripts/assemble-config.sh"

# 1. Generate Genesis Block (INSIDE CLI)
echo "📝 Step 1: Generating genesis block using DefaultChannel profile..."
docker exec -e FABRIC_CFG_PATH=/opt/gopath/src/github.com/hyperledger/fabric/peer cli configtxgen -profile DefaultChannel \
  -outputBlock "/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block" \
  -channelID "${CHANNEL_NAME}"

# 2. Join Orderer(s) to Channel via osnadmin (INSIDE CLI)
echo "🗳️  Step 2: Joining Orderer(s) to the new channel..."
# We discover orderers via their directories in the mount
for ord_dir in "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers"/*; do
    [ -d "$ord_dir" ] || continue
    ORD_NAME=$(basename "$ord_dir")
    
    # Logic for Admin Port (7053 + ID offset)
    ORD_NUM=$(echo "$ORD_NAME" | grep -o "[0-9]\+" || echo 1)
    ADMIN_PORT=$((7053 + (ORD_NUM-1)*100))
    
    # Since we are inside CLI container, we need to address orderers by their service names
    # Service names are orderer.example.com, orderer2.example.com, etc.
    # The Admin port inside the container is ALWAYS 7053 (as defined in compose)
    # BUT wait, the CLI container needs to connect to the ORDERER_HOST:7053.
    
    echo "   Joining ${ORD_NAME} on port 7053 (internal)..."
    docker exec cli osnadmin channel join --channelID "${CHANNEL_NAME}" \
      --config-block "channel-artifacts/${CHANNEL_NAME}.block" \
      -o "${ORD_NAME}:7053" \
      --ca-file "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" \
      --client-cert "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt" \
      --client-key "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"
done

# 3. Join Peers to Channel (INSIDE CLI)
echo "🔗 Step 3: Joining Peers from all active Organizations..."
for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
    [ -d "$org_dir" ] || continue
    ORG_DOMAIN=$(basename "$org_dir")
    ORG_NUM=$(echo "$ORG_DOMAIN" | grep -o "[0-9]\+" || echo 1)
    MSP_ID="Org${ORG_NUM}MSP"
    PEER_NAME="peer0.${ORG_DOMAIN}"
    
    echo "   Joining ${PEER_NAME} (${MSP_ID})..."
    
    docker exec \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/peers/${PEER_NAME}/tls/ca.crt" \
      cli peer channel join -b "channel-artifacts/${CHANNEL_NAME}.block"
done

echo "✅ [SUCCESS] Channel '${CHANNEL_NAME}' has been provisioned and joined by all members."
echo "📍 Note: You can now deploy chaincode to this channel using mass-approve.sh / mass-commit.sh."
