export interface DeploymentConfig {
  projectName: string;
  environment: string;
  region: string;
  kongImage: string;
  ordersDesiredCount: number;
  kongDesiredCount: number;
  konnectControlPlaneHost: string;
  konnectTelemetryHost: string;
  konnectClientCertSecretName: string;
  konnectClientKeySecretName: string;
  tags: Record<string, string>;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): DeploymentConfig {
  const projectName = env.PROJECT_NAME ?? "kong-platform";
  const environment = env.ENVIRONMENT ?? "dev";
  const region = env.AWS_REGION ?? env.CDK_DEFAULT_REGION ?? "ap-southeast-2";

  return {
    projectName,
    environment,
    region,
    kongImage: env.KONG_IMAGE ?? "kong/kong-gateway:3.8",
    ordersDesiredCount: parsePositiveInt(env.ORDERS_DESIRED_COUNT, 2),
    kongDesiredCount: parsePositiveInt(env.KONG_DESIRED_COUNT, 2),
    konnectControlPlaneHost: env.KONNECT_CONTROL_PLANE_HOST ?? "cp.konnect.example.com",
    konnectTelemetryHost: env.KONNECT_TELEMETRY_HOST ?? "telemetry.konnect.example.com",
    konnectClientCertSecretName: env.KONNECT_CLIENT_CERT_SECRET_NAME ?? "konnect/dp/client-cert",
    konnectClientKeySecretName: env.KONNECT_CLIENT_KEY_SECRET_NAME ?? "konnect/dp/client-key",
    tags: {
      Project: projectName,
      Environment: environment,
      ManagedBy: "cdk",
      Domain: "api-platform"
    }
  };
}

function parsePositiveInt(raw: string | undefined, fallback: number): number {
  if (!raw) {
    return fallback;
  }

  const parsed = Number.parseInt(raw, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    return fallback;
  }

  return parsed;
}

