import test from "node:test";
import assert from "node:assert/strict";

import { loadConfig } from "../lib/config";

test("loadConfig applies sane defaults", () => {
  const config = loadConfig({});

  assert.equal(config.projectName, "kong-platform");
  assert.equal(config.environment, "dev");
  assert.equal(config.kongDesiredCount, 2);
  assert.equal(config.ordersDesiredCount, 2);
});

test("loadConfig respects explicit overrides", () => {
  const config = loadConfig({
    PROJECT_NAME: "acme-api",
    ENVIRONMENT: "prod",
    KONG_DESIRED_COUNT: "4",
    ORDERS_DESIRED_COUNT: "3"
  });

  assert.equal(config.projectName, "acme-api");
  assert.equal(config.environment, "prod");
  assert.equal(config.kongDesiredCount, 4);
  assert.equal(config.ordersDesiredCount, 3);
});

