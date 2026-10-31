#!/usr/bin/env bash

set -euo pipefail

REPO="madamiuk/jobtracker"
WORKFLOW="JobTracker CI"
ARTIFACT_NAME="jobtracker-war"

ANSIBLE_DIR="/Users/ma/ansible"
ARTIFACT_DIR="${ANSIBLE_DIR}/artifacts/jobtracker"
WAR_PATH="${ARTIFACT_DIR}/jobtracker.war"
PLAYBOOK="${ANSIBLE_DIR}/jobtracker_deploy.yml"
E2E_PLAYBOOK="${ANSIBLE_DIR}/jobtracker_e2e.yml"

if [[ $# -ge 1 ]]; then
  RUN_ID="$1"
  echo "==> Używam wskazanego JobTracker CI run ID: ${RUN_ID}"
else
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

  echo "==> Znaleziono run ID: ${RUN_ID}"
fi

mkdir -p "${ARTIFACT_DIR}"
rm -f "${ARTIFACT_DIR}"/*

echo "==> Pobieram artifact ${ARTIFACT_NAME} z runu ${RUN_ID}..."

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

if [[ "${RUN_E2E:-false}" == "true" ]]; then
  echo "==> Uruchamiam JobTracker E2E..."

  ansible-playbook \
    "${E2E_PLAYBOOK}"
fi

echo "==> JobTracker deployment zakończony poprawnie."
