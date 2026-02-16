# main.tf - Wires together VPC and EKS modules

locals {
  cluster_name = "${var.cluster_name}-${var.environment}"
  
  common_tags = {
    Project     = var.cluster_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Create VPC using our module
module "vpc" {
  source = "../../modules/vpc"

  cluster_name       = local.cluster_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  single_nat_gateway = true  # Cost saving for dev
}

# Create EKS cluster using our module
module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  cluster_version     = "1.29"
  environment         = var.environment
  
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  node_instance_types = ["t3.small"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3
  node_capacity_type  = "SPOT"  # 60-70% cheaper!
}

# ECR Repository for our application
resource "aws_ecr_repository" "app" {
  name                 = "${local.cluster_name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ECR Lifecycle Policy - Keep only last 10 images (cost saving)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Outputs - Values we need for next steps
output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}