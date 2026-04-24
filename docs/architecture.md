# Reference Architecture

This repository models a small enterprise API platform with Kong controlling north-south traffic and AWS running the underlying workloads.

## Control Plane

- Konnect or a self-managed Kong control plane owns services, routes, plugins, and policy rollout.
- API contracts are defined in [openapi/orders-api.json](../openapi/orders-api.json).
- Declarative gateway configuration lives in [kong/kong.json](../kong/kong.json) and [kong/konnect-control-plane.json](../kong/konnect-control-plane.json).

## Data Plane

- Kong data planes run on ECS Fargate behind an internet-facing ALB.
- The sample `orders-api` service runs privately in the same ECS cluster and is discovered through Cloud Map.
- Public traffic enters Kong, where OIDC, JWT, mTLS, and rate limiting are enforced before the request reaches the upstream service.

## Security Posture

- `openid-connect` protects human-facing routes.
- `jwt` protects partner or service-to-service routes.
- `mtls-auth` protects high-trust operational endpoints.
- Two rate limiting strategies are modeled:
  - `rate-limiting-advanced` with Redis for shared counters across replicas.
  - `rate-limiting` with `local` policy for simpler partner integrations.

## Delivery Options

- [infra/cdk](../infra/cdk) shows a CDK TypeScript deployment path.
- [infra/terraform](../infra/terraform) shows a Terraform deployment path for the same platform shape.

