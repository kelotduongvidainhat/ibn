#!/bin/bash
# network/scripts/upgrade-cc.sh
# Automatically increments version/sequence and upgrades chaincode across all orgs.

set -e

CC_NAME=${1:-basic}
CHANNEL_NAME=${2:-mychannel}
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"

echo "📦 [UPGRADE] Initiating atomic upgrade for chaincode: ${CC_NAME} on ${CHANNEL_NAME}..."

# 1. Detect current lifecycle state
echo "🔍 Querying current chaincode definition..."
# We use Org1 as the reference for the query
CURRENT_INFO=$(docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer lifecycle chaincode querycommitted --channelID "${CHANNEL_NAME}" --name "${CC_NAME}" --output json || echo "{}")

# Parse Version and Sequence
CUR_VER=$(echo "$CURRENT_INFO" | jq -r '.version // "0.0"')
CUR_SEQ=$(echo "$CURRENT_INFO" | jq -r '.sequence // "0"')

if [ "$CUR_SEQ" == "0" ]; then
    echo "❌ Error: Chaincode '${CC_NAME}' is not committed on ${CHANNEL_NAME}. Use mass-approve/commit for initial deploy."
    exit 1
fi

# 2. Calculate next state
# Increment version (simple minor version increment)
MAJOR=$(echo "$CUR_VER" | cut -d. -f1)
MINOR=$(echo "$CUR_VER" | cut -d. -f2)
[ -z "$MINOR" ] && MINOR=0
NEXT_VER="${MAJOR}.$((MINOR + 1))"
NEXT_SEQ=$((CUR_SEQ + 1))

echo "📈 Current: v${CUR_VER} (Seq ${CUR_SEQ}) --> Target: v${NEXT_VER} (Seq ${NEXT_SEQ})"

# 3. Handle Packaging (CaaS Style)
echo "🛠️  Repackaging CaaS chaincode..."
LABEL="${CC_NAME}_${NEXT_VER}"
PACKAGE_NAME="${LABEL}.tar.gz"

# Update metadata.json label
jq ".label = \"${LABEL}\"" "${NETWORK_DIR}/packaging/metadata.json" > "${NETWORK_DIR}/packaging/metadata.json.tmp" && mv "${NETWORK_DIR}/packaging/metadata.json.tmp" "${NETWORK_DIR}/packaging/metadata.json"

# Create package inside packaging directory
cd "${NETWORK_DIR}/packaging"
tar -czf code.tar.gz connection.json
tar -czf "${PACKAGE_NAME}" metadata.json code.tar.gz
cd - > /dev/null

# 4. Install across all Organizations
echo "🚚 Installing new package on all peers..."
ORGS_DIRS=$(ls -d "${NETWORK_DIR}/organizations/peerOrganizations/"* 2>/dev/null)
for ORG_DIR in $ORGS_DIRS; do
    DOMAIN=$(basename "$ORG_DIR")
    ORG_NUM=$(echo $DOMAIN | grep -o '[0-9]\+' | head -n 1)
    [ -z "$ORG_NUM" ] && continue
    MSP_ID="Org${ORG_NUM}MSP"
    
    echo "   Installing for ${MSP_ID}..."
    docker exec \
      -e CORE_PEER_ADDRESS="peer0.${DOMAIN}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls/ca.crt" \
      cli peer lifecycle chaincode install "packaging/${PACKAGE_NAME}"
done

# 5. Extract new Package ID
echo "🔍 Detecting new Package ID for label ${LABEL}..."
PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "Label: ${LABEL}" | sed 's/Package ID: //; s/, Label:.*$//')

if [ -z "$PACKAGE_ID" ]; then
    echo "❌ Error: Could not detect Package ID for label ${LABEL}"
    exit 1
fi
echo "🔗 New Package ID: ${PACKAGE_ID}"
echo "$PACKAGE_ID" > "${NETWORK_DIR}/packaging/package_id.txt"

# 6. Atomic Multi-Org Rollout
echo "🚀 Triggering multi-org approval flow..."
"${SCRIPTS_DIR}/mass-approve.sh" "${CC_NAME}" "${NEXT_VER}" "${NEXT_SEQ}" "${CHANNEL_NAME}"

echo "🏁 Triggering global commit..."
"${SCRIPTS_DIR}/mass-commit.sh" "${CC_NAME}" "${NEXT_VER}" "${NEXT_SEQ}" "${CHANNEL_NAME}"

echo "✅ [SUCCESS] Chaincode '${CC_NAME}' upgraded to v${NEXT_VER} (Sequence ${NEXT_SEQ})."
