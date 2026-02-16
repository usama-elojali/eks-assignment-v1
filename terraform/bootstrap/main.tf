# =============================================================================
# Terraform Bootstrap - Creates S3 bucket and DynamoDB table for remote state
# =============================================================================
# This module solves the "chicken and egg" problem:
# - You need S3/DynamoDB to store remote state
# - But you can't create them with Terraform if you don't have remote state yet
# 
# Solution: This bootstrap uses LOCAL state to create the remote state backend
# Run this ONCE before running any other Terraform
# =============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # IMPORTANT: Bootstrap uses LOCAL state (not remote)
  # This is intentional - we're creating the remote backend here
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform-bootstrap"
    }
  }
}

# =============================================================================
# S3 Bucket for Terraform State
# =============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = false  # Set to true in production
  }

  tags = {
    Name        = "Terraform State Bucket"
    Description = "Stores Terraform state files for ${var.project_name}"
  }
}

# Enable versioning to recover from bad state
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# DynamoDB Table for State Locking
# =============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"  # No cost when not in use
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform Lock Table"
    Description = "Prevents concurrent Terraform operations"
  }
}

