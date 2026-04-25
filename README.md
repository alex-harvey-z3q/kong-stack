# Kong Enterprise API Platform Example

A reference project for building and operating a Kong-based API platform with:

- Kong Konnect control plane and Kong Gateway data planes
- OpenAPI-driven API design and lifecycle governance
- Enterprise API security with OIDC, JWT, and mTLS
- AWS infrastructure automation in CDK (TypeScript) and Terraform
- A small Go upstream service used as the demo backend

## What This Repo Demonstrates

This repo models a common enterprise setup:

- Konnect hosts the control plane.
- Kong data planes run on AWS ECS/Fargate.
- Kong routes traffic to an internal Go service.
- API policy is managed declaratively.
- Infrastructure can be provisioned with either CDK or Terraform.

The example is intentionally compact. It is meant to show how the parts fit together, not to be a production-ready platform module.

## Repository Overview

- [services/orders-api](./services/orders-api): sample Go service with health, orders, and caller-context endpoints.
- [openapi/orders-api.json](./openapi/orders-api.json): OpenAPI 3.1 contract for the demo API.
- [kong/kong.json](./kong/kong.json): example Kong declarative configuration.
- [kong/konnect-control-plane.json](./kong/konnect-control-plane.json): Konnect-oriented declarative state.
- [docs/api-governance.md](./docs/api-governance.md): API versioning and lifecycle expectations.
- [docs/architecture.md](./docs/architecture.md): high-level reference architecture.
- [infra/cdk](./infra/cdk): CDK deployment example.
- [infra/terraform](./infra/terraform): Terraform deployment example.

## Architecture Summary

The sample API uses different gateway controls by audience:

- `/v1/orders`: OIDC plus Redis-backed rate limiting
- `/partner/v1/orders`: JWT plus local rate limiting
- `/v1/caller`: mTLS plus ACLs

The upstream Go service assumes Kong has already authenticated the caller and reads trusted gateway headers such as:

- `X-Consumer-Username`
- `X-Authenticated-Scope`
- `X-Client-Cert-Subject`

## Quick Start

### Run local checks

```bash
npm test
```

This runs:

- Node-based governance and config validation tests in [test](./test)
- Go unit tests in [services/orders-api](./services/orders-api)

### Run the full local check suite

```bash
npm run check
```

This includes:

- tests
- OpenAPI validation
- Kong config validation

### Run the Go service locally

```bash
cd services/orders-api
go run ./cmd/server
```

Example requests:

```bash
curl http://localhost:8080/healthz
curl -H 'X-Tenant-ID: tenant-a' http://localhost:8080/v1/orders
curl \
  -H 'X-Consumer-Username: partner-app' \
  -H 'X-Authenticated-Scope: orders:read orders:write' \
  -H 'X-Client-Cert-Subject: CN=partner-app,O=Example Corp' \
  http://localhost:8080/v1/caller
```

## Konnect And AWS Setup

This project expects a Konnect-managed control plane and a self-hosted Kong data plane deployed in AWS.

### 1. Create the gateway in Konnect

In Konnect UI:

1. Open `API Gateway`.
2. Click `New Gateway`.
3. Choose `Self-managed`.
4. Choose `Docker` or `Linux (Docker)`.
5. Name the gateway `kong-platform-dev`.
6. Open the new gateway and click `Connect`.
7. Generate the certificate and script for the data plane.

The generated script is the source of truth for the values you need. In particular, capture:

- `KONG_CLUSTER_CONTROL_PLANE`
- `KONG_CLUSTER_TELEMETRY_ENDPOINT`
- `KONG_CLUSTER_CERT`
- `KONG_CLUSTER_CERT_KEY`

You do not need to run the generated Docker command locally unless you want a quick smoke test.

### 2. Export the Konnect environment variables

Take the values from the generated script and remove the trailing `:443` from the control plane and telemetry endpoints.

```bash
export PROJECT_NAME=kong-platform
export ENVIRONMENT=dev
export AWS_REGION=ap-southeast-2
export KONNECT_CONTROL_PLANE_HOST='YOUR_CONTROL_PLANE_HOST'
export KONNECT_TELEMETRY_HOST='YOUR_TELEMETRY_HOST'
export KONNECT_CLIENT_CERT_SECRET_NAME='konnect/dp/client-cert'
export KONNECT_CLIENT_KEY_SECRET_NAME='konnect/dp/client-key'
```

Example:

