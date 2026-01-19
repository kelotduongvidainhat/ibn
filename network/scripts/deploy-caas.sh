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
echo "--- Installing package ${PACKAGE_NAME} on all peers ---"
ORGS_DIRS=$(ls -d "${NETWORK_DIR}/organizations/peerOrganizations/"* 2>/dev/null)
for ORG_DIR in $ORGS_DIRS; do
    DOMAIN=$(basename "$ORG_DIR")
    ORG_NUM=$(echo $DOMAIN | grep -o '[0-9]\+' | head -n 1)
    [ -z "$ORG_NUM" ] && continue
    MSP_ID="Org${ORG_NUM}MSP"
    
    echo "   Installing for ${MSP_ID} (peer0.${DOMAIN})..."
    docker exec \
      -e CORE_PEER_ADDRESS="peer0.${DOMAIN}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls/ca.crt" \
      cli peer lifecycle chaincode install "packaging/${PACKAGE_NAME}" > install_log.txt 2>&1 || true
    cat install_log.txt
done

# Extract Package ID directly from the last successful install log to ensure uniqueness
# Fabric prints "Chaincode code package identifier: <ID>" upon success
PACKAGE_ID=$(grep "Chaincode code package identifier:" install_log.txt | awk '{print $NF}' | head -n 1)

# Fallback: If install was a "skip" because it already existed, query the latest for THIS version
if [ -z "$PACKAGE_ID" ]; then
    echo "🔍 Package already installed, querying Package ID for ${LABEL}..."
    PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "Package ID: ${LABEL}:" | awk '{print $3}' | sed 's/,$//' | head -n 1)
fi

echo "Extracted Package ID: ${PACKAGE_ID}"
echo "${PACKAGE_ID}" > "${PACKAGE_DIR}/package_id.txt"

if [ -z "$PACKAGE_ID" ]; then
    echo "ERROR: Failed to extract Package ID"
    exit 1
fi

# Sync chaincode/.env for local development and Docker
CC_ENV="${NETWORK_DIR}/../chaincode/.env"
if [ -f "$CC_ENV" ]; then
    sed -i "s/^CHAINCODE_ID=.*/CHAINCODE_ID=${PACKAGE_ID}/" "$CC_ENV"
    echo "✅ Synchronized ${CC_ENV} with new Package ID"
fi

# 3. Approve and Commit across all Orgs
echo "--- Approving and Committing across all organizations ---"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"
"${SCRIPTS_DIR}/mass-approve.sh" "${CC_NAME}" "${CC_VERSION}" "${CC_SEQUENCE}" "${CHANNEL_NAME}"
"${SCRIPTS_DIR}/mass-commit.sh" "${CC_NAME}" "${CC_VERSION}" "${CC_SEQUENCE}" "${CHANNEL_NAME}"

# 5. Final Report
echo "--- Chaincode Deployment Complete ---"
echo "Next step: Start the chaincode-basic container with PACKAGE_ID=${PACKAGE_ID}"
