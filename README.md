# Kong Enterprise API Platform Example

#### Table of contents

1. [Introduction](#introduction)
2. [What This Repo Demonstrates](#what-this-repo-demonstrates)
3. [Repository Overview](#repository-overview)
4. [Architecture Summary](#architecture-summary)
5. [Dependencies](#dependencies)
6. [Quick Start](#quick-start)
    * [Run local checks](#run-local-checks)
    * [Run the full local check suite](#run-the-full-local-check-suite)
    * [Run the Go service locally](#run-the-go-service-locally)
7. [Konnect And AWS Setup](#konnect-and-aws-setup)
    * [1. Create the gateway in Konnect](#1-create-the-gateway-in-konnect)
    * [2. Run the setup helper](#2-run-the-setup-helper)
    * [3. What the script produces](#3-what-the-script-produces)
    * [4. Security note](#4-security-note)
8. [Kong Configuration Workflow](#kong-configuration-workflow)
    * [1. Export decK variables](#1-export-deck-variables)
    * [2. Validate and sync Kong config](#2-validate-and-sync-kong-config)
9. [Deploy With CDK](#deploy-with-cdk)
    * [CDK workflow](#cdk-workflow)
10. [Repository Layout](#repository-layout)
11. [Why This Structure](#why-this-structure)

## Introduction

A reference project for building and operating a Kong-based API platform with:

- Kong Konnect control plane and Kong Gateway data planes
- OpenAPI-driven API design and lifecycle governance
- Enterprise API security with OIDC, JWT, and mTLS
- AWS infrastructure automation in CDK (TypeScript)
- A small Go upstream service used as the demo backend

## What This Repo Demonstrates

This repo models a common enterprise setup:

- Konnect hosts the control plane.
- Kong data planes run on AWS ECS/Fargate.
- Kong routes traffic to an internal Go service.
- API policy is managed declaratively.
- Infrastructure is provisioned with CDK.

The example is intentionally compact. It is meant to show how the parts fit together, not to be a production-ready platform module.

## Repository Overview

- [services/orders-api](./services/orders-api): sample Go service with health, orders, and caller-context endpoints.
- [openapi/orders-api.json](./openapi/orders-api.json): OpenAPI 3.1 contract for the demo API.
- [kong/kong.json](./kong/kong.json): example Kong declarative configuration.
- [kong/konnect-control-plane.yaml](./kong/konnect-control-plane.yaml): Konnect-oriented declarative state.
- [docs/api-governance.md](./docs/api-governance.md): API versioning and lifecycle expectations.
- [docs/architecture.md](./docs/architecture.md): high-level reference architecture.
- [infra/cdk](./infra/cdk): CDK deployment example.
- [setup.sh](./setup.sh): helper script that converts raw Konnect bootstrap values into deploy-ready AWS setup.

## Architecture Summary

The sample API uses different gateway controls by audience:

- `/v1/orders`: OIDC plus Redis-backed rate limiting
- `/v1/partner/orders`: JWT plus local rate limiting
- `/v1/caller`: mTLS plus ACLs

The upstream Go service assumes Kong has already authenticated the caller and reads trusted gateway headers such as:

- `X-Consumer-Username`
- `X-Authenticated-Scope`
- `X-Client-Cert-Subject`

## Dependencies

Install these tools before working through the local checks, Konnect sync, and AWS deployment steps:

- `Node.js` and `npm`: used for the root validation scripts and the CDK app.
- `Go`: used to run and test the demo `orders-api` service locally.
- `AWS CLI`: used by `setup.sh` to create or update Secrets Manager secrets and by CDK during deploys.
- `decK`: used to validate and sync the Kong declarative config into Konnect.

Example install commands on macOS:

```bash
brew install go
brew install awscli
brew install kong/deck/deck
```

Verify the key CLI dependencies are available:

```bash
go version
aws --version
deck version
node --version
npm --version
```

You do not need a global CDK install. The repo uses the local CDK dependency through `npx cdk ...`.

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
6. Open the new gateway and go to `Data Plane Nodes`.
7. Click `Configure data plane`.
8. Generate the certificate and script for the data plane.

The generated script is the source of truth for the values you need. Save them into environment variables immediately:

```bash
export KONG_CLUSTER_CONTROL_PLANE='YOUR_CLUSTER_CONTROL_PLANE'
export KONG_CLUSTER_TELEMETRY_ENDPOINT='YOUR_CLUSTER_TELEMETRY_ENDPOINT'
export KONG_CLUSTER_CERT='YOUR_CLUSTER_CERT_PEM'
export KONG_CLUSTER_CERT_KEY='YOUR_CLUSTER_CERT_KEY_PEM'
```

You do not need to run the generated Docker command locally unless you want a quick smoke test.

### 2. Run the setup helper

The cleanest path in this repo is to save the four raw Konnect values into environment variables and then run [setup.sh](./setup.sh). The script will:

- strip `:443` from the two host values
- create or update the two AWS Secrets Manager secrets
- print the exact `export` commands this repo expects

Example:

```bash
export KONG_CLUSTER_CONTROL_PLANE='YOUR_CLUSTER_CONTROL_PLANE'
export KONG_CLUSTER_TELEMETRY_ENDPOINT='YOUR_CLUSTER_TELEMETRY_ENDPOINT'
export KONG_CLUSTER_CERT='YOUR_CLUSTER_CERT_PEM'
export KONG_CLUSTER_CERT_KEY='YOUR_CLUSTER_CERT_KEY_PEM'

bash setup.sh
```


### 3. What the script produces

The script will print the export commands you should use before deployment:

```bash
export PROJECT_NAME='kong-platform'
export ENVIRONMENT='dev'
export AWS_REGION='ap-southeast-2'
export KONNECT_CONTROL_PLANE_HOST='YOUR_CONTROL_PLANE_HOST'
export KONNECT_TELEMETRY_HOST='YOUR_TELEMETRY_HOST'
export KONNECT_CLIENT_CERT_SECRET_NAME='konnect/dp/client-cert'
export KONNECT_CLIENT_KEY_SECRET_NAME='konnect/dp/client-key'
```

It will also create or update these two secrets in AWS Secrets Manager:

- `konnect/dp/client-cert`
- `konnect/dp/client-key`

### 4. Security note

If the private key was pasted into chat, screenshots, or any other place you do not fully control, regenerate the Konnect data plane certificate and re-run the setup script before deployment.

## Kong Configuration Workflow

Use the declarative config in this repo as the source of truth for services, routes, and plugins.

Files:

- [kong/kong.json](./kong/kong.json): self-managed declarative config example
- [kong/konnect-control-plane.yaml](./kong/konnect-control-plane.yaml): Konnect-oriented config

### 1. Export decK variables

The Konnect sample config is JWT-first so it can be tested without standing up a separate OIDC provider. Export these values before syncing:

- `DECK_PARTNER_JWT_SECRET`: generate a shared secret once for the environment. The Konnect config uses it for the `partner-app` consumer's HS256 credential.
- `KONNECT_TOKEN`: create a Konnect personal access token in the Konnect UI by opening the Personal Access Tokens page and selecting `Generate Token`, then copy the token value.

Example:

```bash
export DECK_PARTNER_JWT_SECRET="$(openssl rand -hex 32)"
export KONNECT_TOKEN='your-konnect-personal-access-token'
```

The richer self-managed example in [kong/kong.json](./kong/kong.json) still includes OIDC and mTLS routes, but the default Konnect walkthrough uses JWT because it is easier to verify end to end.

### 2. Validate and sync Kong config

Use `deck gateway validate` if you want a live validation step against your Konnect control plane before syncing. This is optional once you already know the file and credentials are correct, but it is useful as a pre-flight check.

```bash
deck gateway validate \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name kong-platform-dev \
  kong/konnect-control-plane.yaml

deck gateway sync \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name kong-platform-dev \
  kong/konnect-control-plane.yaml
```

### 3. Verify the deployed gateway

After `npx cdk deploy`, copy the `GatewayUrl` output and smoke test Kong itself:

```bash
export GATEWAY_URL='http://your-alb-dns-name'
curl -i "$GATEWAY_URL/"
```

A `404` from `/` is expected and confirms the request is reaching Kong.

Then mint a partner JWT and call the JWT-protected route. Kong exposes `/v1/partner/orders` publicly and rewrites it to the upstream service's `/v1/orders` path:

```bash
export PARTNER_JWT="$(node scripts/generate-partner-jwt.mjs)"
curl -i \
  -H "Authorization: Bearer $PARTNER_JWT" \
  -H 'X-Tenant-ID: tenant-a' \
  "$GATEWAY_URL/v1/partner/orders"
```

Expected results:

- `200`: the gateway, JWT policy, and upstream service are all working.
- `401` or `403`: the route exists, but the JWT credential or token is wrong.
- `502` or `503`: the route exists, but Kong cannot reach the upstream service.
- `404`: the Konnect config has not been synced successfully yet.

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
export PROJECT_NAME='kong-platform'
export ENVIRONMENT='dev'
export AWS_REGION='ap-southeast-2'
export KONNECT_CONTROL_PLANE_HOST='YOUR_CONTROL_PLANE_HOST'
export KONNECT_TELEMETRY_HOST='YOUR_TELEMETRY_HOST'
export KONNECT_CLIENT_CERT_SECRET_NAME='konnect/dp/client-cert'
export KONNECT_CLIENT_KEY_SECRET_NAME='konnect/dp/client-key'
```

## Repository Layout

```text
.
├── docs/
├── infra/
│   └── cdk/
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
- Infrastructure is defined in CDK.
