import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const kongConfigPath = path.join(rootDir, "kong", "kong.json");

export async function loadKongConfig() {
  const raw = await readFile(kongConfigPath, "utf8");
  return JSON.parse(raw);
}

function flattenRoutePlugins(config) {
  return (config.services || []).flatMap((service) =>
    (service.routes || []).flatMap((route) =>
      (route.plugins || []).map((plugin) => ({
        route: route.name,
        plugin
      }))
    )
  );
}

export function validateKongConfig(config) {
  const failures = [];

  if (!config._format_version) {
    failures.push("Kong config must define _format_version.");
  }

  const routePlugins = flattenRoutePlugins(config);
  const requiredRoutes = ["orders-public-v1", "orders-partner-v1", "caller-debug-v1"];
  const presentRoutes = new Set(routePlugins.map((entry) => entry.route));

  for (const routeName of requiredRoutes) {
    if (!presentRoutes.has(routeName)) {
      failures.push(`Missing route: ${routeName}`);
    }
  }

  const hasPluginOnRoute = (routeName, pluginName) =>
    routePlugins.some((entry) => entry.route === routeName && entry.plugin.name === pluginName);

  if (!hasPluginOnRoute("orders-public-v1", "openid-connect")) {
    failures.push("orders-public-v1 must use the openid-connect plugin.");
  }

  if (!hasPluginOnRoute("orders-public-v1", "rate-limiting-advanced")) {
    failures.push("orders-public-v1 must use rate-limiting-advanced.");
  }

  if (!hasPluginOnRoute("orders-partner-v1", "jwt")) {
    failures.push("orders-partner-v1 must use the jwt plugin.");
  }

  if (!hasPluginOnRoute("orders-partner-v1", "rate-limiting")) {
    failures.push("orders-partner-v1 must use the local rate-limiting plugin.");
  }

  if (!hasPluginOnRoute("caller-debug-v1", "mtls-auth")) {
    failures.push("caller-debug-v1 must use the mtls-auth plugin.");
  }

  if (!(config.ca_certificates || []).length) {
    failures.push("mTLS routes require at least one CA certificate.");
  }

  return failures;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const config = await loadKongConfig();
  const failures = validateKongConfig(config);

  if (failures.length > 0) {
    console.error(failures.join("\n"));
    process.exit(1);
  }

  console.log("Kong config validation passed.");
}

