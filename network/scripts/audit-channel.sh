#!/bin/bash
# network/scripts/audit-channel.sh
# Governance Inspector: Generates a comprehensive report of channel configuration, 
# organization membership, anchor peers, and chaincode lifecycle status.

set -e

CHANNEL_NAME=${1:-mychannel}
NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${NETWORK_DIR}/channel-artifacts"

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "\n${BOLD}${CYAN}🧐 [GOVERNANCE] Inspecting Channel: ${CHANNEL_NAME}${NC}"
echo "--------------------------------------------------------------------------------"

# 1. Fetch Current Config
echo -ne "📥 Fetching latest channel configuration... "
docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer channel fetch config "channel-artifacts/audit_config.pb" -o orderer.example.com:7050 -c "${CHANNEL_NAME}" --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt > /dev/null 2>&1

docker exec cli configtxlator proto_decode --input "channel-artifacts/audit_config.pb" --type common.Block | jq .data.data[0].payload.data.config > "${ARTIFACTS_DIR}/audit_config.json"
echo -e "${GREEN}DONE${NC}"

# 2. Extract Membership
echo -e "\n${BOLD}${YELLOW}🏛️  Organization Membership & Anchors${NC}"
printf "%-15s | %-30s | %-10s\n" "MSP ID" "Anchor Peer" "Status"
echo "--------------------------------------------------------------------------------"

# Get Orgs from .channel_group.groups.Application.groups
ORGS=$(cat "${ARTIFACTS_DIR}/audit_config.json" | jq -r '.channel_group.groups.Application.groups | keys[]')

for mspid in $ORGS; do
    # Check for Anchor Peers
    ANCHOR=$(cat "${ARTIFACTS_DIR}/audit_config.json" | jq -r ".channel_group.groups.Application.groups.${mspid}.values.AnchorPeers.value.anchor_peers[0] // empty")
    
    if [ -z "$ANCHOR" ]; then
        STATUS="${RED}⚠️ MISSING${NC}"
        ANCHOR_STR="None"
    else
        HOST=$(echo "$ANCHOR" | jq -r '.host')
        PORT=$(echo "$ANCHOR" | jq -r '.port')
        STATUS="${GREEN}✅ SYNCED${NC}"
        ANCHOR_STR="${HOST}:${PORT}"
    fi
    printf "%-15s | %-30s | %b\n" "$mspid" "$ANCHOR_STR" "$STATUS"
done

# 3. Channel Governance Policies
echo -e "\n${BOLD}${YELLOW}⚖️  Channel Governance Policies (Application Layer)${NC}"
printf "%-25s | %-30s\n" "Policy Name" "Rule / Requirement"
echo "--------------------------------------------------------------------------------"

# Extract ImplicitMeta policies
POLICIES=$(cat "${ARTIFACTS_DIR}/audit_config.json" | jq -c '.channel_group.groups.Application.policies | to_entries[]')

echo "$POLICIES" | while read -r p; do
    PNAME=$(echo "$p" | jq -r '.key')
    PTYPE=$(echo "$p" | jq -r '.value.policy.type')
    
    if [ "$PTYPE" == "3" ]; then # ImplicitMeta
        RULE=$(echo "$p" | jq -r '.value.policy.value.rule')
        SUB=$(echo "$p" | jq -r '.value.policy.value.sub_policy')
        # Handle both numeric and string decodings
        case $RULE in
            0|ANY) RULE_STR="ANY ${SUB}" ;;
            1|ALL) RULE_STR="ALL ${SUB}" ;;
            2|MAJORITY) RULE_STR="MAJORITY ${SUB}" ;;
            *) RULE_STR="${RULE} ${SUB}" ;;
        esac
    else
        RULE_STR="Signature-based"
    fi
    printf "%-25s | %-30s\n" "$PNAME" "$RULE_STR"
done

# 4. Chaincode Lifecycle Status
echo -e "\n${BOLD}${YELLOW}📦 Chaincode Definitions${NC}"
printf "%-15s | %-10s | %-10s | %-30s\n" "Name" "Version" "Sequence" "Endorsement Policy"
echo "--------------------------------------------------------------------------------"

# Query committed chaincodes
COMMITTED=$(docker exec \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
  cli peer lifecycle chaincode querycommitted --channelID "${CHANNEL_NAME}" --output json || echo '{"chaincode_definitions":[]}')

echo "$COMMITTED" | jq -c '.chaincode_definitions[] // empty' | while read -r cc; do
    NAME=$(echo "$cc" | jq -r '.name')
    VER=$(echo "$cc" | jq -r '.version')
    SEQ=$(echo "$cc" | jq -r '.sequence')
    
    # Try to decode endorsement policy if it's not the default
    VPARAM=$(echo "$cc" | jq -r '.validation_parameter')
    # Default policy fingerprint (for mychannel)
    DEFAULT_FINGERPRINT="EiAvQ2hhbm5lbC9BcHBsaWNhdGlvbi9FbmRvcnNlbWVudA=="
    
    if [ "$VPARAM" == "$DEFAULT_FINGERPRINT" ]; then
        POLICY="Channel Default (Majority)"
    else
        # If it's custom, we show a simplified decoded string
        DECODED=$(echo "$VPARAM" | base64 -d 2>/dev/null || echo "Unknown")
        # Extract MSP IDs found in the binary blob
        MSPS=$(echo "$DECODED" | grep -oE 'Org[0-9]+MSP' | sort -u | tr '\n' ',' | sed 's/,$//')
        if [ -n "$MSPS" ]; then
            POLICY="Custom: OR(${MSPS})"
        else
            POLICY="Custom (Opaque)"
        fi
    fi
    printf "%-15s | %-10s | %-10s | %-30s\n" "$NAME" "$VER" "$SEQ" "$POLICY"
done

# 5. Consensus Snapshot (Raft)
echo -e "\n${BOLD}${YELLOW}🗳️  Consensus Metadata (RAFT Consenters)$NC"
CONSENTERS=$(cat "${ARTIFACTS_DIR}/audit_config.json" | jq -c '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[]')

i=1
echo "$CONSENTERS" | while read -r consenter; do
    HOST=$(echo "$consenter" | jq -r '.host')
    PORT=$(echo "$consenter" | jq -r '.port')
    echo -e "Node $i: ${CYAN}${HOST}:${PORT}${NC}"
    i=$((i+1))
done

echo -e "\n${BOLD}--------------------------------------------------------------------------------${NC}"
echo -e "📍 Governance audit complete for ${BOLD}${CHANNEL_NAME}${NC}."
rm -f "${ARTIFACTS_DIR}/audit_config.pb" "${ARTIFACTS_DIR}/audit_config.json"
