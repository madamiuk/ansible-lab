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
from collections import defaultdict

json_file = sys.argv[1]
output_file = sys.argv[2]

with open(json_file, encoding="utf-8") as f:
    hosts = json.load(f)

if not hosts:
    raise SystemExit("ERROR: Terraform returned no Ansible hosts")

groups = defaultdict(list)

for name, data in hosts.items():
    for group in data.get("groups", []):
        groups[group].append(name)

with open(output_file, "w", encoding="utf-8") as f:
    f.write("# Generated from Terraform. Do not edit manually.\n")
    f.write("# Source: /Users/ma/oci-terraform-lab\n\n")

    for group in sorted(groups):
        f.write(f"[{group}]\n")

        for name in sorted(groups[group]):
            if group == "oci":
                data = hosts[name]

                f.write(
                    f"{name} "
                    f"ansible_host={data['ansible_host']} "
                    f"private_ip={data['private_ip']} "
                    f"ansible_user={data['ansible_user']} "
                    f"ansible_python_interpreter=/usr/bin/python3\n"
                )
            else:
                f.write(f"{name}\n")

        f.write("\n")

print(f"Generated: {output_file}")
