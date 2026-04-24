data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"
  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Domain      = "api-platform"
    },
    var.tags
  )
}

resource "aws_vpc" "platform" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "platform" {
  vpc_id = aws_vpc.platform.id

  tags = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.42.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.tags, { Name = "${local.name}-public-a" })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.42.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(local.tags, { Name = "${local.name}-public-b" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.platform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.platform.id
  }

  tags = merge(local.tags, { Name = "${local.name}-public" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "kong" {
  name        = "${local.name}-kong"
  description = "Ingress for Kong proxy traffic"
  vpc_id      = aws_vpc.platform.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8100
    protocol    = "tcp"
    cidr_blocks = ["10.42.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-kong" })
}

resource "aws_security_group" "orders" {
  name        = "${local.name}-orders"
  description = "Private access to the orders API"
  vpc_id      = aws_vpc.platform.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.kong.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-orders" })
}

resource "aws_cloudwatch_log_group" "kong" {
  name              = "/ecs/${local.name}/kong"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "orders" {
  name              = "/ecs/${local.name}/orders"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_service_discovery_private_dns_namespace" "platform" {
  name        = "platform.local"
  description = "Service discovery namespace for Kong platform workloads"
  vpc         = aws_vpc.platform.id

  tags = local.tags
}

resource "aws_service_discovery_service" "orders" {
  name = "orders-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.platform.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_cluster" "platform" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "orders" {
  family                   = "${local.name}-orders"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "orders-api"
      image     = var.orders_image
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "ORDERS_API_ADDR"
          value = ":8080"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.orders.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "orders"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_task_definition" "kong" {
  family                   = "${local.name}-kong"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "kong-dp"
      image     = var.kong_image
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        },
        {
          containerPort = 8100
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "KONG_ROLE"
          value = "data_plane"
        },
        {
          name  = "KONG_DATABASE"
          value = "off"
        },
        {
          name  = "KONG_CLUSTER_MTLS"
          value = "pki"
        },
        {
          name  = "KONG_PROXY_LISTEN"
          value = "0.0.0.0:8000"
        },
        {
          name  = "KONG_STATUS_LISTEN"
          value = "0.0.0.0:8100"
        },
        {
          name  = "KONG_CLUSTER_CONTROL_PLANE"
          value = "${var.konnect_control_plane_host}:443"
        },
        {
          name  = "KONG_CLUSTER_SERVER_NAME"
          value = var.konnect_control_plane_host
        },
        {
          name  = "KONG_CLUSTER_TELEMETRY_ENDPOINT"
          value = "${var.konnect_telemetry_host}:443"
        },
        {
          name  = "KONG_CLUSTER_TELEMETRY_SERVER_NAME"
          value = var.konnect_telemetry_host
        },
        {
          name  = "KONG_LUA_SSL_TRUSTED_CERTIFICATE"
          value = "system"
        }
      ]
      secrets = [
        {
          name      = "KONG_CLUSTER_CERT"
          valueFrom = var.konnect_client_cert_secret_arn
        },
        {
          name      = "KONG_CLUSTER_CERT_KEY"
          valueFrom = var.konnect_client_key_secret_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.kong.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "kong"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_lb" "kong" {
  name               = replace(substr("${local.name}-alb", 0, 32), "/[^a-zA-Z0-9-]/", "-")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kong.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = local.tags
}

resource "aws_lb_target_group" "kong" {
  name        = replace(substr("${local.name}-tg", 0, 32), "/[^a-zA-Z0-9-]/", "-")
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.platform.id

  health_check {
    enabled             = true
    path                = "/"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.tags
}

resource "aws_lb_listener" "kong_http" {
  load_balancer_arn = aws_lb.kong.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong.arn
  }
}

resource "aws_ecs_service" "orders" {
  name            = "${local.name}-orders"
  cluster         = aws_ecs_cluster.platform.id
  task_definition = aws_ecs_task_definition.orders.arn
  desired_count   = var.orders_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.orders.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.orders.arn
  }

  tags = local.tags
}

resource "aws_ecs_service" "kong" {
  name            = "${local.name}-kong"
  cluster         = aws_ecs_cluster.platform.id
  task_definition = aws_ecs_task_definition.kong.arn
  desired_count   = var.kong_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.kong.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kong.arn
    container_name   = "kong-dp"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.kong_http]

  tags = local.tags
}

