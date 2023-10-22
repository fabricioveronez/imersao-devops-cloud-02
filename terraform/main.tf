terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.21.0"
    }
  }
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
variable "private_subnet_cidr_blocks" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "public_subnet_cidr_blocks" {
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}
variable "azs" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.region
}

module "imersao_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name            = "imersao-vpc"
  cidr            = var.vpc_cidr
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_blocks
  azs             = var.azs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/imersao-eks" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/imersao-eks" = "shared"
    "kubernetes.io/role/elb"            = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/imersao-eks" = "shared"
    "kubernetes.io/role/internal-elb"   = 1
  }

}

module "imersao_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.17.2"

  cluster_name    = "imersao-eks"
  cluster_version = "1.27"

  subnet_ids                     = module.imersao_vpc.private_subnets
  vpc_id                         = module.imersao_vpc.vpc_id
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    live = {
      min_size     = 1
      max_size     = 3
      desired_size = 3

      instance_types = ["t3.medium"]
    }
  }
}