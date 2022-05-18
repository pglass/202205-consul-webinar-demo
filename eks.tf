module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0"

  cluster_name             = local.name
  cluster_version          = "1.21"
  subnets                  = module.vpc.public_subnets
  vpc_id                   = module.vpc.vpc_id
  wait_for_cluster_timeout = 420

  node_groups = {
    application = {
      name_prefix      = "hashicups"
      instance_types   = ["t3a.medium"]
      desired_capacity = 3
      max_capacity     = 3
      min_capacity     = 3
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

locals {
  ingress_consul_rules = [
    {
      description = "Consul LAN Serf (tcp)"
      port        = 8301
      protocol    = "tcp"
    },
    {
      description = "Consul LAN Serf (udp)"
      port        = 8301
      protocol    = "udp"
    },
  ]

  eks_security_ids = [module.eks.cluster_primary_security_group_id]

  hcp_consul_security_groups = flatten([
    for _, sg in local.eks_security_ids : [
      for _, rule in local.ingress_consul_rules : {
        security_group_id = sg
        description       = rule.description
        port              = rule.port
        protocol          = rule.protocol
      }
    ]
  ])
}

resource "aws_security_group_rule" "hcp_consul_existing_grp" {
  count             = length(local.hcp_consul_security_groups)
  description       = local.hcp_consul_security_groups[count.index].description
  protocol          = local.hcp_consul_security_groups[count.index].protocol
  security_group_id = local.hcp_consul_security_groups[count.index].security_group_id
  cidr_blocks       = [hcp_hvn.server.cidr_block]
  from_port         = local.hcp_consul_security_groups[count.index].port
  to_port           = local.hcp_consul_security_groups[count.index].port
  type              = "ingress"
}


resource "aws_security_group_rule" "eks_proxy_port" {
  description       = "Allow ingress to EKS on 20000 for mesh traffic"
  protocol          = "tcp"
  security_group_id = module.eks.cluster_primary_security_group_id
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  from_port         = 20000
  to_port           = 20000
  type              = "ingress"
}
