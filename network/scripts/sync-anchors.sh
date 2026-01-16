#!/bin/bash
# network/scripts/sync-anchors.sh
# Synchronizes Anchor Peers for an organization on a specific channel.

set -e

ORG_NUM=$1
CHANNEL_NAME=${2:-mychannel}

if [ -z "$ORG_NUM" ]; then
    echo "Usage: ./network/scripts/sync-anchors.sh <org_num> [channel_name]"
    echo "Example: ./network/scripts/sync-anchors.sh 2 mychannel"
    exit 1
fi

ORG_NAME="org${ORG_NUM}"
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"

echo "⚓ [ANCHOR] Synchronizing anchor peers for ${MSP_ID} on channel ${CHANNEL_NAME}..."

# 1. Fetch current config
echo "📥 Fetching latest config block..."
docker exec \
  -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
  cli peer channel fetch config "channel-artifacts/config_block.pb" -o orderer.example.com:7050 -c "${CHANNEL_NAME}" --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

# 2. Decode and Update
echo "🔓 Decoding config and injecting Anchor Peer (peer0.${DOMAIN}:7051)..."
docker exec cli configtxlator proto_decode --input channel-artifacts/config_block.pb --type common.Block | jq .data.data[0].payload.data.config > "${ARTIFACTS_DIR}/config.json"

# Inject anchor peer into the organization's config section
# Logic: .channel_group.groups.Application.groups[MSP_ID].values.AnchorPeers
jq ".channel_group.groups.Application.groups.${MSP_ID}.values += {\"AnchorPeers\": {\"mod_policy\": \"Admins\", \"value\": {\"anchor_peers\": [{\"host\": \"peer0.${DOMAIN}\", \"port\": 7051}]}, \"version\": \"0\"}}" "${ARTIFACTS_DIR}/config.json" > "${ARTIFACTS_DIR}/modified_config.json"

# 3. Compute Delta
echo "📦 Computing configuration delta..."
docker exec cli configtxlator proto_encode --input channel-artifacts/config.json --type common.Config > "${ARTIFACTS_DIR}/config.pb"
docker exec cli configtxlator proto_encode --input channel-artifacts/modified_config.json --type common.Config > "${ARTIFACTS_DIR}/modified_config.pb"
docker exec cli configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original channel-artifacts/config.pb --updated channel-artifacts/modified_config.pb > "${ARTIFACTS_DIR}/config_update.pb"

# 4. Wrap and Submit
echo "✉️  Wrapping and submitting update..."
docker exec cli configtxlator proto_decode --input channel-artifacts/config_update.pb --type common.ConfigUpdate > "${ARTIFACTS_DIR}/config_update.json"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat "${ARTIFACTS_DIR}/config_update.json")'}}}' > "${ARTIFACTS_DIR}/config_update_as_envelope.json"
docker exec cli configtxlator proto_encode --input channel-artifacts/config_update_as_envelope.json --type common.Envelope > "${ARTIFACTS_DIR}/update_in_envelope.pb"

docker exec \
  -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp" \
  cli peer channel update -f channel-artifacts/update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

echo "✅ [SUCCESS] Anchor Peers synchronized for ${MSP_ID}."
