#!/bin/bash
# network/scripts/network-health.sh
# Diagnostic tool to check ledger heights and synchronization across all organizations.

CHANNEL_NAME=${1:-mychannel}
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Define Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}🔍 Scanning Network Health for Channel: ${CHANNEL_NAME}${NC}"
echo "--------------------------------------------------------------------------------"
printf "%-30s | %-10s | %-15s | %-10s\n" "PEER" "STATUS" "HEIGHT" "SYNC"
echo "--------------------------------------------------------------------------------"

# 1. Discover all active peer containers
PEERS=$(docker ps --format "{{.Names}}" | grep "^peer" | grep example.com | sort)

if [ -z "$PEERS" ]; then
    echo -e "${RED}❌ No peer containers found. Is the network running?${NC}"
    exit 1
fi

# 2. Find the Maximum Height (Target)
MAX_HEIGHT=0
declare -A PEER_HEIGHTS

for PEER in $PEERS; do
    # Extract Org info for environment variables
    # Expected format: peer0.org1.example.com
    ORG_PART=$(echo $PEER | cut -d. -f2)
    ORG_NUM=$(echo $ORG_PART | grep -o '[0-9]\+' | head -n 1)
    MSP_ID="Org${ORG_NUM}MSP"
    ORG_DOMAIN=$(echo $PEER | cut -d. -f2-4)
    
    # Get info using CLI container but pointing to this peer
    # We use the CLI container because it has all the admin certs mapped already
    RESULT=$(docker exec \
      -e CORE_PEER_ADDRESS="${PEER}:7051" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp" \
      -e CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/peers/${PEER}/tls/ca.crt" \
      cli peer channel getinfo -c "${CHANNEL_NAME}" 2>/dev/null)

    if [ $? -eq 0 ]; then
        HEIGHT=$(echo $RESULT | grep -o '"height":[0-9]*' | cut -d: -f2)
        PEER_HEIGHTS[$PEER]=$HEIGHT
        if [ "$HEIGHT" -gt "$MAX_HEIGHT" ]; then
            MAX_HEIGHT=$HEIGHT
        fi
    else
        PEER_HEIGHTS[$PEER]="OFFLINE"
    fi
done

# 3. Report Results
for PEER in $PEERS; do
    HEIGHT=${PEER_HEIGHTS[$PEER]}
    
    if [ "$HEIGHT" == "OFFLINE" ]; then
        printf "%-30s | ${RED}%-10s${NC} | %-15s | %-10s\n" "$PEER" "DOWN" "N/A" "❌"
    elif [ "$HEIGHT" -lt "$MAX_HEIGHT" ]; then
        DIFF=$((MAX_HEIGHT - HEIGHT))
        printf "%-30s | ${GREEN}%-10s${NC} | %-15s | ${YELLOW}%-10s${NC}\n" "$PEER" "UP" "$HEIGHT" "LAG($DIFF)"
    else
        printf "%-30s | ${GREEN}%-10s${NC} | %-15s | ${GREEN}%-10s${NC}\n" "$PEER" "UP" "$HEIGHT" "OK"
    fi
done

echo "--------------------------------------------------------------------------------"
echo -e "${BOLD}Target Height: $MAX_HEIGHT${NC}"

if [ "$MAX_HEIGHT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Target height is 0. Check if channel '${CHANNEL_NAME}' exists.${NC}"
fi
