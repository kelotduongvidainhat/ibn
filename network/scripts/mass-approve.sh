#!/bin/bash
# network/scripts/mass-approve.sh
# Automates chaincode approval across all organizations in the network.

CC_NAME=${1:-basic}
CC_VERSION=${2:-1.0}
CC_SEQUENCE=${3:-1}
CHANNEL_NAME=${4:-mychannel}
CC_POLICY=$5

POLICY_ARGS=()
if [ -n "$CC_POLICY" ]; then
    POLICY_ARGS=("--signature-policy" "${CC_POLICY}")
    echo "⚖️  Using Custom Policy: ${CC_POLICY}"
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_ID_FILE="${NETWORK_DIR}/packaging/package_id.txt"

# Define Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}🗳️  Starting Mass Approval for Chaincode: ${CC_NAME} (v${CC_VERSION}, seq ${CC_SEQUENCE})${NC}"

# --- VERIFIED mTLS PARAMETERS FOR CLI ---
# These variables ensure the CLI presents its identity to mTLS-enabled peers.
export CLI_MTLS_ARGS="-e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_TLS_CLIENTAUTHREQUIRED=true \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/tls/client.crt \
  -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/tls/client.key \
  -e CORE_PEER_TLS_CLIENTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/tls/client.crt \
  -e CORE_PEER_TLS_CLIENTKEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/tls/client.key"

if [ ! -f "$PACKAGE_ID_FILE" ]; then
    echo -e "${RED}❌ Error: package_id.txt not found in ${NETWORK_DIR}/packaging/${NC}"
    exit 1
fi

PACKAGE_ID=$(cat "$PACKAGE_ID_FILE")
echo "📦 Using Package ID: ${PACKAGE_ID}"
echo "--------------------------------------------------------------------------------"

# Discover all organizations
ORGS_DIRS=$(ls -d "${NETWORK_DIR}/organizations/peerOrganizations/"* 2>/dev/null)

# Check for collections config
COLLECTIONS_CONFIG="${NETWORK_DIR}/packaging/collections_config.json"
COLLECTIONS_ARGS=()
if [ -f "$COLLECTIONS_CONFIG" ]; then
    COLLECTIONS_ARGS=("--collections-config" "packaging/collections_config.json")
    echo "🔐 Using Collections Config: ${COLLECTIONS_CONFIG}"
fi

for ORG_DIR in $ORGS_DIRS; do
    DOMAIN=$(basename "$ORG_DIR")
    ORG_NUM=$(echo $DOMAIN | grep -o '[0-9]\+' | head -n 1)
    MSP_ID="Org${ORG_NUM}MSP"
    
    # Try to find a peer from this org that is joined to the channel
    TARGET_PEER=""
    for peer_dir in "${ORG_DIR}/peers"/*; do
        [ -d "$peer_dir" ] || continue
        PEER_NAME=$(basename "$peer_dir")
        
        IS_JOINED=$(docker exec \
          ${CLI_MTLS_ARGS} \
          -e CORE_PEER_ADDRESS="${PEER_NAME}:7051" \
          -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
          -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
          -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt" \
          cli peer channel list | grep -q "^${CHANNEL_NAME}$" && echo "yes" || echo "no")

        if [ "$IS_JOINED" == "yes" ]; then
            TARGET_PEER=$PEER_NAME
            break
        fi
    done

    if [ -z "$TARGET_PEER" ]; then
        echo -e "⏭️  Skipping ${BOLD}${MSP_ID}${NC} (No peers joined to ${CHANNEL_NAME})"
        continue
    fi

    echo -ne "✍️  Approving for ${BOLD}${MSP_ID}${NC} (${DOMAIN}) via ${TARGET_PEER}... "

    docker exec \
      ${CLI_MTLS_ARGS} \
      -e CORE_PEER_ADDRESS="${TARGET_PEER}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${TARGET_PEER}/tls/ca.crt" \
      cli peer lifecycle chaincode approveformyorg \
        --channelID "${CHANNEL_NAME}" \
        --name "${CC_NAME}" \
        --version "${CC_VERSION}" \
        --package-id "${PACKAGE_ID}" \
        --sequence "${CC_SEQUENCE}" \
        "${POLICY_ARGS[@]}" \
        "${COLLECTIONS_ARGS[@]}" \
        --tls \
        --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
        --clientauth \
        --certfile "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/tls/client.crt" \
        --keyfile "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/tls/client.key" \
        --waitForEvent

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
done

echo "--------------------------------------------------------------------------------"
echo -e "${BOLD}🔍 Checking Commit Readiness...${NC}"
docker exec ${CLI_MTLS_ARGS} cli peer lifecycle chaincode checkcommitreadiness \
    --channelID "${CHANNEL_NAME}" --name "${CC_NAME}" --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" "${POLICY_ARGS[@]}" "${COLLECTIONS_ARGS[@]}" --output json --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
    --clientauth \
    --certfile "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/tls/client.crt" \
    --keyfile "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/tls/client.key"
