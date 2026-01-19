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
PROFILE_NAME=${2:-DefaultChannel}
ORGS_TO_JOIN=${3:-""} # optional comma separated list like "org1,org2"

echo "📝 Step 1: Generating genesis block using ${PROFILE_NAME} profile..."
docker exec -e FABRIC_CFG_PATH=/opt/gopath/src/github.com/hyperledger/fabric/peer cli configtxgen -profile "${PROFILE_NAME}" \
  -outputBlock "/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block" \
  -channelID "${CHANNEL_NAME}"

# 2. Join Orderer(s) to Channel via osnadmin (INSIDE CLI)
echo "🗳️  Step 2: Joining Orderer(s) to the new channel..."
# We discover orderers via their directories in the mount
for ord_dir in "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers"/*; do
    [ -d "$ord_dir" ] || continue
    ORD_NAME=$(basename "$ord_dir")
    
    echo "   Joining ${ORD_NAME} on port 7053 (internal)..."
    docker exec cli osnadmin channel join --channelID "${CHANNEL_NAME}" \
      --config-block "channel-artifacts/${CHANNEL_NAME}.block" \
      -o "${ORD_NAME}:7053" \
      --ca-file "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" \
      --client-cert "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt" \
      --client-key "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"
done

# 3. Join Peers to Channel (INSIDE CLI)
echo "🔗 Step 3: Joining Peers..."
for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
    [ -d "$org_dir" ] || continue
    ORG_DOMAIN=$(basename "$org_dir")
    ORG_NAME=$(echo "$ORG_DOMAIN" | cut -d. -f1) # e.g. org1
    ORG_NUM=$(echo "$ORG_DOMAIN" | grep -o "[0-9]\+" || echo 1)
    MSP_ID="Org${ORG_NUM}MSP"
    
    # Filter by ORGS_TO_JOIN if provided
    if [ -n "$ORGS_TO_JOIN" ]; then
        if [[ ! ",$ORGS_TO_JOIN," =~ ",$ORG_NAME," ]]; then
            echo "   Skipping Organization ${ORG_NAME} (not in join list)..."
            continue
        fi
    fi

    for peer_dir in "${org_dir}/peers"/*; do
        [ -d "$peer_dir" ] || continue
        PEER_NAME=$(basename "$peer_dir")
        
        echo "   Joining ${PEER_NAME} (${MSP_ID})..."
        
        docker exec \
          -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
          -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
          -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp" \
          -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/peers/${PEER_NAME}/tls/ca.crt" \
          cli peer channel join -b "channel-artifacts/${CHANNEL_NAME}.block"
    done
done

echo "✅ [SUCCESS] Channel '${CHANNEL_NAME}' has been provisioned and joined by all members."
echo "📍 Note: You can now deploy chaincode to this channel using mass-approve.sh / mass-commit.sh."
