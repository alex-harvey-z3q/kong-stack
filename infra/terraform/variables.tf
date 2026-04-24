variable "project_name" {
  description = "Base project name for tags and AWS resources."
  type        = string
  default     = "kong-platform"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "ap-southeast-2"
}

variable "kong_image" {
  description = "Container image for the Kong data plane."
  type        = string
  default     = "kong/kong-gateway:3.8"
}

variable "orders_image" {
  description = "Container image for the orders API."
  type        = string
  default     = "public.ecr.aws/docker/library/golang:1.25"
}

variable "kong_desired_count" {
  description = "Desired number of Kong data plane tasks."
  type        = number
  default     = 2
}

variable "orders_desired_count" {
  description = "Desired number of orders-api tasks."
  type        = number
  default     = 2
}

variable "konnect_control_plane_host" {
  description = "Konnect control plane host used by data planes."
  type        = string
}

variable "konnect_telemetry_host" {
  description = "Konnect telemetry host used by data planes."
  type        = string
}

variable "konnect_client_cert_secret_arn" {
  description = "Secrets Manager ARN holding the Kong data plane client certificate."
  type        = string
}

variable "konnect_client_key_secret_arn" {
  description = "Secrets Manager ARN holding the Kong data plane client private key."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to the platform resources."
  type        = map(string)
  default     = {}
}

