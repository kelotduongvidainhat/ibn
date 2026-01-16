#!/bin/bash
# network/scripts/policy-gen.sh
# Dynamic Endorsement Policy Generator for the IBN Platform.
# Generates Fabric signature policy strings based on the current organization registry.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORGS_DIR="${PROJECT_ROOT}/network/config/orgs"

TYPE=$1
shift # Remaining args could be specific orgs if needed, or we use all app orgs

# 1. Collect all App Orgs (Excluding Orderer/Org0)
# We look for files like Org1MSP.yaml, Org2MSP.yaml...
APP_ORGS=$(ls "${ORGS_DIR}"/Org[1-9]*.yaml 2>/dev/null | xargs grep -h "ID:" | awk '{print $2}' | sort -u)
ORG_COUNT=$(echo "$APP_ORGS" | wc -l)

if [ "$ORG_COUNT" -eq 0 ]; then
    echo "❌ Error: No application organizations found in registry."
    exit 1
fi

# Convert list to array for easy manipulation
ORGS_ARRAY=($APP_ORGS)

# Helper: Format as peer role list
# Returns: 'Org1MSP.peer', 'Org2MSP.peer'...
function format_peers() {
    local list=""
    for msp in $APP_ORGS; do
        list+="'${msp}.peer', "
    done
    echo "${list%, }"
}

PEER_LIST=$(format_peers)

case $TYPE in
    "ALL")
        # AND('Org1MSP.peer', 'Org2MSP.peer', ...)
        echo "AND(${PEER_LIST})"
        ;;
    "ANY")
        # OR('Org1MSP.peer', 'Org2MSP.peer', ...)
        echo "OR(${PEER_LIST})"
        ;;
    "MAJORITY")
        # OutOf(N, ...) where N is ceil((count+1)/2)
        # For 1: 1, For 2: 2, For 3: 2, For 4: 3, For 5: 3
        # Logic: N = (count / 2) + 1
        THRESHOLD=$(( (ORG_COUNT / 2) + 1 ))
        echo "OutOf(${THRESHOLD}, ${PEER_LIST})"
        ;;
    "ANY_2")
        # OutOf(2, ...)
        if [ "$ORG_COUNT" -lt 2 ]; then
            echo "OR(${PEER_LIST})" # Failback to ANY if only 1 org
        else
            echo "OutOf(2, ${PEER_LIST})"
        fi
        ;;
    "VETO")
        # AND('Org1MSP.peer', OutOf(MAJ-1, others...))
        # Requires Org1 AND a majority of the rest
        if [ "$ORG_COUNT" -le 1 ]; then
            echo "AND(${PEER_LIST})"
        else
            OTHERS=$(echo "$APP_ORGS" | grep -v "Org1MSP")
            OTHERS_LIST=""
            for m in $OTHERS; do OTHERS_LIST+="'${m}.peer', "; done
            OTHERS_LIST=${OTHERS_LIST%, }
            
            # Majority of the rest
            REST_COUNT=$(echo "$OTHERS" | wc -l)
            REST_THRESHOLD=$(( (REST_COUNT / 2) + 1 ))
            
            if [ -z "$OTHERS_LIST" ]; then
                echo "AND('Org1MSP.peer')"
            else
                echo "AND('Org1MSP.peer', OutOf(${REST_THRESHOLD}, ${OTHERS_LIST}))"
            fi
        fi
        ;;
    *)
        # Default back to standard Majority if type unknown
        THRESHOLD=$(( (ORG_COUNT / 2) + 1 ))
        echo "OutOf(${THRESHOLD}, ${PEER_LIST})"
        ;;
esac
