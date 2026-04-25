#!/usr/bin/env bash
set -euo pipefail

project_name='kong-platform'
environment='dev'
konnect_client_cert_secret_name='konnect/dp/client-cert'
konnect_client_key_secret_name='konnect/dp/client-key'
konnect_control_plane_host=''
konnect_telemetry_host=''

export AWS_DEFAULT_REGION='ap-southeast-2'

usage() {
  cat <<'USAGE'
Usage:
  export KONG_CLUSTER_CONTROL_PLANE='...'
  export KONG_CLUSTER_TELEMETRY_ENDPOINT='...'
  export KONG_CLUSTER_CERT='...'
  export KONG_CLUSTER_CERT_KEY='...'
  ./setup.sh

Required environment variables:
  KONG_CLUSTER_CONTROL_PLANE
  KONG_CLUSTER_TELEMETRY_ENDPOINT
  KONG_CLUSTER_CERT
  KONG_CLUSTER_CERT_KEY

This script will:
- strip :443 from the Konnect endpoints
- create or update the two Secrets Manager secrets used by this repo
- print the export commands needed for CDK deployment

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

strip_port() {
  local value="$1"

  value="${value#https://}"
  value="${value#http://}"
  value="${value%%:*}"

  printf '%s' "$value"
}

upsert_secret() {
  local secret_name="$1"
  local secret_file="$2"

  if aws secretsmanager describe-secret \
    --secret-id "$secret_name" >/dev/null 2>&1; then
    aws secretsmanager put-secret-value \
      --secret-id "$secret_name" \
      --secret-string "file://$secret_file" >/dev/null
    echo "Updated secret: $secret_name"
  else
    aws secretsmanager create-secret \
      --name "$secret_name" \
      --secret-string "file://$secret_file" >/dev/null
    echo "Created secret: $secret_name"
  fi
}

print_hints() {
  cat <<EOF2
Konnect setup complete.

Export these variables before deploying:
export PROJECT_NAME='$project_name'
export ENVIRONMENT='$environment'
export AWS_REGION='$AWS_DEFAULT_REGION'
export KONNECT_CONTROL_PLANE_HOST='$konnect_control_plane_host'
export KONNECT_TELEMETRY_HOST='$konnect_telemetry_host'
export KONNECT_CLIENT_CERT_SECRET_NAME='$konnect_client_cert_secret_name'
export KONNECT_CLIENT_KEY_SECRET_NAME='$konnect_client_key_secret_name'

CDK example:
cd infra/cdk
npx cdk diff
npx cdk deploy
EOF2
}

main() {
  local cluster_control_plane_raw
  local cluster_telemetry_endpoint_raw
  local cluster_cert_raw
  local cluster_cert_key_raw
  local cert_file
  local key_file

  if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then
    usage
    exit 0
  fi

  if [[ $# -ne 0 ]]; then
    usage >&2
    exit 1
  fi

  require_cmd aws
  require_cmd mktemp

  cluster_control_plane_raw="${KONG_CLUSTER_CONTROL_PLANE:?error: KONG_CLUSTER_CONTROL_PLANE must be set}"
  cluster_telemetry_endpoint_raw="${KONG_CLUSTER_TELEMETRY_ENDPOINT:?error: KONG_CLUSTER_TELEMETRY_ENDPOINT must be set}"
  cluster_cert_raw="${KONG_CLUSTER_CERT:?error: KONG_CLUSTER_CERT must be set}"
  cluster_cert_key_raw="${KONG_CLUSTER_CERT_KEY:?error: KONG_CLUSTER_CERT_KEY must be set}"

  konnect_control_plane_host="$(strip_port "$cluster_control_plane_raw")"
  konnect_telemetry_host="$(strip_port "$cluster_telemetry_endpoint_raw")"

  cert_file="$(mktemp)"
  key_file="$(mktemp)"
  trap "rm -f '$cert_file' '$key_file'" EXIT

  printf '%s\n' "$cluster_cert_raw" > "$cert_file"
  printf '%s\n' "$cluster_cert_key_raw" > "$key_file"

  upsert_secret "$konnect_client_cert_secret_name" "$cert_file"
  upsert_secret "$konnect_client_key_secret_name" "$key_file"

  print_hints
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
