import test from "node:test";
import assert from "node:assert/strict";

import { loadOpenAPISpec, validateOpenAPISpec } from "../scripts/validate-openapi.mjs";

test("OpenAPI spec satisfies governance rules", async () => {
  const spec = await loadOpenAPISpec();
  assert.deepEqual(validateOpenAPISpec(spec), []);
});

test("OpenAPI validator rejects unversioned public routes", () => {
  const spec = {
    openapi: "3.1.0",
    info: {
      version: "1.0.0",
      "x-api-lifecycle": {
        stage: "active"
      }
    },
    paths: {
      "/orders": {
        get: {
          operationId: "listOrders"
        }
      }
    },
    components: {
      securitySchemes: {
        oidc: {},
        bearerJwt: {},
        mutualTls: {}
      }
    }
  };

  assert.match(
    validateOpenAPISpec(spec).join("\n"),
    /must use a versioned prefix/
  );
});

