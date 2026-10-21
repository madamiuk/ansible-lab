#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel)"
OUTPUT_DIR="$PROJECT_DIR/src/main/resources"
OUTPUT_FILE="$OUTPUT_DIR/build-info.properties"

GIT_COMMIT="${GITHUB_SHA:-$(git -C "$REPO_DIR" rev-parse HEAD)}"
GIT_REF="${GITHUB_REF_NAME:-$(git -C "$REPO_DIR" branch --show-current)}"
GITHUB_RUN_ID_VALUE="${GITHUB_RUN_ID:-local}"
GITHUB_RUN_NUMBER_VALUE="${GITHUB_RUN_NUMBER:-local}"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_FILE" <<EOF
git.commit=${GIT_COMMIT}
git.ref=${GIT_REF}
github.run.id=${GITHUB_RUN_ID_VALUE}
github.run.number=${GITHUB_RUN_NUMBER_VALUE}
EOF

echo "Generated $OUTPUT_FILE"
cat "$OUTPUT_FILE"
