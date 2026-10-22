#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Użycie: $0 <host>"
  echo "Przykład: $0 apache01"
  exit 1
fi

TARGET_HOST="$1"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APACHE_PLAYBOOK="$REPO_DIR/apache_role.yml"

echo "========================================"
echo " Apache LAB deployment"
echo " Host: $TARGET_HOST"
echo "========================================"
echo

cd "$REPO_DIR"

if ! ansible "$TARGET_HOST" --list-hosts 2>/dev/null \
  | grep -q 'hosts (1):'; then
  echo "ERROR: Host '$TARGET_HOST' nie istnieje w inventory."
  exit 1
fi

if ! ansible apache --list-hosts 2>/dev/null \
  | grep -qE "^[[:space:]]+$TARGET_HOST$"; then
  echo "ERROR: Host '$TARGET_HOST' nie należy do grupy [apache]."
  exit 1
fi

echo "[0/5] Kontrola wstępna hosta..."

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
echo "[1/5] Sprawdzanie składni Ansible..."

ansible-playbook "$APACHE_PLAYBOOK" --syntax-check

echo
echo "[2/5] Provisioning Apache..."

ansible-playbook "$APACHE_PLAYBOOK" \
  --limit "$TARGET_HOST"

echo
echo "[3/5] Weryfikacja usługi HTTP..."

TARGET_IP="$(
  ansible-inventory --host "$TARGET_HOST" \
    | python3 -c '
import json
import sys

data = json.load(sys.stdin)
print(data["ansible_host"])
'
)"

echo "  - Host: $TARGET_HOST"
echo "  - IP:   $TARGET_IP"

echo
echo "  - Sprawdzam HTTP..."
curl --fail --silent --show-error \
  "http://$TARGET_IP" \
  | grep -q "Apache skonfigurowany przez Ansible"

echo "  - HTTP: OK"

echo
echo "[4/5] Dołączanie hosta do monitoringu LAB..."

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
echo "[5/5] Podsumowanie..."

echo
echo "========================================"
echo " Apache deployment zakończony"
echo " Host: $TARGET_HOST"
echo " URL:  http://$TARGET_IP"
echo " Monitoring: skonfigurowany"
echo "========================================"
