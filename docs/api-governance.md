# API Governance Standards

This example treats the Kong control plane as the enforcement point for API lifecycle and security policy.

## Standards

- Author every public contract in OpenAPI 3.x.
- Publish only versioned routes (`/v1`, `/v2`, and so on).
- Keep breaking changes behind a new major URI version.
- Require a lifecycle marker on every API (`x-api-lifecycle.stage`).
- Deprecate old versions for at least 12 months before retirement.
- Use tags to group APIs by product domain and audience.

## Security Baseline

- Human users authenticate with OIDC through the Kong `openid-connect` plugin.
- Partner and machine identities authenticate with JWT through the Kong `jwt` plugin.
- High-trust operational endpoints require mTLS through the Kong `mtls-auth` plugin.
- Rate limiting is tiered:
  - `redis` strategy for horizontally scaled public traffic.
  - `local` strategy for lower-volume partner integrations.

## Operational Lifecycle

1. Update the OpenAPI document.
2. Review versioning and lifecycle headers.
3. Sync Kong control plane configuration through decK or Konnect.
4. Roll data planes using CDK or Terraform-managed infrastructure.
5. Observe traffic and enforce deprecation windows before sunsetting an API version.

