#!/usr/bin/env bash

set -euo pipefail

project_name='kong-platform'
environment='dev'
stack_name='kong-platform-dev'
konnect_client_cert_secret_name='konnect/dp/client-cert'
konnect_client_key_secret_name='konnect/dp/client-key'

export AWS_DEFAULT_REGION='ap-southeast-2'

usage() {
  cat <<'USAGE'
Usage:
  ./teardown.sh

This script will:
- destroy the CDK stack for this repo
- delete the two Secrets Manager secrets created by setup.sh
- print the remaining Konnect cleanup steps

The AWS region is fixed to:
  ap-southeast-2
USAGE
}

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
}

delete_secret() {
  local secret_name="$1"

  if aws secretsmanager describe-secret --secret-id "$secret_name" >/dev/null 2>&1; then
    aws secretsmanager delete-secret \
       --secret-id "$secret_name" \
       --force-delete-without-recovery >/dev/null
    echo "Deleted secret: $secret_name"
  else
    echo "Secret not found, skipping: $secret_name"
  fi
}

print_hints() {
  cat <<EOF2
Teardown complete.

Remaining manual cleanup in Konnect:
- delete the 'kong-platform-dev' gateway/control plane if you no longer need it
- revoke the Konnect personal access token you used for decK sync

Optional local cleanup:
unset PROJECT_NAME ENVIRONMENT AWS_REGION
unset KONNECT_CONTROL_PLANE_HOST KONNECT_TELEMETRY_HOST
unset KONNECT_CLIENT_CERT_SECRET_NAME KONNECT_CLIENT_KEY_SECRET_NAME
unset KONNECT_TOKEN DECK_PARTNER_JWT_SECRET PARTNER_JWT
unset KONG_CLUSTER_CONTROL_PLANE KONG_CLUSTER_TELEMETRY_ENDPOINT
unset KONG_CLUSTER_CERT KONG_CLUSTER_CERT_KEY
EOF2
}

main() {
  local repo_root

  if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then
    usage
    exit 0
  fi

  if [[ $# -ne 0 ]]; then
    usage >&2
    exit 1
  fi

  require_cmd aws
  require_cmd npx

  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  echo "Destroying CDK stack: $stack_name"

  (cd "$repo_root/infra/cdk"
   PROJECT_NAME="$project_name" ENVIRONMENT="$environment" AWS_REGION="$AWS_DEFAULT_REGION" npx cdk destroy "$stack_name" --force)

  delete_secret "$konnect_client_cert_secret_name"
  delete_secret "$konnect_client_key_secret_name"

  print_hints
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
