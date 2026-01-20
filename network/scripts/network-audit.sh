#!/bin/bash
# network/scripts/network-audit.sh
# Performs resource snapshots and delta calculations (RAM/Storage/Topology).

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'

CHECKPOINT_FILE=".network_state_checkpoint"

# Utility to convert sizes to bytes
to_bytes() {
    local size=$1
    local unit=$(echo "$size" | grep -o -E '[a-zA-Z]+')
    local num=$(echo "$size" | grep -o -E '[0-9.]+')
    
    case ${unit^^} in
        K|KB|KIB) echo "$(echo "$num * 1024" | bc | cut -d. -f1)" ;;
        M|MB|MIB) echo "$(echo "$num * 1024 * 1024" | bc | cut -d. -f1)" ;;
        G|GB|GIB) echo "$(echo "$num * 1024 * 1024 * 1024" | bc | cut -d. -f1)" ;;
        *) echo "$(echo "$num" | cut -d. -f1)" ;;
    esac
}

# Utility to convert bytes to human readable
to_human() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" -eq 0 ]; then echo "0 B"; return; fi
    units=("B" "KB" "MB" "GB" "TB")
    unit_idx=0
    while (( $(echo "$bytes > 1024" | bc -l) )) && [ $unit_idx -lt 4 ]; do
        bytes=$(echo "scale=2; $bytes / 1024" | bc)
        ((unit_idx++))
    done
    echo "$bytes ${units[$unit_idx]}"
}

get_current_state() {
    # 1. Container Count
    local cnt=$(docker ps --format "{{.Names}}" | grep -E "peer|ca_|orderer|cli|chaincode|couchdb|ipfs|backend|org[0-9]" | wc -l)
    
    # 2. Total RAM Usage
    local ram_sum=0
    local containers=$(docker ps --format "{{.Names}}" | grep -E "peer|ca_|orderer|cli|chaincode|couchdb|ipfs|backend|org[0-9]")
    if [ -n "$containers" ]; then
        while read -r mem; do
            local b=$(to_bytes "$mem")
            ram_sum=$(echo "$ram_sum + $b" | bc)
        done < <(docker stats --no-stream --format "{{.MemUsage}}" $containers | awk '{print $1}')
    fi
    
    # 3. Host Storage (Artifacts & Certs)
    local host_storage=$(du -sb network/organizations channel-artifacts chaincode/pkg 2>/dev/null | awk '{sum+=$1} END {print sum}')
    host_storage=${host_storage:-0}

    # 4. Ledger Storage (Simulated via Volume count * estimated base)
    # Note: Accessing volume sizes directly usually requires root. 
    # We will use the number of active volumes as a proxy for "Managed Objects".
    local vol_count=$(docker volume ls -q | grep -E "fabric|wallet" | wc -l)

    echo "$cnt|$ram_sum|$host_storage|$vol_count"
}

checkpoint() {
    echo -e "${CYAN}📸 Taking Network State Snapshot...${NC}"
    get_current_state > "$CHECKPOINT_FILE"
    echo -e "${GREEN}✅ Checkpoint saved to $CHECKPOINT_FILE${NC}"
}

diff() {
    if [ ! -f "$CHECKPOINT_FILE" ]; then
        echo -e "${RED}❌ No checkpoint found. Run 'checkpoint' first.${NC}"
        exit 1
    fi

    local prev_state=$(cat "$CHECKPOINT_FILE")
    local curr_state=$(get_current_state)

    IFS='|' read -r p_cnt p_ram p_host p_vol <<< "$prev_state"
    IFS='|' read -r c_cnt c_ram c_host c_vol <<< "$curr_state"

    echo -e "${BOLD}⚖️  Network Resource Delta Analysis${NC}"
    echo "--------------------------------------------------------------------------------"
    printf "${BOLD}%-20s | %-15s | %-15s | %-15s${NC}\n" "RESOURCE" "PREVIOUS" "CURRENT" "DELTA"
    echo "--------------------------------------------------------------------------------"

    # Delta Helpers
    calc_delta() {
        local diff=$(echo "$2 - $1" | bc)
        if [ "$diff" -gt 0 ]; then echo -e "${RED}+$diff${NC}"; elif [ "$diff" -lt 0 ]; then echo -e "${GREEN}$diff${NC}"; else echo "0"; fi
    }
    
    calc_delta_human() {
        local diff=$(echo "$2 - $1" | bc)
        local h=$(to_human "${diff#-}")
        if [ "$diff" -gt 0 ]; then echo -e "${RED}+$h 📈${NC}"; elif [ "$diff" -lt 0 ]; then echo -e "${GREEN}-$h 📉${NC}"; else echo "0"; fi
    }

    printf "%-20s | %-15s | %-15s | %-15s\n" "Active Containers" "$p_cnt" "$c_cnt" "$(calc_delta "$p_cnt" "$c_cnt")"
    printf "%-20s | %-15s | %-15s | %-15s\n" "RAM Utilization" "$(to_human "$p_ram")" "$(to_human "$c_ram")" "$(calc_delta_human "$p_ram" "$c_ram")"
    printf "%-20s | %-15s | %-15s | %-15s\n" "Host Storage" "$(to_human "$p_host")" "$(to_human "$c_host")" "$(calc_delta_human "$p_host" "$c_host")"
    printf "%-20s | %-15s | %-15s | %-15s\n" "Data Volumes" "$p_vol" "$c_vol" "$(calc_delta "$p_vol" "$c_vol")"
    echo "--------------------------------------------------------------------------------"
}

case $1 in
    checkpoint|snap) checkpoint ;;
    diff|audit) diff ;;
    *) echo "Usage: $0 {checkpoint|diff}" ;;
esac
