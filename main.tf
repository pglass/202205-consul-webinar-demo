locals {
  launch_type      = "FARGATE"
  suffix           = var.suffix == "" ? lower(random_string.suffix.result) : var.suffix
  name             = "consul-ecs-webinar-${local.suffix}"
  ecs_ingress_port = 80
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "eks_consul_client" {
  source = "./modules/hcp-eks-client"

  cluster_id       = hcp_consul_cluster.this.cluster_id
  consul_hosts     = jsondecode(base64decode(hcp_consul_cluster.this.consul_config_file))["retry_join"]
  k8s_api_endpoint = module.eks.cluster_endpoint
  consul_version   = hcp_consul_cluster.this.consul_version

  boostrap_acl_token    = hcp_consul_cluster.this.consul_root_token_secret_id
  consul_ca_file        = base64decode(hcp_consul_cluster.this.consul_ca_file)
  datacenter            = hcp_consul_cluster.this.datacenter
  gossip_encryption_key = jsondecode(base64decode(hcp_consul_cluster.this.consul_config_file))["encrypt"]

  # The EKS node group will fail to create if the clients are
  # created at the same time. This forces the client to wait until
  # the node group is successfully created.
  depends_on = [module.eks]
}


module "demo_app" {
  source = "./modules/k8s-demo-app"

  depends_on = [module.eks_consul_client]
}
