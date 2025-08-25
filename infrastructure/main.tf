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

# S3 Bucket for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "cicd-frontend-bucket-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront OAC (OAI는 deprecated)
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "cicd-frontend-oac"
  description                       = "OAC for cicd frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }
  
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    
    # CORS 헤더 추가
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
  }
  
  # Handle SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = "200"
    response_page_path = "/index.html"
  }
  
  custom_error_response {
    error_code         = 403
    response_code      = "200"
    response_page_path = "/index.html"
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    acm_certificate_arn      = var.domain_name != "" ? aws_acm_certificate.frontend[0].arn : null
    ssl_support_method       = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version = var.domain_name != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.domain_name == "" ? true : false
  }
  
  aliases = var.domain_name != "" ? [var.domain_name] : null
  
  tags = {
    Name = "cicd-frontend-distribution"
  }
}

# Random resources
resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

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

# Route 53 A Record for CloudFront (Frontend)
resource "aws_route53_record" "frontend" {
  count = var.domain_name != "" ? 1 : 0
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
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

# Route 53 AAAA Record for CloudFront (IPv6)
resource "aws_route53_record" "frontend_ipv6" {
  count = var.domain_name != "" ? 1 : 0
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "AAAA"
  
  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

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

# CloudFront CORS Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "cors" {
  name = "cicd-cors-policy"
  
  cors_config {
    access_control_allow_credentials = false
    
    access_control_allow_headers {
      items = ["*"]
    }
    
    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    }
    
    access_control_allow_origins {
      items = ["*"]
    }
    
    access_control_expose_headers {
      items = ["*"]
    }
    
    access_control_max_age_sec = 600
    
    origin_override = true
  }
  
  security_headers_config {
    content_type_options {
      override = true
    }
    
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }
    
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}





# GitHub Actions 관련 리소스는 oidc-setup.tf에서 관리됩니다.