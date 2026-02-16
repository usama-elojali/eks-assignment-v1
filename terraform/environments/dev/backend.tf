# backend.tf - Configures where Terraform stores its state

terraform {
  backend "s3" {
    bucket         = "eks-tfstate-usama"      # Your S3 bucket name
    key            = "dev/terraform.tfstate"  # Path inside the bucket
    region         = "us-east-1"              # Your region
    dynamodb_table = "eks-terraform-locks"    # For state locking
    encrypt        = true                     # Encrypt state at rest
  }
}