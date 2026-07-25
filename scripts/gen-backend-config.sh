#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIRS=("v2-remote-state-ssm" "v3-dynamic-inventory")

command -v aws &> /dev/null || { echo "aws CLI not found." >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || { echo "Failed to resolve AWS account ID." >&2; exit 1; }
[[ -n "${ACCOUNT_ID}" ]] || { echo "Empty account ID returned." >&2; exit 1; }

for DIR in "${TARGET_DIRS[@]}"; do
  OUTPUT_FILE="${ROOT_DIR}/${DIR}/backend.hcl"
  cat > "${OUTPUT_FILE}" <<EOF
bucket = "ansible-linux-sandbox-tf-state-${ACCOUNT_ID}"
EOF
  echo "backend.hcl generated at ${OUTPUT_FILE}"
done
