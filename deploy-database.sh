#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Użycie: $0 <host>"
  echo "Przykład: $0 database02"
  exit 1
fi

TARGET_HOST="$1"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTGRES_PLAYBOOK="$REPO_DIR/postgresql_role.yml"
REMOTE_TEST_PLAYBOOK="$REPO_DIR/postgresql_remote_test.yml"

echo "========================================"
echo " PostgreSQL LAB deployment"
echo " Host: $TARGET_HOST"
echo "========================================"
echo

cd "$REPO_DIR"

if ! ansible "$TARGET_HOST" --list-hosts 2>/dev/null \
  | grep -q 'hosts (1):'; then
  echo "ERROR: Host '$TARGET_HOST' nie istnieje w inventory."
  exit 1
fi

if ! ansible database --list-hosts 2>/dev/null \
  | grep -qE "^[[:space:]]+$TARGET_HOST$"; then
  echo "ERROR: Host '$TARGET_HOST' nie należy do grupy [database]."
  exit 1
fi

echo "[0/6] Kontrola wstępna hosta..."

echo "  - Sprawdzam połączenie Ansible..."
ansible "$TARGET_HOST" \
  -m ansible.builtin.ping

echo
echo "  - Sprawdzam uprawnienia sudo..."
ansible "$TARGET_HOST" \
  -b \
  -m ansible.builtin.command \
  -a 'id -u' \
  | grep -q '0$'

echo
echo "Pre-check: OK"

echo
echo "[1/6] Sprawdzanie składni Ansible..."

ansible-playbook "$POSTGRES_PLAYBOOK" --syntax-check
ansible-playbook "$REMOTE_TEST_PLAYBOOK" --syntax-check

echo
echo "[2/6] Provisioning PostgreSQL..."

ansible-playbook "$POSTGRES_PLAYBOOK" \
  --limit "$TARGET_HOST"

echo
echo "[3/6] Lokalna weryfikacja PostgreSQL..."

ansible "$TARGET_HOST" \
  -b \
  -m ansible.builtin.shell \
  -a "systemctl is-active postgresql && ss -lnt | grep ':5432'"

echo
echo "[4/6] Zdalna weryfikacja dostępu do PostgreSQL..."

REMOTE_TEST_HOST=""

while read -r host; do
  [[ -z "$host" ]] && continue

  echo "  - Sprawdzam klienta testowego: $host"

  if ansible "$host" \
    -m ansible.builtin.ping \
    -o >/dev/null 2>&1; then

    REMOTE_TEST_HOST="$host"
    break
  fi
done < <(
  ansible db_clients --list-hosts 2>/dev/null \
    | tail -n +2 \
    | sed 's/^[[:space:]]*//'
)

if [[ -z "$REMOTE_TEST_HOST" ]]; then
  echo "ERROR: Brak osiągalnego hosta w grupie [db_clients]."
  exit 1
fi

echo "  - Klient testowy: $REMOTE_TEST_HOST"

echo
echo "[5/6] Dołączanie hosta do monitoringu LAB..."

echo "  - Instalacja i konfiguracja Node Exporter..."
ansible-playbook "$REPO_DIR/node_exporter.yml" \
  --limit "$TARGET_HOST"

echo
echo "  - Odświeżanie konfiguracji Nagios..."
ansible-playbook "$REPO_DIR/nagios.yml"

echo
echo "  - Odświeżanie konfiguracji Prometheus..."
ansible-playbook "$REPO_DIR/prometheus.yml"

echo
echo "[6/6] Podsumowanie..."

echo
echo "========================================"
echo " PostgreSQL deployment zakończony"
echo " Host: $TARGET_HOST"
echo " Monitoring: skonfigurowany"
echo "========================================"
