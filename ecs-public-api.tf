locals {
  public_api_name      = "public-api"
  public_api_port      = 8081
  public_api_namespace = "default"
  public_api_partition = "ecs-dev"

  public_api_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "${local.public_api_name}-${local.suffix}"
    }
  }

}

resource "aws_ecs_service" "public-api" {
  name            = local.public_api_name
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.public-api.task_definition_arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type    = "FARGATE"
  propagate_tags = "TASK_DEFINITION"
  load_balancer {
    target_group_arn = aws_lb_target_group.public-api.arn
    container_name   = local.public_api_name
    container_port   = local.public_api_port
  }
  enable_execute_command = true
}

module "public-api" {
  source              = "hashicorp/consul-ecs/aws//modules/mesh-task"
  version             = "0.4.1"
  consul_image        = "public.ecr.aws/hashicorp/consul-enterprise:1.11.5-ent"
  consul_service_name = local.public_api_name
  consul_partition    = local.public_api_partition
  consul_namespace    = local.public_api_namespace
  family              = "${local.public_api_name}-${local.suffix}"
  cpu                 = 1024
  memory              = 2048
  port                = local.public_api_port
  log_configuration   = local.public_api_log_config
  container_definitions = [{
    name             = local.public_api_name
    image            = "ghcr.io/pglass/hashicorpdemoapp-public-api:v0.0.7"
    essential        = true
    logConfiguration = local.public_api_log_config
    environment = [
      {
        name  = "PAYMENT_API_URI"
        value = "http://localhost:9090"
      },
      {
        name  = "PRODUCT_API_URI"
        value = "http://localhost:9091"
      },
      {
        name  = "BIND_ADDRESS"
        value = ":${local.public_api_port}"
      }
    ]
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [
      {
        containerPort = local.public_api_port
        hostPort      = local.public_api_port
        protocol      = "tcp"
      }
    ]
  }]
  upstreams = [
    {
      destinationName      = "product-api"
      destinationPartition = "eks-dev"
      destinationNamespace = "default"
      localBindPort        = 9091
    },
    {
      destinationName      = "payments"
      destinationPartition = "eks-dev"
      destinationNamespace = "default"
      localBindPort        = 9090
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
