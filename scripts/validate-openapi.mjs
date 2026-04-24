import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const specPath = path.join(rootDir, "openapi", "orders-api.json");

export async function loadOpenAPISpec() {
  const raw = await readFile(specPath, "utf8");
  return JSON.parse(raw);
}

export function validateOpenAPISpec(spec) {
  const failures = [];

  if (!String(spec.openapi || "").startsWith("3.")) {
    failures.push("OpenAPI document must use version 3.x.");
  }

  if (!spec.info?.version) {
    failures.push("OpenAPI info.version is required.");
  }

  if (!spec.info?.["x-api-lifecycle"]?.stage) {
    failures.push("OpenAPI info.x-api-lifecycle.stage is required for lifecycle governance.");
  }

  const securitySchemes = spec.components?.securitySchemes || {};
  for (const name of ["oidc", "bearerJwt", "mutualTls"]) {
    if (!securitySchemes[name]) {
      failures.push(`Missing security scheme: ${name}`);
    }
  }

  for (const [route, pathItem] of Object.entries(spec.paths || {})) {
    if (route !== "/healthz" && !route.startsWith("/v1/")) {
      failures.push(`Path ${route} must use a versioned prefix.`);
    }

    for (const [method, operation] of Object.entries(pathItem)) {
      if (!operation?.operationId) {
        failures.push(`Operation ${method.toUpperCase()} ${route} is missing an operationId.`);
      }
    }
  }

  return failures;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const spec = await loadOpenAPISpec();
  const failures = validateOpenAPISpec(spec);

  if (failures.length > 0) {
    console.error(failures.join("\n"));
    process.exit(1);
  }

  console.log("OpenAPI validation passed.");
}

