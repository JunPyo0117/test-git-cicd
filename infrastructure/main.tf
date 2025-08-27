terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  
  backend "s3" {
    bucket = "cicd-terraform-state-471303021447"
    key    = "infrastructure/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "cicd-demo"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"  # VPC 모듈 버전 명시
  
  name = "cicd-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["${var.aws_region}a", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  
  cluster_name    = "cicd-cluster"
  cluster_version = "1.31"
  
  cluster_endpoint_public_access = true
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  
  # 노드 그룹 설정
  eks_managed_node_groups = {
    main = {
      name         = "main"
      min_size     = 1
      max_size     = 2
      desired_size = 1
      instance_types = ["t3.medium"]
      subnet_ids = module.vpc.private_subnets
    }
  }
}

# IAM User for EKS access (로컬 개발용)
resource "aws_iam_user" "my_user" {
  name = "my_user"
  
  tags = {
    Name = "my_user"
  }
}

# IAM Access Key for my_user
resource "aws_iam_access_key" "my_user" {
  user = aws_iam_user.my_user.name
}

# IAM Policy for my_user to access EKS
resource "aws_iam_policy" "my_user_eks_access" {
  name = "my-user-eks-access-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:GetToken"
        ]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}

# Attach policy to my_user
resource "aws_iam_user_policy_attachment" "my_user_eks_access" {
  user       = aws_iam_user.my_user.name
  policy_arn = aws_iam_policy.my_user_eks_access.arn
}

# EKS Access Entry for my_user (will be created after cluster is ready)
resource "aws_eks_access_entry" "my_user" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_user.my_user.arn
  kubernetes_groups = ["admin"]
  type             = "STANDARD"
}

# EKS Access Entry for github-actions-role (will be created after cluster is ready)
resource "aws_eks_access_entry" "github_actions" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = "arn:aws:iam::471303021447:role/github-actions-role"
  kubernetes_groups = ["admin"]
  type             = "STANDARD"
}

# Associate AmazonEKSAdminPolicy with my_user
resource "aws_eks_access_policy_association" "my_user_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.my_user.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.my_user]
}

# Associate AmazonEKSClusterAdminPolicy with my_user
resource "aws_eks_access_policy_association" "my_user_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.my_user.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.my_user]
}

# Associate AmazonEKSAdminPolicy with github-actions-role
resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::471303021447:role/github-actions-role"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.github_actions]
}

# Associate AmazonEKSClusterAdminPolicy with github-actions-role
resource "aws_eks_access_policy_association" "github_actions_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::471303021447:role/github-actions-role"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.github_actions]
}





# ECR Repositories
resource "aws_ecr_repository" "frontend" {
  name                 = "cicd-demo-frontend"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "cicd-demo-backend"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# RDS Database
resource "aws_db_subnet_group" "main" {
  name       = "cicd-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "rds" {
  name_prefix = "cicd-rds-"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # EKS 클러스터에서 접근 허용
    security_groups = [module.eks.cluster_security_group_id]
  }
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # EKS 노드 그룹에서 접근 허용
    security_groups = [module.eks.node_security_group_id]
  }
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # 프라이빗 서브넷에서 접근 허용
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "cicd-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier = "cicd-database"
  
  engine         = "postgres"
  engine_version = "15.13"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  
  db_name  = "cicd_demo"
  username = "postgres"
  password = random_password.db_password.result
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  
  tags = {
    Name = "cicd-database"
  }
}

# S3 버킷 제거 - 프론트엔드는 쿠버네티스에서 서빙

# S3 버킷 정책 제거 (CloudFront 없이 직접 접근)
# CloudFront를 사용하지 않으므로 S3 버킷 정책도 제거

# Random resources
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# S3 버킷을 사용하지 않으므로 bucket_suffix도 제거

# AWS Load Balancer Controller for EKS
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name = "aws-load-balancer-controller-role"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# Security Group for Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "cicd-alb-"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "cicd-alb-sg"
  }
}

# Security Group Rule: Allow ALB to access EKS cluster
resource "aws_security_group_rule" "eks_from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = module.eks.cluster_security_group_id
  description              = "Allow ALB to access EKS cluster pods"
}

# Security Group Rule: Allow ALB to access EKS node group
resource "aws_security_group_rule" "eks_node_from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = module.eks.node_security_group_id
  description              = "Allow ALB to access EKS node group"
}

# Security Group Rule: Allow pod CIDR access to EKS cluster
resource "aws_security_group_rule" "eks_from_pod_cidr" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3001
  protocol          = "tcp"
  cidr_blocks       = [var.pod_cidr]
  security_group_id = module.eks.cluster_security_group_id
  description       = "Allow pod CIDR access to EKS cluster"
}

# Route 53 Hosted Zone (커스텀 도메인이 있는 경우)
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
  
  tags = {
    Name = "cicd-zone"
  }
}

# Route 53 A Record for Frontend (EKS Ingress Controller가 생성한 ALB 사용)
resource "aws_route53_record" "frontend" {
  count = var.domain_name != "" ? 1 : 0
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"
  
  # EKS Ingress Controller가 생성한 ALB의 DNS 이름을 사용
  # 실제 ALB DNS는 Ingress 생성 후에 확인 가능
  alias {
    name                   = "placeholder-alb-dns-name"  # Ingress 생성 후 업데이트 필요
    zone_id                = "Z35SXDOTRQ7R7K"  # ALB의 기본 hosted zone ID
    evaluate_target_health = true
  }
}

# Route 53 A Record for ALB (Backend API) - EKS Ingress Controller가 생성한 ALB 사용
resource "aws_route53_record" "backend" {
  count = var.domain_name != "" ? 1 : 0
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  # EKS Ingress Controller가 생성한 ALB의 DNS 이름을 사용
  # 실제 ALB DNS는 Ingress 생성 후에 확인 가능
  alias {
    name                   = "placeholder-alb-dns-name"  # Ingress 생성 후 업데이트 필요
    zone_id                = "Z35SXDOTRQ7R7K"  # ALB의 기본 hosted zone ID
    evaluate_target_health = true
  }
}

# Route 53 AAAA Record for Frontend (IPv6) - S3는 IPv6를 지원하지 않으므로 제거
# S3 버킷은 IPv4만 지원하므로 AAAA 레코드는 불필요

# ACM Certificate for custom domain
resource "aws_acm_certificate" "frontend" {
  count = var.domain_name != "" ? 1 : 0
  
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name = "cicd-frontend-cert"
  }
}

# Certificate validation records
resource "aws_route53_record" "cert_validation" {
  count = var.domain_name != "" ? length(aws_acm_certificate.frontend[0].domain_validation_options) : 0
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = aws_acm_certificate.frontend[0].domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.frontend[0].domain_validation_options[count.index].resource_record_type
  records = [aws_acm_certificate.frontend[0].domain_validation_options[count.index].resource_record_value]
  ttl     = 60
}

# Certificate validation
resource "aws_acm_certificate_validation" "frontend" {
  count = var.domain_name != "" ? 1 : 0
  
  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = aws_route53_record.cert_validation[*].fqdn
}

# Application Load Balancer for backend - EKS Ingress Controller가 자동 생성하므로 제거
# AWS Load Balancer Controller가 Ingress를 통해 ALB를 자동으로 생성합니다.

# CloudFront CORS Response Headers Policy 제거
# CloudFront를 사용하지 않으므로 CORS 정책도 불필요





# GitHub Actions 관련 리소스는 oidc-setup.tf에서 관리됩니다.