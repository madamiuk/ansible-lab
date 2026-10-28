#!/usr/bin/env bash

set -euo pipefail

REPO="madamiuk/jobtracker"
WORKFLOW="JobTracker CI"
ARTIFACT_NAME="jobtracker-war"

ANSIBLE_DIR="/Users/ma/ansible"
ARTIFACT_DIR="${ANSIBLE_DIR}/artifacts/jobtracker"
WAR_PATH="${ARTIFACT_DIR}/jobtracker.war"
PLAYBOOK="${ANSIBLE_DIR}/jobtracker_deploy.yml"

echo "==> Szukam najnowszego poprawnego runu JobTracker CI..."

RUN_ID="$(
  gh run list \
    --repo "${REPO}" \
    --workflow "${WORKFLOW}" \
    --branch main \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId'
)"

if [[ -z "${RUN_ID}" || "${RUN_ID}" == "null" ]]; then
  echo "ERROR: Nie znaleziono poprawnego runu JobTracker CI."
  exit 1
fi

echo "==> Run ID: ${RUN_ID}"

mkdir -p "${ARTIFACT_DIR}"
rm -f "${ARTIFACT_DIR}"/*

echo "==> Pobieram artifact ${ARTIFACT_NAME}..."

gh run download "${RUN_ID}" \
  --repo "${REPO}" \
  --name "${ARTIFACT_NAME}" \
  --dir "${ARTIFACT_DIR}"

if [[ ! -f "${WAR_PATH}" ]]; then
  echo "ERROR: Nie znaleziono ${WAR_PATH}"
  exit 1
fi

echo "==> Sprawdzam WAR..."

jar tf "${WAR_PATH}" \
  | grep -q 'WEB-INF/classes/pl/jobtracker/rest/HealthResource.class'

jar tf "${WAR_PATH}" \
  | grep -q 'WEB-INF/classes/META-INF/persistence.xml'

echo "==> WAR poprawny."

echo "==> SHA-256:"
shasum -a 256 "${WAR_PATH}"

echo "==> Uruchamiam deployment przez Ansible..."

cd "${ANSIBLE_DIR}"

ansible-playbook \
  "${PLAYBOOK}" \
  -e jobtracker_build_local=false \
  -e wildfly_war_source="${WAR_PATH}"
