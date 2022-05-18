// Create Admin Partition and Namespace for the server
resource "consul_admin_partition" "eks-dev" {
  name        = "eks-dev"
  description = "Partition for EKS"
  depends_on  = [hcp_consul_cluster.this]
}

resource "consul_admin_partition" "ecs-dev" {
  name        = "ecs-dev"
  description = "Partition for ECS"
  depends_on  = [hcp_consul_cluster.this]
}

resource "consul_config_entry" "exported_eks_services" {
  kind = "exported-services"
  # Note that only "global" is currently supported for proxy-defaults and that
  # Consul will override this attribute if you set it to anything else.
  name = consul_admin_partition.eks-dev.name

  config_json = jsonencode({
    Services = [
      {
        Name      = "product-api"
        Partition = "eks-dev"
        Namespace = "default"
        Consumers = [
          {
            Partition = consul_admin_partition.ecs-dev.name
          },
        ]
      },
      {
        Name      = "payments"
        Partition = "eks-dev"
        Namespace = "default"
        Consumers = [
          {
            Partition = consul_admin_partition.ecs-dev.name
          },
        ]
      }
    ]
  })
}



// For frontend -> public-api in ECS
resource "consul_config_entry" "frontend_intention" {
  name      = local.public_api_name
  kind      = "service-intentions"
  partition = consul_admin_partition.ecs-dev.name
  namespace = "default"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = local.frontend_name
        Precedence = 9
        Type       = "consul"
        Namespace  = "default"
        Partition  = local.frontend_partition
      }
    ]
  })
}
