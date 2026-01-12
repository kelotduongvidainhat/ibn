#!/bin/bash
# network/scripts/deploy-caas.sh
# Deploys the CaaS chaincode to the network.

set -e

# Configuration
CHANNEL_NAME="mychannel"
CC_NAME="basic"
CC_VERSION="1.0"
CC_SEQUENCE="1"
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_PATH="${NETWORK_DIR}/packaging/${CC_NAME}.tar.gz"

echo "=== Deploying CaaS Chaincode: ${CC_NAME} ==="

# 1. Install Chaincode
echo "--- Installing chaincode package on peer0.org1.example.com ---"
docker exec cli peer lifecycle chaincode install "/opt/gopath/src/github.com/hyperledger/fabric/peer/packaging/${CC_NAME}.tar.gz" >&log.txt
cat log.txt
PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^.*Package ID: //;p;q;}" log.txt)
echo "Package ID: ${PACKAGE_ID}"

# 2. Approve Chaincode
echo "--- Approving chaincode for Org1 ---"
docker exec cli peer lifecycle chaincode approveformyorg \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --package-id "${PACKAGE_ID}" \
  --sequence "${CC_SEQUENCE}"

# 3. Check Commit Readiness
echo "--- Checking commit readiness ---"
docker exec cli peer lifecycle chaincode checkcommitreadiness \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --output json

# 4. Commit Chaincode
echo "--- Committing chaincode definition ---"
docker exec cli peer lifecycle chaincode commit \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}"

# 5. Final Report
echo "--- Chaincode Deployment Complete ---"
echo "Next step: Start the chaincode-basic container with PACKAGE_ID=${PACKAGE_ID}"
echo "${PACKAGE_ID}" > "${NETWORK_DIR}/packaging/package_id.txt"
