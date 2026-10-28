#!/usr/bin/env bash

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$REPO_DIR" || exit 1

echo
echo "========================================"
echo " Notebook VM shutdown"
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
    ansible notebook_vms --list-hosts 2>/dev/null \
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

SHUTDOWN_REQUESTED=()

for host in "${RUNNING_HOSTS[@]}"; do
    printf "  %-15s " "$host"

    if ansible "$host" \
        -b \
        -m ansible.builtin.command \
        -a "systemd-run --on-active=2s systemctl poweroff" \
        -o >/dev/null 2>&1; then

        echo "shutdown zaplanowany"
        SHUTDOWN_REQUESTED+=("$host")
    else
        echo "UWAGA: nie udało się zaplanować shutdown"
    fi
done

echo
echo "Czekam na wyłączenie hostów..."
echo

FAILED_HOSTS=()

for host in "${SHUTDOWN_REQUESTED[@]}"; do
    printf "  %-15s " "$host"

    offline=false

    for attempt in {1..12}; do
      if ! ansible "$host" \
        -m ansible.builtin.ping \
        >/dev/null 2>&1; then

        offline=true
        break
      fi

      sleep 5
    done

    if [[ "$offline" == true ]]; then
      echo "OFFLINE"
    else
      echo "NADAL ONLINE"
      FAILED_HOSTS+=("$host")
    fi
  done

echo
echo "========================================"

if [[ ${#FAILED_HOSTS[@]} -eq 0 ]]; then
    echo " Wszystkie uruchomione VM zostały wyłączone"
    EXIT_CODE=0
else
    echo " Nie wszystkie VM zostały wyłączone"
    echo
    echo " Nadal dostępne:"
    printf '  - %s\n' "${FAILED_HOSTS[@]}"
    EXIT_CODE=1
fi

echo "========================================"
echo

exit "$EXIT_CODE"
