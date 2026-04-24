import test from "node:test";
import assert from "node:assert/strict";

import { loadKongConfig, validateKongConfig } from "../scripts/validate-kong.mjs";

test("Kong config includes OIDC, JWT, mTLS, and rate limiting strategies", async () => {
  const config = await loadKongConfig();
  assert.deepEqual(validateKongConfig(config), []);
});

test("Kong validator rejects missing enterprise security policy", () => {
  const config = {
    _format_version: "3.0",
    services: [
      {
        routes: [
          {
            name: "orders-public-v1",
            plugins: []
          },
          {
            name: "orders-partner-v1",
            plugins: []
          },
          {
            name: "caller-debug-v1",
            plugins: []
          }
        ]
      }
    ],
    ca_certificates: []
  };

  assert.match(
    validateKongConfig(config).join("\n"),
    /openid-connect/
  );
});

