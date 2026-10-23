#!/usr/bin/env bash

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$REPO_DIR" || exit 1

echo
echo "========================================"
echo " LAB VM shutdown"
echo "========================================"
echo

RUNNING_HOSTS=()

echo "Sprawdzam uruchomione hosty..."
echo

while read -r host; do
    [[ -z "$host" ]] && continue

    printf "  %-15s " "$host"

    if ansible "$host" \
        -m ansible.builtin.ping \
        -o >/dev/null 2>&1; then

        echo "ONLINE"
        RUNNING_HOSTS+=("$host")
    else
        echo "OFFLINE"
    fi

done < <(
    ansible all --list-hosts 2>/dev/null \
        | tail -n +2 \
        | sed 's/^[[:space:]]*//'
)

echo

if [[ ${#RUNNING_HOSTS[@]} -eq 0 ]]; then
    echo "Brak uruchomionych maszyn."
    exit 0
fi

echo "Hosty do wyłączenia:"
printf '  - %s\n' "${RUNNING_HOSTS[@]}"

echo
read -r -p "Wyłączyć wszystkie powyższe VM? [y/N]: " answer

case "$answer" in
    y|Y|yes|YES)
        ;;
    *)
        echo "Anulowano."
        exit 0
        ;;
esac

echo
echo "Wysyłam polecenie wyłączenia..."
echo

for host in "${RUNNING_HOSTS[@]}"; do
    printf "  %-15s " "$host"

    if ansible "$host" \
        -b \
        -m ansible.builtin.command \
        -a "systemctl poweroff --no-block" \
        -o >/dev/null 2>&1; then

        echo "shutdown wysłany"
    else
        echo "UWAGA: nie udało się wysłać polecenia"
    fi
done

echo
echo "========================================"
echo " Polecenia wyłączenia zostały wysłane"
echo "========================================"
