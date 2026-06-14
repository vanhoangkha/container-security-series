# Hardened EKS Cluster — Production Ready
# Apply: terraform init && terraform plan && terraform apply

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.40" }
  }
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "eks/production/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.region
}

variable "region" { default = "ap-southeast-1" }
variable "cluster_name" { default = "production" }
variable "kubernetes_version" { default = "1.30" }

# --- VPC ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# --- KMS Keys ---
resource "aws_kms_key" "eks" {
  description             = "EKS secrets envelope encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_key" "ebs" {
  description             = "EBS volume encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# --- EKS Cluster ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # SECURITY: Private endpoint only
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # SECURITY: Envelope encryption for secrets
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }

  # SECURITY: All control plane logs enabled
  cluster_enabled_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    platform = {
      instance_types = ["m6i.xlarge"]
      ami_type       = "BOTTLEROCKET_x86_64"
      min_size       = 3
      max_size       = 20
      desired_size   = 5

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
            encrypted   = true
            kms_key_id  = aws_kms_key.ebs.arn
          }
        }
      }
    }
  }

  enable_cluster_creator_admin_permissions = false
  access_entries = {
    platform-admin = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/PlatformAdmin"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = { Environment = "production", ManagedBy = "terraform" }
}

data "aws_caller_identity" "current" {}

# --- ECR Repositories ---
resource "aws_ecr_repository" "apps" {
  for_each             = toset(["frontend", "backend", "worker"])
  name                 = "production/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ebs.arn
  }
}

# --- GuardDuty EKS Runtime ---
resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_guardduty_detector_feature" "eks_runtime" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EKS_RUNTIME_MONITORING"
  status      = "ENABLED"
  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

# --- Outputs ---
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_name" { value = module.eks.cluster_name }
output "ecr_repositories" { value = { for k, v in aws_ecr_repository.apps : k => v.repository_url } }
