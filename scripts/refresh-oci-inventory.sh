#!/usr/bin/env bash

set -euo pipefail

ANSIBLE_DIR="/Users/ma/ansible"
GENERATOR="${ANSIBLE_DIR}/scripts/generate-oci-inventory.sh"
INVENTORY="${ANSIBLE_DIR}/inventory/oci.ini"

echo
echo "========================================"
echo " OCI inventory refresh"
echo "========================================"
echo

echo "[1/3] Generowanie inventory z Terraform..."
"$GENERATOR"

echo
echo "[2/3] Weryfikacja struktury inventory..."
ansible-inventory \
  -i "$INVENTORY" \
  --graph

echo
echo "[3/3] Test połączenia z hostami OCI..."
ansible all \
  -i "$INVENTORY" \
  -m ansible.builtin.ping

echo
echo "========================================"
echo " OCI inventory gotowe"
echo "========================================"
echo
