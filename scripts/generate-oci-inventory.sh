#!/usr/bin/env bash

set -euo pipefail

TERRAFORM_DIR="/Users/ma/oci-terraform-lab"
OUTPUT_FILE="/Users/ma/ansible/inventory/oci.ini"

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

terraform -chdir="$TERRAFORM_DIR" output -json ansible_hosts > "$TMP_JSON"

python3 - "$TMP_JSON" "$OUTPUT_FILE" <<'PY'
import json
import sys

json_file = sys.argv[1]
output_file = sys.argv[2]

with open(json_file, encoding="utf-8") as f:
    hosts = json.load(f)

required_hosts = {
    "oci-ansible01",
    "oci-ansible02",
    "oci-ansible03",
}

missing = required_hosts - set(hosts)
if missing:
    raise SystemExit(
        "ERROR: Missing Terraform hosts: " + ", ".join(sorted(missing))
    )

with open(output_file, "w", encoding="utf-8") as f:
    f.write("# Generated from Terraform. Do not edit manually.\n")
    f.write("# Source: /Users/ma/oci-terraform-lab\n\n")

    f.write("[oci]\n")
    for name in sorted(hosts):
        data = hosts[name]
        f.write(
            f"{name} "
            f"ansible_host={data['ansible_host']} "
            f"ansible_user={data['ansible_user']} "
            f"ansible_python_interpreter=/usr/bin/python3\n"
        )

    f.write("\n[appservers]\n")
    f.write("oci-ansible01\n")

    f.write("\n[nagios_server]\n")
    f.write("oci-ansible02\n")

    f.write("\n[oci_database]\n")
    f.write("oci-ansible03\n")

    f.write("\n[monitored_hosts:children]\n")
    f.write("appservers\n")
    f.write("oci_database\n")

print(f"Generated: {output_file}")
PY
