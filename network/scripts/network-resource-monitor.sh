#!/bin/bash
# network/scripts/network-resource-monitor.sh
# Real-time dashboard for monitoring CPU/RAM usage of the Fabric network.

# Define Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Discovery: Get all containers related to our network
CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "peer|ca_|orderer|cli|chaincode" | sort)

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ No network containers found.${NC}"
    exit 1
fi

# Function to display the stats once
show_stats() {
    clear
    echo -e "${BOLD}📊 Hyperledger Fabric Network Resource Monitor${NC}"
    echo -e "Time: $(date)"
    echo "----------------------------------------------------------------------------------------------------------------"
    printf "${CYAN}%-30s | %-10s | %-15s | %-15s | %-10s${NC}\n" "CONTAINER" "CPU %" "MEM USAGE" "MEM LIMIT" "NET I/O"
    echo "----------------------------------------------------------------------------------------------------------------"
    
    # We use docker stats with --no-stream to get a single snapshot
    docker stats --no-stream --format "{{.Name}} | {{.CPUPerc}} | {{.MemUsage}} | {{.NetIO}}" $CONTAINERS | while read -r line; do
        NAME=$(echo "$line" | cut -d'|' -f1 | xargs)
        CPU=$(echo "$line" | cut -d'|' -f2 | xargs)
        MEM_STR=$(echo "$line" | cut -d'|' -f3 | xargs)
        NET=$(echo "$line" | cut -d'|' -f4 | xargs)
        
        USAGE=$(echo "$MEM_STR" | cut -d'/' -f1 | xargs)
        LIMIT=$(echo "$MEM_STR" | cut -d'/' -f2 | xargs)

        # Color coding for CPU
        CPU_VAL=${CPU%\%}
        if (( $(echo "$CPU_VAL > 50.0" | bc -l) )); then CPU_COLOR=$RED; elif (( $(echo "$CPU_VAL > 10.0" | bc -l) )); then CPU_COLOR=$YELLOW; else CPU_COLOR=$GREEN; fi

        printf "%-30s | ${CPU_COLOR}%-10s${NC} | %-15s | %-15s | %-10s\n" "$NAME" "$CPU" "$USAGE" "$LIMIT" "$NET"
    done
    echo "----------------------------------------------------------------------------------------------------------------"
    echo "Press [CTRL+C] to exit."
}

# Trap interrupt to exit gracefully
trap "echo -e '\nMonitor stopped.'; exit" SIGINT

# Main Loop
while true; do
    show_stats
    sleep 10
done
