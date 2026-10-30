#!/bin/bash

WARNING_FREE="${1:-20}"
CRITICAL_FREE="${2:-10}"

if ! [[ "$WARNING_FREE" =~ ^[0-9]+$ && "$CRITICAL_FREE" =~ ^[0-9]+$ ]]; then
    echo "UNKNOWN - memory thresholds must be integers"
    exit 3
fi

if (( CRITICAL_FREE >= WARNING_FREE )); then
    echo "UNKNOWN - critical free memory threshold must be lower than warning threshold"
    exit 3
fi

MEM_TOTAL_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
MEM_AVAILABLE_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

if [[ -z "$MEM_TOTAL_KB" || -z "$MEM_AVAILABLE_KB" || "$MEM_TOTAL_KB" -eq 0 ]]; then
    echo "UNKNOWN - unable to read memory information"
    exit 3
fi

FREE_PERCENT=$(( MEM_AVAILABLE_KB * 100 / MEM_TOTAL_KB ))
USED_PERCENT=$(( 100 - FREE_PERCENT ))

TOTAL_MB=$(( MEM_TOTAL_KB / 1024 ))
AVAILABLE_MB=$(( MEM_AVAILABLE_KB / 1024 ))
USED_MB=$(( TOTAL_MB - AVAILABLE_MB ))

PERFDATA="used=${USED_MB}MB;;;0;${TOTAL_MB} available=${AVAILABLE_MB}MB;;;0;${TOTAL_MB} used_percent=${USED_PERCENT}%;;;0;100"

if (( FREE_PERCENT <= CRITICAL_FREE )); then
    echo "MEMORY CRITICAL - ${FREE_PERCENT}% available (${AVAILABLE_MB} MB of ${TOTAL_MB} MB) | ${PERFDATA}"
    exit 2
elif (( FREE_PERCENT <= WARNING_FREE )); then
    echo "MEMORY WARNING - ${FREE_PERCENT}% available (${AVAILABLE_MB} MB of ${TOTAL_MB} MB) | ${PERFDATA}"
    exit 1
else
    echo "MEMORY OK - ${FREE_PERCENT}% available (${AVAILABLE_MB} MB of ${TOTAL_MB} MB) | ${PERFDATA}"
    exit 0
fi
