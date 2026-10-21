#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Użycie: $0 <host>"
  echo "Przykład: $0 rhel02"
  exit 1
fi

TARGET_HOST="$1"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_DIR/applications/hello-wildfly"
BUILD_INFO_SCRIPT="$APP_DIR/generate-build-info.sh"
PLAYBOOK="$REPO_DIR/wildfly_role.yml"

echo
echo "========================================"
echo " WildFly Lab Deployment"
echo "========================================"
echo
echo "Target: $TARGET_HOST"
echo

cd "$REPO_DIR"

if ! ansible "$TARGET_HOST" --list-hosts 2>/dev/null \
  | grep -q 'hosts (1):'; then
  echo "ERROR: Host '$TARGET_HOST' nie istnieje w inventory."
  exit 1
fi

echo "[0/5] Kontrola wstępna hosta..."

echo "  - Sprawdzam połączenie Ansible..."
ansible "$TARGET_HOST" \
  -m ansible.builtin.ping

echo "  - Sprawdzam uprawnienia sudo..."
ansible "$TARGET_HOST" \
  -b \
  -K \
  -m ansible.builtin.command \
  -a 'id -u' \
  | grep -q '0$'

echo "Pre-check: OK"
echo

echo "[1/5] Generowanie metadanych buildu..."
"$BUILD_INFO_SCRIPT"

echo
echo "[2/5] Budowanie aplikacji..."
mvn -B -f "$APP_DIR/pom.xml" clean verify

echo
echo "[3/5] Sprawdzanie artefaktu WAR..."
test -f "$APP_DIR/target/hello-wildfly.war"

jar tf "$APP_DIR/target/hello-wildfly.war" \
  | grep -Fx 'WEB-INF/classes/build-info.properties' >/dev/null

echo "WAR: OK"

echo
echo "[4/5] Sprawdzanie składni Ansible..."
ansible-playbook "$PLAYBOOK" --syntax-check

echo
echo "[5/5] Deployment i weryfikacja..."
ansible-playbook "$PLAYBOOK" \
  -K \
  --limit "$TARGET_HOST"

echo
echo "========================================"
echo " Deployment zakończony pomyślnie"
echo " Host: $TARGET_HOST"
echo "========================================"
