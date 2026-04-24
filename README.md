# Kong Enterprise API Platform Example

This repository is a compact reference project for the stack you described:

- Kong Konnect / Gateway control plane and data plane concepts
- Kong services, routes, plugins, and rate-limiting strategies
- Enterprise API security with OIDC, JWT, and mTLS
- OpenAPI 3.x contracts with versioning and lifecycle governance
- AWS infrastructure automation in both CDK (TypeScript) and Terraform
- A small Go upstream service with unit tests

## What Is Included

- [services/orders-api](./services/orders-api): a small Go API with health, orders, and caller-context endpoints.
- [openapi/orders-api.json](./openapi/orders-api.json): OpenAPI 3.1 contract for the sample API.
- [kong/kong.json](./kong/kong.json): declarative Kong Gateway configuration showing:
  - `openid-connect` for human users
  - `jwt` for partner/service access
  - `mtls-auth` for high-trust routes
  - `rate-limiting-advanced` with Redis
  - `rate-limiting` with local counters
- [kong/konnect-control-plane.json](./kong/konnect-control-plane.json): decK/Konnect-oriented control plane state.
- [docs/api-governance.md](./docs/api-governance.md): versioning, lifecycle, and policy rules.
- [docs/architecture.md](./docs/architecture.md): platform architecture overview.
- [infra/cdk](./infra/cdk): CDK TypeScript deployment example for ECS/Fargate-hosted Kong data planes and the upstream API.
- [infra/terraform](./infra/terraform): Terraform alternative for the same deployment shape.

## Repo Layout

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

## Security Model

The sample API uses different gateway controls by audience:

- Public human traffic hits `/v1/orders` and is protected by OIDC plus Redis-backed rate limiting.
- Partner traffic hits `/partner/v1/orders` and is protected by JWT plus local rate limiting.
- High-trust debugging or operational traffic hits `/v1/caller` and is protected by mTLS and ACLs.

The upstream Go service assumes Kong has already authenticated the caller and therefore reads trusted identity headers such as `X-Consumer-Username`, `X-Authenticated-Scope`, and `X-Client-Cert-Subject`.

## Running What Is Local

### Run unit tests

```bash
npm test
```

That runs:

- Node-based governance/config validation tests in [test](./test)
- Go unit tests in [services/orders-api](./services/orders-api)

### Run the Go service directly

```bash
cd services/orders-api
go run ./cmd/server
```

Then call:

```bash
curl http://localhost:8080/healthz
curl -H 'X-Tenant-ID: tenant-a' http://localhost:8080/v1/orders
curl \
  -H 'X-Consumer-Username: partner-app' \
  -H 'X-Authenticated-Scope: orders:read orders:write' \
  -H 'X-Client-Cert-Subject: CN=partner-app,O=Example Corp' \
  http://localhost:8080/v1/caller
```

## Kong Workflow

Use the declarative config as the source of truth for service and route policy.

### Gateway config

- [kong/kong.json](./kong/kong.json) is the example self-managed declarative state.
- [kong/konnect-control-plane.json](./kong/konnect-control-plane.json) shows the control-plane state you would sync with decK for Konnect.

Example sync commands:

```bash
deck gateway sync kong/konnect-control-plane.json
deck gateway validate kong/konnect-control-plane.json
```

## CDK Deployment

The CDK example deploys:

- A VPC
- An ECS cluster with Cloud Map service discovery
- A private `orders-api` Fargate service
- A public Kong data plane Fargate service behind an ALB
- Secrets Manager references for the Konnect data plane client certificate and key

Typical workflow:

```bash
cd infra/cdk
npm install
npm test
npm run synth
```

Useful environment variables:

```bash
export PROJECT_NAME=kong-platform
export ENVIRONMENT=dev
export AWS_REGION=ap-southeast-2
export KONNECT_CONTROL_PLANE_HOST=cp.konnect.example.com
export KONNECT_TELEMETRY_HOST=telemetry.konnect.example.com
export KONNECT_CLIENT_CERT_SECRET_NAME=konnect/dp/client-cert
export KONNECT_CLIENT_KEY_SECRET_NAME=konnect/dp/client-key
```

## Terraform Deployment

The Terraform example provisions the same high-level shape: VPC, ECS, ALB, Cloud Map, and Fargate services for Kong plus the sample upstream.

Typical workflow:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform test
terraform plan
```

## Why This Project Is Structured This Way

This is intentionally a reference implementation, not a production-ready platform module. The goal is to show how the concerns fit together:

- API contract and lifecycle rules live with the code.
- Kong policy is declarative and testable.
- Application code is small and easily verified.
- Infrastructure can be expressed in either CDK TypeScript or Terraform depending on team preference.

