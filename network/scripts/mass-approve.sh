#!/bin/bash
# network/scripts/mass-approve.sh
# Automates chaincode approval across all organizations in the network.

CC_NAME=${1:-basic}
CC_VERSION=${2:-1.0}
CC_SEQUENCE=${3:-1}
CHANNEL_NAME=${4:-mychannel}

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_ID_FILE="${NETWORK_DIR}/packaging/package_id.txt"

# Define Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}🗳️  Starting Mass Approval for Chaincode: ${CC_NAME} (v${CC_VERSION}, seq ${CC_SEQUENCE})${NC}"

if [ ! -f "$PACKAGE_ID_FILE" ]; then
    echo -e "${RED}❌ Error: package_id.txt not found in ${NETWORK_DIR}/packaging/${NC}"
    exit 1
fi

PACKAGE_ID=$(cat "$PACKAGE_ID_FILE")
echo "📦 Using Package ID: ${PACKAGE_ID}"
echo "--------------------------------------------------------------------------------"

# Discover all organizations
ORGS_DIRS=$(ls -d "${NETWORK_DIR}/organizations/peerOrganizations/"* 2>/dev/null)

for ORG_DIR in $ORGS_DIRS; do
    DOMAIN=$(basename "$ORG_DIR")
    # Extract Org number/name for MSP ID
    ORG_NUM=$(echo $DOMAIN | grep -o '[0-9]\+' | head -n 1)
    if [ -z "$ORG_NUM" ]; then continue; fi
    
    MSP_ID="Org${ORG_NUM}MSP"
    echo -ne "✍️  Approving for ${BOLD}${MSP_ID}${NC} (${DOMAIN})... "

    docker exec \
      -e CORE_PEER_ADDRESS="peer0.${DOMAIN}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls/ca.crt" \
      cli peer lifecycle chaincode approveformyorg \
        --channelID "${CHANNEL_NAME}" \
        --name "${CC_NAME}" \
        --version "${CC_VERSION}" \
        --package-id "${PACKAGE_ID}" \
        --sequence "${CC_SEQUENCE}" \
        --tls \
        --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
        --waitForEvent

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
done

echo "--------------------------------------------------------------------------------"
echo -e "${BOLD}🔍 Checking Commit Readiness...${NC}"
docker exec cli peer lifecycle chaincode checkcommitreadiness \
    --channelID "${CHANNEL_NAME}" --name "${CC_NAME}" --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" --output json --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
