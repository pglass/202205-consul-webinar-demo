locals {
  frontend_name      = "frontend"
  frontend_port      = 3000
  frontend_namespace = "default"
  frontend_partition = "ecs-dev"

  frontend_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "${local.frontend_name}-${local.suffix}"
    }
  }
}

resource "aws_ecs_service" "frontend" {
  name            = local.frontend_name
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.frontend.task_definition_arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type    = "FARGATE"
  propagate_tags = "TASK_DEFINITION"
  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = local.frontend_name
    container_port   = local.frontend_port
  }
  enable_execute_command = true
}

module "frontend" {
  source              = "hashicorp/consul-ecs/aws//modules/mesh-task"
  version             = "0.4.1"
  consul_image        = "public.ecr.aws/hashicorp/consul-enterprise:1.11.5-ent"
  consul_service_name = local.frontend_name
  consul_partition    = local.frontend_partition
  consul_namespace    = local.frontend_namespace
  family              = "${local.frontend_name}-${local.suffix}"
  cpu                 = 1024
  memory              = 2048
  port                = local.frontend_port
  log_configuration   = local.frontend_log_config
  container_definitions = [{
    name             = local.frontend_name
    image            = "ghcr.io/pglass/hashicorpdemoapp-frontend:v1.0.2"
    essential        = true
    logConfiguration = local.frontend_log_config
    environment = [
      {
        name  = "NAME"
        value = local.frontend_name
      },
      {
        name  = "NEXT_PUBLIC_PUBLIC_API_URL",
        value = "http://${aws_lb.hashicups.dns_name}:8081"
      }
    ]
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [
      {
        containerPort = local.frontend_port
        hostPort      = local.frontend_port
        protocol      = "tcp"
      }
    ]
    cpu         = 0
    mountPoints = []
    volumesFrom = []
  }]
  upstreams = [
    {
      destinationName = "public-api"
      localBindPort   = 8081
    }
  ]
  retry_join                     = jsondecode(base64decode(hcp_consul_cluster.this.consul_config_file))["retry_join"]
  tls                            = true
  consul_server_ca_cert_arn      = aws_secretsmanager_secret.consul_ca_cert.arn
  gossip_key_secret_arn          = aws_secretsmanager_secret.gossip_key.arn
  acls                           = true
  consul_client_token_secret_arn = module.acl_controller.client_token_secret_arn
  acl_secret_name_prefix         = local.name
  consul_datacenter              = "dc1"
  additional_task_role_policies  = [aws_iam_policy.execute_command.arn]
  depends_on                     = [module.acl_controller]
}

