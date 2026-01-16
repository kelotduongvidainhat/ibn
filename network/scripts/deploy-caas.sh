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
PACKAGE_DIR="${NETWORK_DIR}/packaging"

echo "=== Deploying CaaS Chaincode: ${CC_NAME} ==="

# 1. Dynamic Packaging
echo "--- Dynamically packaging CaaS chaincode (v${CC_VERSION}) ---"
LABEL="${CC_NAME}_${CC_VERSION}"
PACKAGE_NAME="${LABEL}.tar.gz"

cat <<EOF > "${PACKAGE_DIR}/metadata.json"
{"type":"ccaas","label":"${LABEL}"}
EOF

if [ ! -f "${PACKAGE_DIR}/connection.json" ]; then
    echo "{\"address\":\"chaincode-basic:9999\",\"dial_timeout\":\"10s\",\"tls_required\":false}" > "${PACKAGE_DIR}/connection.json"
fi

cd "${PACKAGE_DIR}"
tar -czf code.tar.gz connection.json
tar -czf "${PACKAGE_NAME}" metadata.json code.tar.gz
cd - > /dev/null

# 2. Install Chaincode
echo "--- Installing package ${PACKAGE_NAME} on peer0.org1.example.com ---"
docker exec cli peer lifecycle chaincode install "packaging/${PACKAGE_NAME}" > log.txt 2>&1 || true
cat log.txt

# Extract Package ID from install or queryinstalled
if grep -q "Chaincode code package identifier:" log.txt; then
    PACKAGE_ID=$(grep "Chaincode code package identifier:" log.txt | awk '{print $NF}')
else
    echo "Chaincode likely already installed, querying Package ID..."
    PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "Package ID: ${CC_NAME}_${CC_VERSION}:" | awk '{print $3}' | sed 's/,$//')
fi

echo "Extracted Package ID: ${PACKAGE_ID}"

if [ -z "$PACKAGE_ID" ]; then
    echo "ERROR: Failed to extract Package ID"
    exit 1
fi

# 2. Approve Chaincode
echo "--- Approving chaincode for Org1 ---"
MAX_RETRIES=5
RETRY_COUNT=0
SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    set +e
    docker exec cli peer lifecycle chaincode approveformyorg \
      -o orderer.example.com:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
      --channelID "${CHANNEL_NAME}" \
      --name "${CC_NAME}" \
      --version "${CC_VERSION}" \
      --package-id "${PACKAGE_ID}" \
      --sequence "${CC_SEQUENCE}"
    
    if [ $? -eq 0 ]; then
        SUCCESS=true
        set -e
        break
    else
        RETRY_COUNT=$((RETRY_COUNT+1))
        echo "⚠️ Approval failed (attempt $RETRY_COUNT/$MAX_RETRIES). Waiting for Orderer Raft leader..."
        sleep 5
    fi
    set -e
done

if [ "$SUCCESS" = false ]; then
    echo "❌ ERROR: Failed to approve chaincode after $MAX_RETRIES attempts."
    exit 1
fi

# 3. Check Commit Readiness
echo "--- Checking commit readiness ---"
docker exec cli peer lifecycle chaincode checkcommitreadiness \
  --channelID "${CHANNEL_NAME}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --output json

# 4. Commit Chaincode
"${NETWORK_DIR}/scripts/mass-commit.sh" "${CC_NAME}" "${CC_VERSION}" "${CC_SEQUENCE}" "${CHANNEL_NAME}"

# 5. Final Report
echo "--- Chaincode Deployment Complete ---"
echo "${PACKAGE_ID}" > "${PACKAGE_DIR}/package_id.txt"
echo "Next step: Start the chaincode-basic container with PACKAGE_ID=${PACKAGE_ID}"
