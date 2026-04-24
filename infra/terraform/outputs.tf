output "ecs_cluster_name" {
  description = "Name of the ECS cluster hosting Kong and the demo API."
  value       = aws_ecs_cluster.platform.name
}

output "gateway_url" {
  description = "Public URL of the Kong data plane ALB."
  value       = "http://${aws_lb.kong.dns_name}"
}

output "orders_service_dns_name" {
  description = "Cloud Map name used by Kong to reach the upstream service."
  value       = "orders-api.platform.local"
}