```bash
export KONNECT_CONTROL_PLANE_HOST='example.au.cp.konghq.com'
export KONNECT_TELEMETRY_HOST='example.au.tp.konghq.com'
```

### 3. Store the data plane certificate and key in Secrets Manager

Create two local PEM files from the Konnect output.

`konnect-dp-cert.pem`

```pem
-----BEGIN CERTIFICATE-----
PASTE_THE_CLIENT_CERT_FROM_KONNECT_HERE
-----END CERTIFICATE-----
```

`konnect-dp-key.pem`

```pem
-----BEGIN PRIVATE KEY-----
PASTE_THE_CLIENT_PRIVATE_KEY_FROM_KONNECT_HERE
-----END PRIVATE KEY-----
```

Create the secrets:

```bash
aws secretsmanager create-secret \
  --region "$AWS_REGION" \
  --name "$KONNECT_CLIENT_CERT_SECRET_NAME" \
  --secret-string file://konnect-dp-cert.pem

aws secretsmanager create-secret \
  --region "$AWS_REGION" \
  --name "$KONNECT_CLIENT_KEY_SECRET_NAME" \
  --secret-string file://konnect-dp-key.pem
```

If the secrets already exist, update them instead:

```bash
aws secretsmanager put-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$KONNECT_CLIENT_CERT_SECRET_NAME" \
  --secret-string file://konnect-dp-cert.pem

aws secretsmanager put-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$KONNECT_CLIENT_KEY_SECRET_NAME" \
  --secret-string file://konnect-dp-key.pem
```

Verify them:

```bash
aws secretsmanager describe-secret \
  --region "$AWS_REGION" \
  --secret-id "$KONNECT_CLIENT_CERT_SECRET_NAME"

aws secretsmanager describe-secret \
  --region "$AWS_REGION" \
  --secret-id "$KONNECT_CLIENT_KEY_SECRET_NAME"
```

### 4. Security note

If the private key was pasted into chat, screenshots, or any other place you do not fully control, regenerate the Konnect data plane certificate and update the two secrets before deployment.

## Kong Configuration Workflow

Use the declarative config in this repo as the source of truth for services, routes, and plugins.

Files:

- [kong/kong.json](./kong/kong.json): self-managed declarative config example
- [kong/konnect-control-plane.json](./kong/konnect-control-plane.json): Konnect-oriented config

Example sync commands:

```bash
deck gateway validate kong/konnect-control-plane.json
deck gateway sync kong/konnect-control-plane.json
```

## Deploy With CDK

The CDK example provisions:

- a VPC
- an ECS cluster with Cloud Map
- a private `orders-api` service
- a public Kong data plane behind an ALB
- Secrets Manager references for the Konnect certificate and key

### CDK workflow

```bash
cd infra/cdk
npm install
npm test
npm run typecheck
npm run synth
```

Deploy:

```bash
cd infra/cdk
npx cdk bootstrap aws://ACCOUNT_ID/$AWS_REGION
npx cdk diff
npx cdk deploy
```

The CDK stack expects these environment variables to already be set:

```bash
export PROJECT_NAME=kong-platform
export ENVIRONMENT=dev
export AWS_REGION=ap-southeast-2
export KONNECT_CONTROL_PLANE_HOST='YOUR_CONTROL_PLANE_HOST'
export KONNECT_TELEMETRY_HOST='YOUR_TELEMETRY_HOST'
export KONNECT_CLIENT_CERT_SECRET_NAME='konnect/dp/client-cert'
export KONNECT_CLIENT_KEY_SECRET_NAME='konnect/dp/client-key'
```

## Deploy With Terraform

The Terraform example provisions the same high-level topology: VPC, ECS, ALB, Cloud Map, and Fargate services for Kong and the sample upstream.

### Terraform workflow

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Populate `terraform.tfvars` with:

- Konnect control plane host
- Konnect telemetry host
- Secrets Manager ARN for the client cert
- Secrets Manager ARN for the client key

## Repository Layout

```text
.
├── docs/
├── infra/
│   ├── cdk/
│   └── terraform/
├── kong/
├── openapi/
├── scripts/
├── services/
│   └── orders-api/
└── test/
```

## Why This Structure

The repository is organized so that the key concerns stay close together:

- API contracts and governance live with the source.
- Kong policy is versioned and testable.
- The demo service is small and easy to validate.
- Infrastructure is available in both CDK and Terraform.
