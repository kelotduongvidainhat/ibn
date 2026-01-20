#!/bin/bash
# network/scripts/revoke-identity.sh
# Performs identity revocation and updates the channel with the new CRL.

set -e

CLIENT_ID=$1
ORG_NAME=$2
CHANNEL_NAME=${3:-mychannel}

if [ -z "$CLIENT_ID" ] || [ -z "$ORG_NAME" ]; then
    echo "Usage: ./network/scripts/revoke-identity.sh <client_id> <org_name> [channel_name]"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"

# --- DYNAMIC CONFIGURATION ---
ORG_NUM=$(echo $ORG_NAME | grep -o '[0-9]\+')
MSP_ID="Org${ORG_NUM}MSP"
DOMAIN="${ORG_NAME}.example.com"

# CA Port logic
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then CA_PORT=10054; elif [ $CA_PORT -ge 10054 ]; then CA_PORT=$((CA_PORT+1000)); fi

CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"
CA_CERT="${CA_HOME}/ca-cert.pem"

echo "📜 [REVOKE] Revoking ${CLIENT_ID} from ${ORG_NAME}..."

# 1. REVOKE via CA
export FABRIC_CA_CLIENT_HOME="${CA_HOME}"
fabric-ca-client revoke -u "https://admin:adminpw@localhost:${CA_PORT}" \
    --caname "ca-${ORG_NAME}" --revoke.name "${CLIENT_ID}" --tls.certfiles "${CA_CERT}"

# 2. GENERATE CRL
echo "⚙️ Generating Certificate Revocation List (CRL)..."
fabric-ca-client gencrl -u "https://admin:adminpw@localhost:${CA_PORT}" \
    --caname "ca-${ORG_NAME}" --tls.certfiles "${CA_CERT}"

# 3. DEPLOY CRL TO MSP
CRL_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/msp/crls"
mkdir -p "${CRL_DIR}"
cp "${CA_HOME}/msp/crls/crl.pem" "${CRL_DIR}/crl.pem"

# 4. UPDATE CHANNEL CONFIGURATION
# We need to inject this CRL into the MSP definition of the channel
echo "💃 Performing the Revocation Admin Dance..."

# First, extract current Org definition in JSON from channel
# We'll use a temporary script to handle the jq injection within CLI
cat > "${NETWORK_DIR}/scripts/internal_config_crl.sh" <<EOF
#!/bin/bash
set -e
CHANNEL=\$1
MSP_ID=\$2
CRL_B64=\$(cat /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${DOMAIN}/msp/crls/crl.pem | base64 -w 0)

peer channel fetch config config_block.pb -c \$CHANNEL -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

# Inject CRL into the specific Org's MSP definition
jq ".channel_group.groups.Application.groups.\"\$MSP_ID\".values.MSP.value.config.revocation_list = [\"\$CRL_B64\"]" config.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output original_config.pb
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id \$CHANNEL --original original_config.pb --updated modified_config.pb --output update.pb
configtxlator proto_decode --input update.pb --type common.ConfigUpdate | jq '{"payload":{"header":{"channel_header":{"channel_id":"'\$CHANNEL'", "type":2}},"data":{"config_update":.}}}' | configtxlator proto_encode --type common.Envelope --output update_in_envelope.pb
EOF

chmod +x "${NETWORK_DIR}/scripts/internal_config_crl.sh"

docker exec cli /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/internal_config_crl.sh "${CHANNEL_NAME}" "${MSP_ID}"

# 5. COLLECT SIGNATURES & SUBMIT
echo "✍️ Collecting signatures and submitting update..."
for org_dir in "${NETWORK_DIR}/organizations/peerOrganizations"/*; do
    [ -d "$org_dir" ] || continue
    EX_ORG_DOMAIN=$(basename "$org_dir")
    EX_ORG_NUM=$(echo $EX_ORG_DOMAIN | grep -o "[0-9]\+" || echo 1)
    EX_MSP_ID="Org${EX_ORG_NUM}MSP"
    
    echo "signing with ${EX_MSP_ID}..."
    docker exec \
      -e CORE_PEER_LOCALMSPID="${EX_MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${EX_ORG_DOMAIN}/users/Admin@${EX_ORG_DOMAIN}/msp" \
      cli peer channel signconfigtx -f update_in_envelope.pb
done

docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer channel update -f update_in_envelope.pb -c "${CHANNEL_NAME}" -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

rm "${NETWORK_DIR}/scripts/internal_config_crl.sh"

echo "✅ [SUCCESS] Identity ${CLIENT_ID} has been revoked and the channel updated with the CRL."
