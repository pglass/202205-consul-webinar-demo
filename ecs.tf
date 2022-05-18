resource "aws_ecs_cluster" "this" {
  name = local.name
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
  }
}

// Policy that allows execution of remote commands in ECS tasks.
resource "aws_iam_policy" "execute_command" {
  name   = "ecs-execute-command-${local.suffix}"
  path   = "/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}



module "acl_controller" {
  source                    = "hashicorp/consul-ecs/aws//modules/acl-controller"
  version                   = "0.4.1"
  consul_partitions_enabled = true
  consul_partition          = "ecs-dev"
  name_prefix               = local.name
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "consul-acl-controller"
    }
  }
  consul_bootstrap_token_secret_arn = aws_secretsmanager_secret.bootstrap_token.arn
  consul_server_http_addr           = hcp_consul_cluster.this.consul_private_endpoint_url
  ecs_cluster_arn                   = aws_ecs_cluster.this.arn
  region                            = var.region
  subnets                           = module.vpc.private_subnets
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = local.name
}



resource "aws_lb" "hashicups" {
  name               = "hashicups-${local.suffix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = module.vpc.public_subnets
}


## HashiCups Frontend

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.hashicups.arn
  port              = local.ecs_ingress_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_target_group" "frontend" {
  name                 = "frontend-${local.suffix}"
  port                 = local.frontend_port
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 30
  health_check {
    path                = "/robots.txt" // something that does not hit upstreams
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 15
  }
}


## HashiCups Public API

resource "aws_lb_listener" "public-api" {
  load_balancer_arn = aws_lb.hashicups.arn
  port              = local.public_api_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public-api.arn
  }
}

resource "aws_lb_target_group" "public-api" {
  name                 = "public-api-${local.suffix}"
  port                 = local.public_api_port
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 30
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 15
  }
}


// Grant ingress to the ALB from internet.
resource "aws_security_group" "lb" {
  name   = "frontend-alb-${local.suffix}"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Access to frontend Web UI."
    from_port   = local.ecs_ingress_port
    to_port     = local.ecs_ingress_port
    protocol    = "tcp"
    cidr_blocks = var.lb_ingress_ips
  }

  ingress {
    description = "Access to GraphQL API."
    from_port   = local.public_api_port
    to_port     = local.public_api_port
    protocol    = "tcp"
    cidr_blocks = var.lb_ingress_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group_rule" "ingress_from_client_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb.id
  security_group_id        = module.vpc.default_security_group_id
}
