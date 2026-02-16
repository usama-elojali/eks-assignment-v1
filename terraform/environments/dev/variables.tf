# variables.tf - Input variables for the dev environment

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-learning"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}