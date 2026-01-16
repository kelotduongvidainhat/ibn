#!/bin/bash
# network/scripts/org-logs.sh
# Aggregates and streams logs for a specific organization's containers.

set -e

ORG_NUM=$1

if [ -z "$ORG_NUM" ]; then
    echo "Usage: ./network/scripts/org-logs.sh <org_num>"
    echo "Example: ./network/scripts/org-logs.sh 1"
    exit 1
fi

ORG_NAME="org${ORG_NUM}"
DOMAIN="${ORG_NAME}.example.com"

# Define Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${YELLOW}📋 [LOGS] Aggregating logs for Organization: ${ORG_NAME}${NC}"
echo "--------------------------------------------------------------------------------"

# Detect containers
PEERS=$(docker ps --format "{{.Names}}" | grep -E "peer[0-9]\.${DOMAIN}")
CA=$(docker ps --format "{{.Names}}" | grep -E "ca_${ORG_NAME}")
COUCH=$(docker ps --format "{{.Names}}" | grep -E "couchdb.*${DOMAIN}")

CONTAINERS="${PEERS} ${CA} ${COUCH}"

if [ -z "$(echo $CONTAINERS | tr -d ' ')" ]; then
    echo -e "❌ No active containers found for ${ORG_NAME}."
    exit 1
fi

echo -e "📡 Streaming: ${CYAN}${CONTAINERS}${NC}"
echo -e "Press Ctrl+C to stop.\n"

# Use docker-compose logs if possible, or manual docker logs
# We use a simple loop with background tailing for better visual prefixing
for c in $CONTAINERS; do
    docker logs --tail 20 -f "$c" 2>&1 | sed "s/^/[$c] /" &
done

# Wait for Ctrl+C
trap "kill 0" EXIT
wait
