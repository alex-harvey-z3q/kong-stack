run "plan_has_expected_naming" {
  command = plan

  variables {
    project_name                   = "kong-platform"
    environment                    = "dev"
    region                         = "ap-southeast-2"
    konnect_control_plane_host     = "cp.konnect.example.com"
    konnect_telemetry_host         = "telemetry.konnect.example.com"
    konnect_client_cert_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:konnect-cert"
    konnect_client_key_secret_arn  = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:konnect-key"
  }

  assert {
    condition     = aws_ecs_cluster.platform.name == "kong-platform-dev"
    error_message = "The ECS cluster should follow the project-environment naming convention."
  }

  assert {
    condition     = output.orders_service_dns_name == "orders-api.platform.local"
    error_message = "Orders service discovery should remain stable for Kong upstream routing."
  }
}

