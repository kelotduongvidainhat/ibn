#!/bin/bash
# network/scripts/mass-commit.sh
# Automates the collection of peer addresses and submission of chaincode commit.

CC_NAME=${1:-basic}
CC_VERSION=${2:-1.0}
CC_SEQUENCE=${3:-1}
CHANNEL_NAME=${4:-mychannel}
CC_POLICY=$5

POLICY_ARGS=()
if [ -n "$CC_POLICY" ]; then
    POLICY_ARGS=("--signature-policy" "${CC_POLICY}")
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Define Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}🚀 Starting Mass Commit for Chaincode: ${CC_NAME} (v${CC_VERSION}, seq ${CC_SEQUENCE})${NC}"
echo "--------------------------------------------------------------------------------"

# 1. Discover all organizations and build the peer address string
PEER_ARGS=""
ORGS_DIRS=$(ls -d "${NETWORK_DIR}/organizations/peerOrganizations/"* 2>/dev/null)

for ORG_DIR in $ORGS_DIRS; do
    DOMAIN=$(basename "$ORG_DIR")
    PEER_NAME="peer0.${DOMAIN}"
    TLS_ROOT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt"
    
    # Append the peer address and its root cert to the argument string
    PEER_ARGS="${PEER_ARGS} --peerAddresses ${PEER_NAME}:7051 --tlsRootCertFiles ${TLS_ROOT}"
    echo "📍 Including Endorser: ${PEER_NAME}"
done

# Check for collections config
COLLECTIONS_CONFIG="${NETWORK_DIR}/packaging/collections_config.json"
COLLECTIONS_ARGS=()
if [ -f "$COLLECTIONS_CONFIG" ]; then
    COLLECTIONS_ARGS=("--collections-config" "packaging/collections_config.json")
    echo "🔐 Including Collections Config in commit"
fi

# 2. Execute the commit via CLI
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer lifecycle chaincode commit \
    -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    "${POLICY_ARGS[@]}" \
    "${COLLECTIONS_ARGS[@]}" \
    ${PEER_ARGS}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SUCCESS: Chaincode '${CC_NAME}' is now committed to ${CHANNEL_NAME}.${NC}"
else
    echo -e "${RED}❌ FAILED: Commit transaction failed. check logs or checkcommitreadiness.${NC}"
    exit 1
fi

echo "--------------------------------------------------------------------------------"
echo -e "${BOLD}🔍 Verifying Committed Status...${NC}"
docker exec cli peer lifecycle chaincode querycommitted --channelID "${CHANNEL_NAME}" --name "${CC_NAME}"
