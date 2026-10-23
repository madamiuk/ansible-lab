#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Użycie: $0 <host>"
  echo "Przykład: $0 tomcat01"
  exit 1
fi

TARGET_HOST="$1"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_DIR/applications/hello-tomcat"
PLAYBOOK="$REPO_DIR/tomcat_role.yml"

echo
echo "========================================"
echo " Tomcat LAB deployment"
echo " Host: $TARGET_HOST"
echo "========================================"
echo

cd "$REPO_DIR"

#
# Inventory validation
#

if ! ansible "$TARGET_HOST" --list-hosts 2>/dev/null \
  | grep -q 'hosts (1):'; then
  echo "ERROR: Host '$TARGET_HOST' nie istnieje w inventory."
  exit 1
fi

if ! ansible tomcat --list-hosts 2>/dev/null \
  | grep -qE "^[[:space:]]+$TARGET_HOST$"; then
  echo "ERROR: Host '$TARGET_HOST' nie należy do grupy [tomcat]."
  exit 1
fi

#
# Pre-check
#

echo "[0/7] Kontrola wstępna hosta..."

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

#
# Build
#

echo
echo "[1/7] Budowanie aplikacji hello-tomcat..."

mvn -B \
  -f "$APP_DIR/pom.xml" \
  clean verify

#
# WAR verification
#

echo
echo "[2/7] Weryfikacja artefaktu WAR..."

WAR_FILE="$APP_DIR/target/hello-tomcat.war"

if [[ ! -f "$WAR_FILE" ]]; then
  echo "ERROR: Nie znaleziono artefaktu:"
  echo "       $WAR_FILE"
  exit 1
fi

jar tf "$WAR_FILE" \
  | grep -Fx 'WEB-INF/classes/pl/ansible/lab/HelloServlet.class' \
  >/dev/null

echo "WAR: OK"
echo "  - $WAR_FILE"

#
# Ansible syntax
#

echo
echo "[3/7] Sprawdzanie składni Ansible..."

ansible-playbook "$PLAYBOOK" --syntax-check

#
# Provisioning
#

echo
echo "[4/7] Provisioning Tomcat..."

ansible-playbook "$PLAYBOOK" \
  --limit "$TARGET_HOST"

#
# Application verification
#

echo
echo "[5/7] Weryfikacja aplikacji..."

TARGET_IP="$(
  ansible-inventory --host "$TARGET_HOST" \
    | python3 -c '
import json
import sys

data = json.load(sys.stdin)
print(data["ansible_host"])
'
)"

APP_URL="http://$TARGET_IP:8080/hello-tomcat/hello"

echo "  - Host: $TARGET_HOST"
echo "  - IP:   $TARGET_IP"
echo "  - URL:  $APP_URL"

HTTP_RESPONSE="$(
  curl \
    --fail \
    --silent \
    --show-error \
    "$APP_URL"
)"

echo "$HTTP_RESPONSE" \
  | grep -q "Hello from Jakarta Servlet!"

echo "$HTTP_RESPONSE" \
  | grep -q "Apache Tomcat 11"

echo "  - Tomcat HTTP: OK"

#
# Monitoring
#

echo
echo "[6/7] Dołączanie hosta do monitoringu LAB..."

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
echo "Monitoring onboarding: OK"

#
# Summary
#

echo
echo "[7/7] Podsumowanie..."

echo
echo "========================================"
echo " Tomcat deployment zakończony"
echo " Host:       $TARGET_HOST"
echo " URL:        $APP_URL"
echo " Monitoring: skonfigurowany"
echo "========================================"
