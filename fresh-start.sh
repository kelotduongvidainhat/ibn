#!/bin/bash
# fresh-start.sh
# Complete automation to reset and build the a 6-organization network from scratch.

set -e

# Colors for UI
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/network/scripts"

echo -e "${BOLD}${CYAN}💥 STARTING TOTAL NETWORK RESET (3-ORG SCENARIO)${NC}"
echo "--------------------------------------------------------------------------------"

# 1. Primary Bootstrap (Org1 + Orderer)
echo -e "${BOLD}Step 1: Initial Bootstrap (Org1 + Orderer)${NC}"
./network/scripts/bootstrap-ca.sh

# Give the Orderer extra time to settle Raft leadership
echo "⏳ Waiting for Orderer Raft leadership (5s)..."
sleep 5

# 2. Initial Chaincode Deployment (Required to generate package_id.txt)
echo -e "\n${BOLD}Step 2: Initial Chaincode Deployment for Org1${NC}"
./network/scripts/deploy-caas.sh

# 3. Sequential Scaling (Orgs 2 through 3)
echo -e "\n${BOLD}Step 3: Sequential Scaling (Orgs 2 through 3)${NC}"
for i in {2..3}; do
    echo -e "\n${BOLD}${CYAN}Step 3.$((i-1)): Adding Org${i}...${NC}"
    "${SCRIPTS_DIR}/add-org.sh" "$i"
done

# 4. Starting Application Services
echo -e "\n${BOLD}Step 4: Launching CaaS and Backend API${NC}"
docker compose -f network/docker-compose.yaml up -d chaincode-basic backend

# 5. Final Synchronization Check
echo -e "\n${BOLD}Step 5: Verifying Network Health${NC}"
sleep 10
"${SCRIPTS_DIR}/network-health.sh"

echo "--------------------------------------------------------------------------------"
echo -e "${GREEN}${BOLD}✅ FRESH START COMPLETE!${NC}"
echo -e "Backend API: ${BOLD}http://localhost:8080${NC}"
echo -e "Master CLI:  ${BOLD}./ibn-ctl${NC}"
