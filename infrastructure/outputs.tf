output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "load_balancer_controller_role_arn" {
  description = "ARN of the Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_security_group_id" {
  description = "Security Group ID for ALB"
  value       = aws_security_group.alb.id
}

output "ecr_frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_password" {
  description = "RDS database password"
  value       = random_password.db_password.result
  sensitive   = true
}

# S3 관련 출력 제거 - 프론트엔드는 쿠버네티스에서 서빙

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

# Route 53 outputs
output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "route53_name_servers" {
  description = "Route 53 name servers"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}

# ALB outputs - EKS Ingress Controller가 자동 생성
output "alb_dns_name" {
  description = "ALB DNS name (EKS Ingress Controller가 생성)"
  value       = "EKS Ingress Controller가 ALB를 자동 생성합니다"
}

output "alb_zone_id" {
  description = "ALB zone ID"
  value       = "Z35SXDOTRQ7R7K"  # ALB의 기본 hosted zone ID
}

output "backend_api_url" {
  description = "Backend API URL"
  value       = var.domain_name != "" ? "https://api.${var.domain_name}" : "EKS Ingress Controller가 생성한 ALB DNS"
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.domain_name != "" ? aws_acm_certificate.frontend[0].arn : null
}

# IAM User outputs
output "my_user_arn" {
  description = "ARN of the my_user IAM user"
  value       = aws_iam_user.my_user.arn
}

output "my_user_access_key_id" {
  description = "Access key ID for my_user"
  value       = aws_iam_access_key.my_user.id
  sensitive   = true
}

output "my_user_secret_access_key" {
  description = "Secret access key for my_user"
  value       = aws_iam_access_key.my_user.secret
  sensitive   = true
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "EKS OIDC provider"
  value       = module.eks.oidc_provider
}
