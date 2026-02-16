# EKS Learning Project

A complete end-to-end deployment pipeline for a containerized application on AWS EKS, using Terraform for infrastructure, Docker for containerization, and GitHub Actions for CI/CD.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         VPC (10.0.0.0/16)                           │    │
│  │                                                                      │    │
│  │   ┌─────────────────────┐      ┌─────────────────────┐              │    │
│  │   │   Public Subnets    │      │   Private Subnets   │              │    │
│  │   │   (10.0.0-32.0/20)  │      │   (10.0.128-160/20) │              │    │
│  │   │                     │      │                      │              │    │
│  │   │  ┌──────────────┐   │      │  ┌──────────────┐   │              │    │
│  │   │  │ NAT Gateway  │   │      │  │  EKS Nodes   │   │              │    │
│  │   │  └──────────────┘   │      │  │  (t3.small)  │   │              │    │
│  │   │                     │      │  │   SPOT       │   │              │    │
│  │   │  ┌──────────────┐   │      │  └──────────────┘   │              │    │
│  │   │  │    Load      │   │      │                      │              │    │
│  │   │  │   Balancer   │◄──┼──────┼──► EKS Cluster      │              │    │
│  │   │  └──────────────┘   │      │                      │              │    │
│  │   └─────────────────────┘      └─────────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │     ECR      │    │      S3      │    │   DynamoDB   │                   │
│  │  (Images)    │    │   (TF State) │    │  (TF Locks)  │                   │
│  └──────────────┘    └──────────────┘    └──────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
         ▲                                           
         │ Push Image                                
         │                                           
┌────────┴────────┐                                  
│  GitHub Actions │◄──── Push to main                
│     (CI/CD)     │                                  
└─────────────────┘                                  
```

## 📁 Project Structure

```
eks-project/
├── app/                          # Application code (2048 game)
│   ├── Dockerfile                # Container definition
│   ├── index.html
│   └── ...
│
├── terraform/
│   ├── bootstrap/                # Remote state backend (run first)
│   │   ├── main.tf               # S3 bucket + DynamoDB table
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── environments/
│   │   └── dev/                  # Development environment
│   │       ├── backend.tf        # Remote state configuration
│   │       ├── main.tf           # Infrastructure definition
│   │       ├── providers.tf
│   │       └── variables.tf
│   │
│   └── modules/
│       ├── vpc/                  # VPC module
│       └── eks/                  # EKS module
│
├── k8s-manifests/
│   └── apps/
│       ├── deployment.yaml       # Kubernetes Deployment
│       └── service.yaml          # Kubernetes Service (LoadBalancer)
│
└── .github/
    └── workflows/
        └── deploy.yml            # CI/CD pipeline
```

## 🚀 Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Docker
- kubectl
- GitHub account (for CI/CD)

## 📋 Setup Instructions

### Step 1: Bootstrap Remote State

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This creates:
- S3 bucket with versioning and encryption for state storage
- DynamoDB table for state locking

### Step 2: Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

This creates:
- VPC with public and private subnets across 3 AZs
- Internet Gateway and NAT Gateway
- EKS cluster with managed node group (SPOT instances)
- ECR repository for container images

### Step 3: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-learning-dev
```

### Step 4: Build and Push Docker Image

```bash
cd app

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build image (use linux/amd64 for EKS compatibility)
docker build --platform linux/amd64 -t eks-learning-dev-app .

# Tag and push
docker tag eks-learning-dev-app:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/eks-learning-dev-app:v1
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/eks-learning-dev-app:v1
```

### Step 5: Deploy to Kubernetes

```bash
# Update the image in deployment.yaml with your ECR URL
kubectl apply -f k8s-manifests/apps/deployment.yaml
kubectl apply -f k8s-manifests/apps/service.yaml

# Check deployment status
kubectl get pods
kubectl get svc
```

Access the application via the LoadBalancer URL from `kubectl get svc`.

## 🔄 CI/CD Pipeline

The GitHub Actions workflow automatically builds and deploys on push to `main` branch.

### Setup GitHub Actions

1. Create a GitHub Environment named `dev`

2. Add these secrets to the environment:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

3. Add these variables to the environment:
   - `AWS_REGION`: `us-east-1`
   - `ECR_REPOSITORY`: `eks-learning-dev-app`
   - `EKS_CLUSTER_NAME`: `eks-learning-dev`

4. Create IAM user `github-actions-eks` with these permissions:
   - ECR: Push/pull images
   - EKS: DescribeCluster, ListClusters

5. Add the IAM user to EKS aws-auth ConfigMap:
   ```bash
   kubectl edit configmap aws-auth -n kube-system
   ```
   Add under `mapUsers`:
   ```yaml
   - userarn: arn:aws:iam::<account-id>:user/github-actions-eks
     username: github-actions-eks
     groups:
       - system:masters
   ```

### Pipeline Flow

```
Push to main (app/** changes)
        │
        ▼
GitHub Actions triggered
        │
        ▼
Build Docker image (linux/amd64)
        │
        ▼
Push to ECR
        │
        ▼
kubectl set image (rolling update)
        │
        ▼
App deployed with zero downtime
```

## 🧹 Cleanup

### Destroy Infrastructure

**Important:** Delete Kubernetes resources before Terraform destroy to avoid orphaned AWS resources.

```bash
# Step 1: Delete Kubernetes resources
kubectl delete -f k8s-manifests/apps/service.yaml
kubectl delete -f k8s-manifests/apps/deployment.yaml

# Step 2: Wait for LoadBalancer to be deleted (check AWS Console)

# Step 3: Destroy infrastructure
cd terraform/environments/dev
terraform destroy

# Step 4: Destroy bootstrap (optional)
cd terraform/bootstrap
terraform destroy
```

### Common Cleanup Issues

If `terraform destroy` gets stuck:

1. **Load Balancer blocking VPC deletion:**
   ```bash
   aws elb describe-load-balancers --region us-east-1
   aws elb delete-load-balancer --load-balancer-name <name> --region us-east-1
   ```

2. **Security Groups blocking VPC deletion:**
   ```bash
   aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" --region us-east-1
   aws ec2 delete-security-group --group-id <sg-id> --region us-east-1
   ```

## 💡 Key Concepts

### Why Bootstrap for Remote State?

Terraform remote state requires S3 and DynamoDB to exist before use. The bootstrap module solves this "chicken and egg" problem by using local state to create the remote backend.

### Why SPOT Instances?

SPOT instances cost up to 90% less than on-demand. Good for dev/test environments where occasional interruption is acceptable.

### Why Multi-AZ Subnets?

High availability - if one Availability Zone fails, resources in other AZs continue running.

## 📊 Cost Estimate

| Resource | Approximate Cost |
|----------|------------------|
| EKS Control Plane | ~$73/month |
| NAT Gateway | ~$32/month + data |
| t3.small SPOT (2 nodes) | ~$8/month |
| Load Balancer | ~$16/month |
| **Total** | **~$130/month** |

> 💡 Destroy resources when not in use to avoid charges!

## 🔐 Security Features

- Private subnets for EKS nodes
- NAT Gateway for outbound internet access
- S3 state bucket: encryption, versioning, public access blocked
- ECR: vulnerability scanning enabled
- Kubernetes: liveness and readiness probes

## 📚 Resources

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

