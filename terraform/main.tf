provider "aws" {
  region  = local.region
  profile = "default"
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name   = "esagirov-bb"
  region = "eu-west-1"

  node_group_name = "self-ondemand"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    ProjectName = "AWS-BB"
    Owner       = "Eldar Sagirov"
  }
}

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.0.9"

  cluster_name    = local.name
  cluster_version = "1.21"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets


  node_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Nodegroup for Karpenter"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    },
    all_cluster_internal = {
      description                   = "Cluster API to Nodegroup for Karpenter"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    },
    all_nodes_internal = {
      description = "Cluster API to Nodegroup for Karpenter"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    },
    all_cluster_outbound = {
      description = "Cluster API to Nodegroup for Karpenter"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    },

  }

  node_security_group_tags = {
    "karpenter.sh/discovery/${local.name}" = local.name
  }

  self_managed_node_groups = {
    self_mg_t3 = {
      node_group_name    = local.node_group_name
      launch_template_os = "amazonlinux2eks"
      max_size           = 1
      subnet_ids         = module.vpc.private_subnets
      instance_type      = "t3.medium"
    }
  }

  platform_teams = {
    admin = {
      users = [data.aws_caller_identity.current.arn] #TODO replace with a proper team role - aws_iam_role.eks_access["administrators"]
    }
  }

  application_teams = {
    team-eshop = {
      "labels" = {
        "appName"     = "eshop-team-app",
        "projectName" = "project-eshop",
        "environment" = var.environment
      }
      "quota" = {
        "requests.cpu"    = "10000m",
        "requests.memory" = "40Gi",
        "limits.cpu"      = "20000m",
        "limits.memory"   = "80Gi",
        "pods"            = "100",
        "secrets"         = "100",
        "services"        = "100"
      }

      #manifests_dir = "./manifests-team-red"
      users = [data.aws_caller_identity.current.arn] #TODO replace with a proper team role - aws_iam_role.eks_access["eshop-team"] 
    }

    team-game = {
      "labels" = {
        "appName"     = "game-team-app",
        "projectName" = "project-game",
        "environment" = var.environment
      }
      "quota" = {
        "requests.cpu"    = "2000m",
        "requests.memory" = "4Gi",
        "limits.cpu"      = "4000m",
        "limits.memory"   = "16Gi",
        "pods"            = "20",
        "secrets"         = "20",
        "services"        = "20"
      }

      #manifests_dir = "./manifests-team-blue"
      users = [data.aws_caller_identity.current.arn] #TODO replace with a proper team role - aws_iam_role.eks_access["game-team"]
    }
  }


  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.0.9"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  enable_argocd         = true
  argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying add-ons
  argocd_applications = {
    addons = {
      path               = "chart"
      repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
      add_on_application = true
    }
    workloads = {
      path               = "envs/dev"
      repo_url           = "https://github.com/eldarsagirovda/aws-bb-containerization.git"
      add_on_application = false
    }
  }

  # Add-ons
  #enable_cluster_autoscaler = true
  enable_karpenter                     = true
  enable_metrics_server                = true
  enable_prometheus                    = true
  enable_vpa                           = true
  enable_argo_rollouts                 = true
  enable_aws_node_termination_handler  = true
  enable_aws_load_balancer_controller  = true
  amazon_eks_aws_ebs_csi_driver_config = true

  tags = local.tags

}


# # Creates Launch templates for Karpenter
# # Launch template outputs will be used in Karpenter Provisioners yaml files. Checkout this examples/karpenter/provisioners/default_provisioner_with_launch_templates.yaml
module "karpenter_launch_templates" {
  source = "./modules/launch-templates"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  launch_template_config = {
    linux = {
      ami                    = data.aws_ami.eks.id
      launch_template_prefix = "karpenter"
      iam_instance_profile   = module.eks_blueprints.self_managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks_blueprints.worker_node_security_group_id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 200
        }
      ]
    }

    bottlerocket = {
      ami                    = data.aws_ami.bottlerocket.id
      launch_template_os     = "bottlerocket"
      launch_template_prefix = "bottle"
      iam_instance_profile   = module.eks_blueprints.self_managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks_blueprints.worker_node_security_group_id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 200
        }
      ]
    }
  }

  tags = merge(local.tags, { Name = "karpenter" })
}

# # Deploying default provisioner for Karpenter autoscaler
data "kubectl_path_documents" "karpenter_provisioners" {
  pattern = "${path.module}/provisioners/default_provisioner.yaml"
  vars = {
    azs                     = join(",", local.azs)
    iam-instance-profile-id = "${local.name}-${local.node_group_name}"
    eks-cluster-id          = local.name
    eks-vpc_name            = local.name
  }
}

# You can also deploy multiple provisioner files with the below code snippet
# data "kubectl_path_documents" "karpenter_provisioners" {
#   pattern = "${path.module}/provisioners/*.yaml"
# }

resource "kubectl_manifest" "karpenter_provisioner" {
  for_each  = toset(data.kubectl_path_documents.karpenter_provisioners.documents)
  yaml_body = each.value

  depends_on = [module.eks_blueprints_kubernetes_addons]
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true
  #single_nat_gateway   = false
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}

data "aws_ami" "eks" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-${module.eks_blueprints.eks_cluster_version}-*"]
  }
}

data "aws_ami" "bottlerocket" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${module.eks_blueprints.eks_cluster_version}-x86_64-*"]
  }
}
