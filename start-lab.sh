#!/usr/bin/env bash

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$REPO_DIR" || exit 1

if [[ $# -eq 0 ]]; then
    echo "Użycie: $0 <host1> [host2 ...]"
    echo
    echo "Przykład:"
    echo "  $0 oracle01 database02 tomcat01"
    exit 1
fi

echo
echo "========================================"
echo " LAB VM startup"
echo "========================================"
echo

TARGETS=("$@")

declare -a STARTED_HOSTS=()
declare -a ALREADY_ONLINE=()
declare -a FAILED_HOSTS=()

for host in "${TARGETS[@]}"; do

    echo "Host: $host"

    #
    # Inventory validation
    #

    if ! ansible "$host" --list-hosts 2>/dev/null \
        | grep -q 'hosts (1):'; then

        echo "  ERROR: host nie istnieje w inventory"
        FAILED_HOSTS+=("$host")
        echo
        continue
    fi

    #
    # Already online?
    #

    if ansible "$host" \
        -m ansible.builtin.ping \
        -o >/dev/null 2>&1; then

        echo "  ONLINE - pomijam uruchamianie"
        ALREADY_ONLINE+=("$host")
        echo
        continue
    fi

    #
    # VM exists in UTM?
    #

    if ! utmctl list \
        | awk 'NR > 1 { $1=""; $2=""; sub(/^ +/, ""); print }' \
        | grep -Fxq "$host"; then

        echo "  ERROR: nie znaleziono VM '$host' w UTM"
        FAILED_HOSTS+=("$host")
        echo
        continue
    fi

    #
    # Start VM
    #

    echo "  Uruchamiam VM..."

    utmctl start --hide "$host" 2>/dev/null || true

    STARTED_HOSTS+=("$host")
    echo "  start: wysłany"


    echo
done

#
# Wait for Ansible
#

if [[ ${#STARTED_HOSTS[@]} -gt 0 ]]; then

    echo "========================================"
    echo " Oczekiwanie na gotowość hostów"
    echo "========================================"
    echo

    for host in "${STARTED_HOSTS[@]}"; do

        printf "  %-15s " "$host"

        READY=0

        for attempt in {1..30}; do

            if ansible "$host" \
                -m ansible.builtin.ping \
                -o >/dev/null 2>&1; then

                READY=1
                break
            fi

            sleep 2
        done

        if [[ "$READY" -eq 1 ]]; then
            echo "ONLINE"
        else
            echo "TIMEOUT"
            FAILED_HOSTS+=("$host")
        fi
    done
fi

echo
echo "========================================"
echo " Podsumowanie"
echo "========================================"

if [[ ${#ALREADY_ONLINE[@]} -gt 0 ]]; then
    echo
    echo "Już uruchomione:"
    printf '  - %s\n' "${ALREADY_ONLINE[@]}"
fi

if [[ ${#STARTED_HOSTS[@]} -gt 0 ]]; then
    echo
    echo "Uruchomione przez skrypt:"
    printf '  - %s\n' "${STARTED_HOSTS[@]}"
fi

if [[ ${#FAILED_HOSTS[@]} -gt 0 ]]; then
    echo
    echo "Problemy:"
    printf '  - %s\n' "${FAILED_HOSTS[@]}"
    echo
    exit 1
fi

echo
echo "Wszystkie wybrane hosty są dostępne."
echo
