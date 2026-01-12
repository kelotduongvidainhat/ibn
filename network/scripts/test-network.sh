#!/bin/bash
# network/scripts/test-network.sh
# Checks the health and connectivity of the Fabric network.

echo "=== Fabric Network Health Check ==="

# 1. Check Containers
echo "--- Docker Container Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "peer|orderer|cli"

# 2. Check Channel Involvement
echo "--- Peer Channel List ---"
docker exec cli peer channel list

# 3. Check Orderer Participation
echo "--- Orderer Participation Status ---"
docker exec cli osnadmin channel list \
  -o orderer.example.com:7053 \
  --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
  --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
  --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

# 4. Check Gossip/Endpoints
echo "--- Peer Node Status (Gossip) ---"
docker exec cli peer node status

echo "Health Check Complete."
