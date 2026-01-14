#!/bin/bash
# network/scripts/bootstrap-ca.sh
set -e

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${NETWORK_DIR}/scripts"
export COMPOSE_PROJECT_NAME=fabric

echo "==== STARTING FABRIC CA BOOTSTRAP ===="

# 1. Full Cleanup
echo "--- Stopping and cleaning network ---"
docker compose -f "${NETWORK_DIR}/compose/docker-compose-base.yaml" -f "${NETWORK_DIR}/compose/docker-compose-org1.yaml" down --volumes --remove-orphans || true
docker run --rm -v "${NETWORK_DIR}:/network" alpine sh -c "rm -rf /network/organizations/* /network/channel-artifacts/*"

# Ensure directories exist and are owned by current user
mkdir -p "${NETWORK_DIR}/organizations"
mkdir -p "${NETWORK_DIR}/channel-artifacts"
sudo chown -R $(id -u):$(id -g) "${NETWORK_DIR}/organizations"
sudo chown -R $(id -u):$(id -g) "${NETWORK_DIR}/channel-artifacts"

# 2. Start CAs
echo "--- Launching CA containers ---"
docker compose -f "${NETWORK_DIR}/compose/docker-compose-base.yaml" -f "${NETWORK_DIR}/compose/docker-compose-org1.yaml" up -d ca_org1 ca_orderer

# 3. Wait for CAs to be healthy
echo "--- Waiting for CAs to initialize ---"
max_retries=15
counter=0
while [ ! -f "${NETWORK_DIR}/organizations/fabric-ca/org1/tls-cert.pem" ]; do
    if [ $counter -eq $max_retries ]; then
        echo "CAs failed to start"
        exit 1
    fi
    echo "Waiting for CAs... ($((counter+1))/$max_retries)"
    sleep 2
    counter=$((counter+1))
done
sleep 2

# Fix permissions again after CA containers created files
sudo chown -R $(id -u):$(id -g) "${NETWORK_DIR}/organizations"

# 4. Enroll Identities
echo "--- Running enrollment script ---"
"${SCRIPTS_DIR}/enroll-identities.sh"

# 5. Generate Channel Artifacts
echo "--- Generating Genesis Block ---"
export FABRIC_CFG_PATH="${NETWORK_DIR}"
"${NETWORK_DIR}/../bin/configtxgen" -profile Org1Channel -outputBlock "${NETWORK_DIR}/channel-artifacts/mychannel.block" -channelID mychannel

# 6. Start Rest of Network
echo "--- Launching Orderer, Peer, and CLI ---"
docker compose -f "${NETWORK_DIR}/compose/docker-compose-base.yaml" -f "${NETWORK_DIR}/compose/docker-compose-org1.yaml" up -d orderer.example.com peer0.org1.example.com couchdb0 cli

# 7. Wait for nodes
echo "--- Waiting for network nodes (10s) ---"
sleep 10

# 8. Channel Participation
echo "--- Joining Orderer to mychannel ---"
# Using the service name from within CLI container
docker exec cli osnadmin channel join \
  --channelID mychannel \
  --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block \
  -o orderer.example.com:7053 \
  --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
  --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
  --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

echo "--- Joining Peer to mychannel ---"
docker exec cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block

echo "==== CA BOOTSTRAP COMPLETE ===="
docker exec cli peer channel list
