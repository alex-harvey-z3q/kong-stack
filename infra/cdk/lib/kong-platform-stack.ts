import path from "node:path";

import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ecsPatterns from "aws-cdk-lib/aws-ecs-patterns";
import * as logs from "aws-cdk-lib/aws-logs";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import { Construct } from "constructs";

import { DeploymentConfig } from "./config";

export interface KongPlatformStackProps extends cdk.StackProps {
  config: DeploymentConfig;
}

export class KongPlatformStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: KongPlatformStackProps) {
    super(scope, id, props);

    const { config } = props;

    const vpc = new ec2.Vpc(this, "PlatformVpc", {
      maxAzs: 2,
      natGateways: 1
    });

    const cluster = new ecs.Cluster(this, "PlatformCluster", {
      vpc,
      clusterName: `${config.projectName}-${config.environment}`,
      enableFargateCapacityProviders: true,
      containerInsights: true,
      defaultCloudMapNamespace: {
        name: "platform.local"
      }
    });

    const ordersLogGroup = new logs.LogGroup(this, "OrdersLogGroup", {
      retention: logs.RetentionDays.ONE_WEEK
    });

    const ordersTask = new ecs.FargateTaskDefinition(this, "OrdersTask", {
      cpu: 256,
      memoryLimitMiB: 512
    });

    ordersTask.addContainer("OrdersContainer", {
      image: ecs.ContainerImage.fromAsset(path.join(__dirname, "../../../services/orders-api")),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: "orders-api",
        logGroup: ordersLogGroup
      }),
      environment: {
        ORDERS_API_ADDR: ":8080"
      }
    }).addPortMappings({
      containerPort: 8080
    });

    const ordersService = new ecs.FargateService(this, "OrdersService", {
      cluster,
      taskDefinition: ordersTask,
      desiredCount: config.ordersDesiredCount,
      assignPublicIp: false,
      cloudMapOptions: {
        name: "orders-api"
      }
    });

    const kongLogGroup = new logs.LogGroup(this, "KongLogGroup", {
      retention: logs.RetentionDays.ONE_WEEK
    });

    const kongTask = new ecs.FargateTaskDefinition(this, "KongTask", {
      cpu: 1024,
      memoryLimitMiB: 2048
    });

    const clientCertSecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      "KonnectClientCertSecret",
      config.konnectClientCertSecretName
    );
    const clientKeySecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      "KonnectClientKeySecret",
      config.konnectClientKeySecretName
    );

    kongTask.addContainer("KongDataPlane", {
      image: ecs.ContainerImage.fromRegistry(config.kongImage),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: "kong-dp",
        logGroup: kongLogGroup
      }),
      environment: {
        KONG_ROLE: "data_plane",
        KONG_DATABASE: "off",
        KONG_CLUSTER_MTLS: "pki",
        KONG_PROXY_LISTEN: "0.0.0.0:8000",
        KONG_STATUS_LISTEN: "0.0.0.0:8100",
        KONG_CLUSTER_CONTROL_PLANE: `${config.konnectControlPlaneHost}:443`,
        KONG_CLUSTER_SERVER_NAME: config.konnectControlPlaneHost,
        KONG_CLUSTER_TELEMETRY_ENDPOINT: `${config.konnectTelemetryHost}:443`,
        KONG_CLUSTER_TELEMETRY_SERVER_NAME: config.konnectTelemetryHost,
        KONG_LUA_SSL_TRUSTED_CERTIFICATE: "system",
        KONG_VITALS: "off"
      },
      secrets: {
        KONG_CLUSTER_CERT: ecs.Secret.fromSecretsManager(clientCertSecret),
        KONG_CLUSTER_CERT_KEY: ecs.Secret.fromSecretsManager(clientKeySecret)
      }
    }).addPortMappings(
      {
        containerPort: 8000
      },
      {
        containerPort: 8100
      }
    );

    const kongService = new ecsPatterns.ApplicationLoadBalancedFargateService(this, "KongGateway", {
      cluster,
      taskDefinition: kongTask,
      publicLoadBalancer: true,
      desiredCount: config.kongDesiredCount,
      listenerPort: 80
    });

    kongService.targetGroup.configureHealthCheck({
      path: "/",
      healthyHttpCodes: "200-499"
    });

    ordersService.connections.allowFrom(kongService.service, ec2.Port.tcp(8080), "Allow Kong to reach orders-api");

    for (const [key, value] of Object.entries(config.tags)) {
      cdk.Tags.of(this).add(key, value);
    }

    new cdk.CfnOutput(this, "GatewayUrl", {
      value: `http://${kongService.loadBalancer.loadBalancerDnsName}`
    });
  }
}

