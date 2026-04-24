#!/usr/bin/env node
import * as cdk from "aws-cdk-lib";

import { loadConfig } from "../lib/config";
import { KongPlatformStack } from "../lib/kong-platform-stack";

const app = new cdk.App();
const config = loadConfig(process.env);

new KongPlatformStack(app, `${config.projectName}-${config.environment}`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: config.region
  },
  config
});

