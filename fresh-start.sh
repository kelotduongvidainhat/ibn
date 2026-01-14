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

echo -e "${BOLD}${CYAN}💥 STARTING TOTAL NETWORK RESET (MONOTONIC GOVERNANCE)${NC}"
echo "--------------------------------------------------------------------------------"

# 0. Governance & Config Reset
echo -e "${BOLD}Step 0: Deep Cleaning Governance & Configs${NC}"
# Clear all audit logs and history to restart Org counter
rm -rf "${PROJECT_ROOT}/docs/logs/"*
mkdir -p "${PROJECT_ROOT}/docs/logs"

# Reset configtx.yaml to Base (Org1 + Orderer only)
python3 <<EOF
import yaml
path = '${PROJECT_ROOT}/network/configtx.yaml'
with open(path, 'r') as f:
    d = yaml.safe_load(f)
# Keep only OrdererOrg and Org1MSP in the main Organizations list
d['Organizations'] = [o for o in d['Organizations'] if o.get('ID') in ['OrdererMSP', 'Org1MSP']]
with open(path, 'w') as f:
    yaml.dump(d, f, default_flow_style=False, sort_keys=False)
EOF

# Reset docker-compose.yaml to Base
python3 <<EOF
import yaml
path = '${PROJECT_ROOT}/network/docker-compose.yaml'
with open(path, 'r') as f:
    d = yaml.safe_load(f)
# Whitelist of core services
core = ['ca_orderer', 'ca_org1', 'orderer.example.com', 'peer0.org1.example.com', 'couchdb0', 'cli', 'chaincode-basic', 'backend']
d['services'] = {k: v for k, v in d['services'].items() if k in core}
# Whitelist core volumes
core_vols = ['orderer.example.com', 'peer0.org1.example.com']
d['volumes'] = {k: v for k, v in d['volumes'].items() if k in core_vols}
with open(path, 'w') as f:
    yaml.dump(d, f, default_flow_style=False, sort_keys=False)
EOF

# 1. Primary Bootstrap (Org1 + Orderer)
echo -e "\n${BOLD}Step 1: Initial Bootstrap (Org1 + Orderer)${NC}"
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
    echo -e "\n${BOLD}${CYAN}Step 3.$((i-1)): Provisioning next Organization...${NC}"
    "${SCRIPTS_DIR}/add-org.sh"
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
